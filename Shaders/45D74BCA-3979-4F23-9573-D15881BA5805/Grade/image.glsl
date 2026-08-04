// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template filter

// #alpha
// #color-surface ring=hue
// #color-surface ring=light xaxis="Flat,Punchy" yaxis="Darker,Brighter"

// The ring is painted with real perceptual hue, so each balance control points at the
// hue it actually produces rather than at a screen edge. Drag the puck toward the red
// you can see on the ring and Red goes up. There are no compass labels because the ring
// is the legend, and it is a more honest one than four words at the cardinal points.
// Red and cyan sit 166 degrees apart, green and magenta 186 - those hues are not exact
// perceptual opposites, and the surface solves for both controls together rather than
// assuming a square grid.

// #float label="Red / Cyan" group={"Balance", "circle.lefthalf.filled"} min=-100 max=100 default=0 surface="hue x:+31 y:+17"
uniform float uRedCyan;

// #float label="Green / Magenta" group="Balance" min=-100 max=100 default=0 surface="hue x:-28 y:+22"
uniform float uGreenMagenta;

// #bool label="Preserve Brightness" group="Balance" default=true
uniform bool uPreserveLuma;

// #float label="Exposure" group={"Light", "camera.aperture"} units="stops" min=-5 max=5 default=0 surface="light y:+1.5"
uniform float uExposure;

// #percent label="Contrast" group="Light" min=0 max=200 default=100 surface="light x:+70"
uniform float uContrast;

// The pivot is a luminance, so the eyedropper sets it directly: click what the
// grade is being judged on and contrast pushes away from that level instead of
// away from a nominal 18% that may be nowhere near where this image sits.
// #percent label="Pivot" group="Light" min=1 max=99 default=18 pick=luma-linear
uniform float uPivot;

// #percent label="Saturation" group={"Colour", "paintpalette"} min=0 max=200 default=100
uniform float uSaturation;

// #percent label="Mix" group={"Finish", "switch.2"} min=0 max=100 default=100
uniform float uMix;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

// The source arrives DISPLAY-ENCODED, so every photometric step below has to happen
// in linear light and be re-encoded on the way out. Grading encoded values is the
// classic mistake: one stop of exposure stops meaning one stop, and contrast starts
// bending hue as the channels cross the curve at different rates. `decodeToLinear`
// and `encodeFromLinear` are the injected pair, like `balanceGain` and the Oklab
// round trip below - defining a private copy would only suppress the injection.

void mirageFilterImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;
	vec4 source = texture(iChannel0, uv);
	vec3 graded = decodeToLinear(source.rgb);

	// 1. BALANCE first. A cast is an error in the capture, so it is corrected before
	// anything is built on top of it - shaping contrast around a tinted image bakes
	// the tint into the shape. Channel gains, in linear light: a cast is light
	// arriving in the wrong proportion, so it is undone in the same terms.
	float startLuma = dot(graded, LUMA);
	graded *= balanceGain(uRedCyan, uGreenMagenta);
	if (uPreserveLuma)
	{
		// Balance changes colour and only colour. Without this every pull doubles as
		// an exposure move, which is what makes ordinary temperature sliders feel
		// like they fight you.
		graded *= startLuma / max(dot(graded, LUMA), 0.0001);
	}

	// 2. EXPOSURE in stops, as a straight multiply of linear light: +1 is exactly
	// twice the light, the same as opening the aperture a stop.
	graded *= pow(2.0, uExposure);

	// 3. CONTRAST about a pivot, so it does not drag exposure with it. The pivot
	// defaults to 18% - middle grey - which is why the image appears to rotate about
	// its midtones instead of getting brighter as it gets punchier.
	float pivot = max(uPivot, 0.001);
	graded = pivot * pow(max(graded / pivot, vec3(0.000001)), vec3(uContrast));

	// 4. SATURATION last, so the earlier steps do not get re-weighted by it, and in
	// OKLAB rather than as a pull toward luma. Saturation is colour work, and the
	// difference shows at the ends: a chroma stretch holds the hue it started with
	// and puts zero on a true neutral of the same lightness, where mixing toward a
	// luma grey drags blues violet on the way down and leaves greens reading light.
	vec3 lab = linearToOklab(max(graded, 0.0));
	graded = oklabToLinear(vec3(lab.x, lab.y * uSaturation, lab.z * uSaturation));

	vec3 result = encodeFromLinear(graded);
	fragColor = vec4(mix(source.rgb, result, uMix), source.a);
}

// FxPlug supplies iChannel0 premultiplied. The filter body keeps doing its
// existing maths in that representation; #alpha then expects straight colour,
// so unwrap once here before Mirage premultiplies the final output.
void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	mirageFilterImage(fragColor, fragCoord);
	if (fragColor.a > 0.0001)
		fragColor.rgb /= fragColor.a;
	else
		fragColor.rgb = vec3(0.0);
}
