// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// Keep this directive prefix aligned with the Image tab, the whole #slots block
// included. Each pass lays its uniform block out in the order its own directives
// appear, so a tab that dropped one or reordered them would read a neighbouring
// control's value.

// #slots name="Colour" max=8 default=1 min=0

// #float label="New Colour {n}" group={"Colour", "paintpalette"} units="°" min=-180 max=180 default=0 surface="a:+180" puck="Colour {n}" pick=hue
uniform float uNewHue;

// #percent label="New Saturation {n}" group="Colour" min=0 max=100 default=0 surface="r:+100" puck="Colour {n}" pick=saturation
uniform float uNewSat;

// #percent label="Width {n}" group="Colour" min=1 max=100 default=25
uniform float uWidth;

// #percent label="Strength {n}" group="Colour" min=0 max=100 default=100
uniform float uStrength;

// #float label="Colour {n} Hue" group={"Picked Colours", "eyedropper"} units="°" min=-180 max=180 default=0 pick=hue puck="Colour {n}"
uniform float uPickedHue;

// #percent label="Colour {n} Saturation" group="Picked Colours" min=0 max=100 default=0 pick=saturation puck="Colour {n}"
uniform float uPickedSat;
// #slots-end

// #percent label="Feather Edges" group={"Finish", "switch.2"} min=0 max=100 default=20
uniform float uFeather;

// #bool label="Show Selection" group={"Finish", "switch.2"} default=false preview=selection
uniform bool uShowSelection;

// Which colour Show Selection is about. Option 0 is every one of them at once; n
// narrows it to the nth.
//
// The union is the wrong picture for TUNING one colour. Judging a Width against a
// frame that also carries the other slots' selections is guessing, and the reflex is
// then to widen the one you are on until the whole thing looks right - a slot tuned
// to compensate for slots it has nothing to do with. It costs nothing to narrow: the
// shift this pass accumulates never reads it, so the grade is identical either way.
//
// NO ROW IN THE INSPECTOR, and nothing stored. `preview=` hands the control to the
// Color panel, which feeds the handle you last touched into it while its preview is
// open - so the matte simply follows the puck you are holding, with no control to
// find and nothing to set. Everywhere the panel is not driving it, including Final
// Cut's viewer, it reads the 0 declared here and the matte never appears.
//
// The options are what the panel's numbering means, not a menu anyone sees.
// #choice label="Preview Key" group={"Finish", "switch.2"} options="All,1,2,3,4,5,6,7,8" default=0 preview=active-key
uniform int uPreviewKey;

// #percent label="Mix" group={"Finish", "switch.2"} min=0 max=100 default=100
uniform float uMix;

// Eight taps a side plus the centre, so seventeen per pass and thirty four for the
// pair. The same reach as a single 17 x 17 kernel costs 289 fetches, and that factor
// of eight is the whole reason the blur is split into a horizontal and a vertical
// pass rather than done in one.
const int FEATHER_TAPS = 8;

// How far out the last tap sits, in standard deviations. At 2.5 the Gaussian has
// fallen to 4.4 percent, which is under the 5 percent where truncating a kernel
// starts to show as a ring around a bright matte edge.
const float FEATHER_SIGMAS = 2.5;

// Feather at 100 percent reaches 1.5 percent of the frame HEIGHT: 16 pixels at
// 1080p, 32 at 2160p. Tying it to the height rather than to a pixel count is what
// makes the same percentage look the same on both, which matters here because the
// fringe being removed is itself a fraction of the picture rather than a fixed
// number of pixels.
const float FEATHER_MAX_FRACTION = 0.015;

float featherRadiusPixels()
{
	return uFeather * FEATHER_MAX_FRACTION * iResolution.y;
}

float featherTapWeight(int index)
{
	float t = float(index) / float(FEATHER_TAPS) * FEATHER_SIGMAS;
	return exp(-0.5 * t * t);
}

// The horizontal half of the feather. Buffer C reads Buffer B on iChannel1, which is
// an EARLIER buffer and therefore this frame's, not last frame's: the chain stays a
// pure function of the current picture and never becomes feedback.
//
// It blurs the whole vec4 without caring what is in it, which is the point: the shift
// in rg and the matte in b are both linear in the pixel, so one separable Gaussian
// over all of them is the same answer as one per channel.
void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;
	float radius = featherRadiusPixels();

	// Under half a pixel there is nothing a blur could move, so Feather at 0 costs one
	// fetch and hands the shift field through untouched rather than paying for
	// seventeen taps that would average a value with itself.
	if (radius < 0.5)
	{
		fragColor = texture(iChannel1, uv);
		return;
	}

	vec2 stepUV = vec2(radius / float(FEATHER_TAPS) / iResolution.x, 0.0);
	vec4 total = texture(iChannel1, uv);
	float weightTotal = 1.0;
	for (int i = 1; i <= FEATHER_TAPS; ++i)
	{
		float weight = featherTapWeight(i);
		vec2 offset = stepUV * float(i);
		total += texture(iChannel1, clamp(uv + offset, 0.0, 1.0)) * weight;
		total += texture(iChannel1, clamp(uv - offset, 0.0, 1.0)) * weight;
		weightTotal += 2.0 * weight;
	}
	fragColor = total / weightTotal;
}
