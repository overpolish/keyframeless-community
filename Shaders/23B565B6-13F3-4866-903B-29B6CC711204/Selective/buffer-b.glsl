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

// The most colourful thing Rec.709 can show sits at about this Oklab chroma, so
// dividing by it turns chroma into a 0..1 colourfulness. It is the same number the
// eyedropper divides by when it writes a saturation, so a picked 40% and a slider
// at 40% mean the same colour.
const float MAX_CHROMA = 0.33;

// Where a hue and a colourfulness land on the Oklab a/b plane. A hue and a
// saturation ARE a point on that plane, so a slot's two colours become two points
// and its whole correction is the arrow between them. One function for both of them,
// on purpose: a slot whose colours are equal then produces two bit-identical points,
// and the arrow is exactly zero rather than nearly.
vec2 chromaPoint(float hueDegrees, float saturation)
{
	float angle = radians(hueDegrees);
	return MAX_CHROMA * saturation * vec2(cos(angle), sin(angle));
}

// How much a pixel belongs to a slot: 1 exactly on the picked colour, 0 at Width
// away and past it, smooth and falling all the way between.
//
// One distance covers hue AND colourfulness because on this plane they are one
// measurement - a circle of radius Width around the picked point, which is the same
// circle the user can see around the handle. A separate hue band and saturation gate
// would select a wedge instead, and a wedge reaches all the way to the middle, where
// every hue is grey and the selection crawls over the flat areas.
float belonging(vec2 ab, vec2 picked, float width)
{
	float distance = length(ab - picked) / MAX_CHROMA;
	return 1.0 - smoothstep(0.0, max(width, 0.0001), distance);
}

// Every live slot, summed into ONE move. rg is the combined shift - each slot's arrow
// scaled by how much this pixel belongs to it and by its Strength - and b is the
// combined matte, for the Show Selection switch alone, over whichever slots Preview
// Key admits.
//
// Strength is applied here rather than in the Image pass because that is the only
// place it can be once the slots are summed, and it costs nothing to move: it scaled
// a weight there and it scales the same weight here, one multiply either way.
//
// Half of the shift is NEGATIVE wherever a colour moves the other way round the
// wheel, and that stores: a buffer is an RGBA16Float render target, so rg is signed
// and has the range and the precision for a value bounded by twice the maximum
// chroma. Nothing has to be biased into 0..1 and unbiased on the far side.
//
// Alpha is a plain 1.0. This chain reads only EARLIER buffers - this pass reads the
// source clip and nothing else - so there is no frame of its own output to recognise
// and no signature to write into alpha for it.
//
// The loop is bounded by the live count and never by the array length: a slot past
// the count is zero-filled, and a zeroed Width would select the whole flat area of
// the frame rather than nothing.
//
// Buffer A is skipped, so iChannel0 is the source clip.
void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;
	vec3 linear = max(decodeToLinear(texture(iChannel0, uv).rgb), 0.0);
	vec2 ab = linearToOklab(linear).yz;

	vec2 shift = vec2(0.0);
	// A slot that was pinned and has since been deleted is still held in the stored
	// value. Comparing against it would match nothing and show an empty matte, which
	// reads as a broken slot rather than a stale setting, so it falls back to All -
	// and re-adding the slot brings the pin back, nothing having rewritten it.
	int previewKey = uPreviewKey > uColourCount ? 0 : uPreviewKey;
	float matte = 0.0;
	for (int i = 0; i < uColourCount; i++)
	{
		vec2 picked = chromaPoint(uPickedHue[i], uPickedSat[i]);
		float weight = belonging(ab, picked, uWidth[i]);
		shift += (chromaPoint(uNewHue[i], uNewSat[i]) - picked) * (weight * uStrength[i]);
		// The matte channel is the DIAGNOSTIC, and Preview Key is allowed to narrow it.
		// The shift above is not, and reads none of this: what gets graded is the same
		// whichever colour is being looked at.
		if (previewKey == 0 || previewKey == i + 1)
			matte = max(matte, weight);
	}

	fragColor = vec4(shift, matte, 1.0);
}
