// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template filter

// #alpha
// #color-surface ring=light xaxis="Flat,Punchy" yaxis="Darker,Brighter"

// #float label="Exposure" group={"Tone", "camera.aperture"} units="stops" min=-5 max=5 default=0 surface="y:+1.5"
uniform float uExposure;

// #float label="Contrast" group={"Tone", "camera.aperture"} min=-100 max=100 default=0 surface="x:+35"
uniform float uContrast;

// The pivot is a luminance, so the eyedropper sets it directly: click the thing the
// grade is being judged on - a face, a grey card, the wall behind it - and contrast
// pushes away from that level instead of away from a nominal 18% that may be
// nowhere near where this image actually sits.
// #percent label="Pivot" group={"Tone", "camera.aperture"} min=1 max=99 default=18 pick=luma-linear
uniform float uPivot;

// #float label="Black Level" group={"Tone", "camera.aperture"} units="%" min=-5 max=5 default=0
uniform float uBlackLevel;

// #percent label="Mix" group={"Finish", "switch.2"} min=0 max=100 default=100
uniform float uMix;

// Contrast in LOG space around a pivot, which is how a grader means it: the pivot
// holds still and everything else moves away from it by a constant ratio, so the
// image gets steeper without the mids sliding up or down. Doing it linearly instead
// pulls the whole picture toward black as contrast rises, and then you spend the
// exposure control undoing it.
vec3 contrastAroundPivot(vec3 c, float amount, float pivot)
{
	if (abs(amount) < 0.0001) return c;
	float slope = amount >= 0.0 ? 1.0 + amount / 50.0 : 1.0 + amount / 100.0;
	vec3 l = log2(max(c, 1e-6));
	float p = log2(max(pivot, 1e-6));
	return exp2(p + (l - p) * slope);
}

void mirageFilterImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;
	vec4 source = texture(iChannel0, uv);

	vec3 linear = decodeToLinear(source.rgb);

	// Black level first, as a plain offset: it decides where black sits, and doing it
	// after contrast would have contrast fighting a floor that keeps moving.
	linear += uBlackLevel / 100.0;

	linear *= exp2(uExposure);
	linear = contrastAroundPivot(linear, uContrast, uPivot);

	vec3 graded = encodeFromLinear(max(linear, 0.0));
	fragColor = vec4(mix(source.rgb, graded, uMix), source.a);
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
