// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template filter

// #alpha
// #color-surface ring=hue

// Click a colour in the picture, then drag it somewhere else.
//
// Each slot holds two colours: the one that was PICKED out of the frame, and the one
// it is moving TO. The eyedropper writes BOTH of them, so the handle lands exactly on
// the cluster it just sampled and the picture does not change until the handle is
// dragged. Point at the thing, then pull it where you want it - there is no threshold
// to find first. One slot is what a fresh apply starts with, and there are as many
// more as the shot asks for.
//
// A handle's bearing is the new colour and its distance from the middle is how
// colourful that colour is, which is exactly the pair of numbers the wheel under
// it is painted with. Both readings are Oklab, the space the ring is drawn in, so
// a handle sitting on a green produces that green rather than a neighbouring one.
//
// New Colour and New Saturation default to zero because that is what puts the
// handle where the eyedropper will put it. A handle's bearing is ABSOLUTE - it
// names the hue it is sitting on whatever the control's default is - but its
// distance is measured from that default, so a non-zero New Saturation would
// move the ring's centre out from under every handle. Zero also reads correctly
// on its own: a handle in the middle has picked nothing yet.
//
// The picked colours are kept as ordinary sliders at the bottom, so a value can be
// typed, keyframed or copied without the eyedropper being the only way in. They
// carry their slot's puck= so a click is routed to the handle being worked on
// rather than to every slot at once.
//
// FEATHER, and why this shader is four passes.
//
// A tree against a sky has pixels along its edge that are neither: the lens and the
// sensor mixed them, so in Oklab they sit part way between the leaf cluster and the
// sky. Selecting purely by colour therefore gives them a partial weight, they move
// part of the way, and the result reads as a coloured outline tracing every branch.
// No colour-space refinement fixes that, because those pixels genuinely are a
// mixture - the information that they belong to the edge is SPATIAL.
//
// So the matte is computed once into a buffer and then blurred, and the blurred
// matte is what gets applied. An edge pixel is then surrounded by fully selected
// leaf on one side and fully rejected sky on the other, and the blur hands it a
// weight that agrees with its neighbourhood instead of with its own mongrel colour.
// The fringe stops being a ring and becomes the last few percent of a gradient.
//
// WHAT THE BUFFER CARRIES, and why it is not one channel per slot.
//
// Three slots fit in r/g/b and eight do not, so the buffer holds the finished sum
// rather than the ingredients: Buffer B weighs every live slot and writes the
// COMBINED SHIFT, sum of arrow times weight times strength, into rg. That is not an
// approximation of blurring each weight separately, it is the same number. A blur is
// a weighted sum of neighbours, the arrows are one pair of values for the whole
// frame, and a weighted sum commutes with multiplying by a constant and with adding,
// so blur(sum of arrow_i * w_i) is exactly sum of arrow_i * blur(w_i). Two channels
// carry any number of slots, and the cost stops growing at the third.
//
// Buffer A is deliberately SKIPPED so that iChannel0 stays the source clip in every
// pass, which is the routing this engine gives a shader for free. Buffer B sums the
// live slots into the shift field in rg and their combined matte in b, Buffer C blurs
// that horizontally, Buffer D blurs Buffer C vertically, and this pass reads the
// finished field on iChannel3. Every pass reads only EARLIER buffers, so the chain is
// a pure function of the current frame with no feedback in it, and accumulate motion
// blur still works.

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

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

void mirageFilterImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;
	vec4 source = texture(iChannel0, uv);

	// Buffer D: the combined move in rg and the combined matte in b, summed by colour
	// in Buffer B and then feathered across the picture by Buffer C and Buffer D.
	// Alpha is unused. The arrows and the strengths are already inside rg, so there is
	// nothing left for this pass to weigh - it reads the answer and adds it.
	vec3 field = texture(iChannel3, uv).rgb;
	vec2 shift = field.xy;
	float matte = field.z;

	// A selection you cannot see the shape of is guesswork, so the combined matte is
	// one switch away. It shows the FEATHERED weights, which is what is actually
	// being applied - a matte that disagreed with the correction would be worse than
	// no matte at all. It stays in the encoded domain deliberately: it is a
	// diagnostic rather than an image.
	//
	// One honest divergence from the correction it stands beside: this is the blur of
	// the largest weight, where the shape being applied is built from the blur of each
	// weight. The two agree everywhere one slot is on its own and part company only
	// where two selections overlap, an average of maxima never being less than the
	// max of the averages, so this reads a touch generous there. A diagnostic can
	// carry that; a correction could not, which is why the correction is not built
	// this way.
	if (uShowSelection)
	{
		vec3 grey = vec3(dot(source.rgb, LUMA) * 0.25);
		fragColor = vec4(mix(grey, vec3(1.0), matte), source.a);
		return;
	}

	// Nothing has been moved anywhere, so nothing is touched: not re-encoded, not
	// nudged by a round trip out of Oklab and back, not by a single code value. Every
	// slot whose two colours agree contributes an arrow of exactly zero - the same
	// function produced both of its points - so the sum Buffer B writes is exactly
	// zero, and a blur of zeros is zeros whatever the taps weigh. This is an equality,
	// not a tolerance. The decode below is on the far side of this branch for that
	// reason.
	if (shift == vec2(0.0))
	{
		fragColor = source;
		return;
	}

	vec3 lab = linearToOklab(max(decodeToLinear(source.rgb), 0.0));

	// The selection is TRANSLATED, not turned: every pixel in it moves by the same
	// arrow, so the shading inside the object survives the move. Rotating each pixel
	// onto the destination hue instead would land them all on one colour and flatten
	// the thing being graded into a sticker. Lightness is in neither term, so a colour
	// change cannot become a brightness change.
	lab.yz += shift;

	vec3 graded = encodeFromLinear(oklabToLinear(lab));
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
