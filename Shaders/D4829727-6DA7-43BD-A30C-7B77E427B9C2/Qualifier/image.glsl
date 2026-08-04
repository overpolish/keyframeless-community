// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template filter

// #alpha
// #color-surface ring=hue

// One key is a hue you SELECT and a correction you push it toward. A shot rarely
// has one: the jacket and the sky and the skin are three different arguments, and
// running the effect three times means three mattes nobody can see together and
// three grades stacked through three encodes. So a key is a slot, one is what a
// fresh apply starts with, and there are as many more as the shot asks for.
//
// Two handles per key, doing two different jobs.
//
// Target SELECTS. Its bearing is the hue being keyed and nothing else, so it is
// tracked to a circle just inside the ring where it sits on the colour it picks -
// pulling a selection handle in and out would mean nothing. The eyedropper drives
// the same handle: click the thing in the frame you want to change and Target lands
// on its hue, which beats hunting for a shirt's exact angle by eye. Pick what it is,
// then drag Adjust to where you want it to go.
//
// Adjust CORRECTS, and carries the whole correction rather than one number. Its
// bearing is the colour to push the selection toward; its distance drives the shift
// AND the saturation together, because that is the move - a secondary you push
// toward a colour almost always wants to come up in saturation with it, and doing
// both from one drag is the difference between grading and setting parameters. You
// watch the footage and pull until it looks right, which is not something you can
// read off a wheel.
//
// Each key gets its own pair, numbered: key 3's select handle is drawn 3.circle and
// its correct handle 3.square, so the wheel reads as the set of keys rather than as
// a crowd of identical dots. Both handles take their angle from the ring, and the
// ring is painted in OKLAB, so every hue in here is an Oklab hue. Reading the image
// on one wheel and aiming on another is how a correction ends up somewhere nobody
// pointed at.
//
// WHERE EACH KEY MEASURES ITS SELECTION, which is the whole question once there is
// more than one.
//
// A key's weight is measured against the ORIGINAL pixel, and its correction is
// applied to the RUNNING one. That split is deliberate and it is the contract.
//
// Measuring selection on the running colour would be the other choice, and it reads
// well for about one key: key 2 would then select whatever key 1 had just produced,
// so pushing the jacket toward orange would quietly drag it into the skin key and
// grade it twice. Worse, the second key's matte would change every time the first
// key's Shift Amount moved - a handle nobody touched, changing what a different
// handle selects. Anchoring every weight to the footage means Show Selection is
// telling the truth about a key no matter what the keys above it are doing, and a
// key's matte only moves when its own Select controls move.
//
// The corrections still COMPOSITE in order rather than summing. Each key turns and
// stretches the running Oklab vector it is handed, so where two hue windows overlap
// a pixel gets key 1's move and then key 2's move applied to the result, both scaled
// by their own weights. Summing the raw corrections instead would double-shift that
// overlap - two half-strength pushes toward the same hue would land past it - and no
// amount of normalising fixes it without making each key's strength depend on which
// other keys happen to be on.
//
// A key's turn is measured from where the pixel currently IS, which is what keeps
// "at full amount the selection lands on the colour the handle points at" true for
// the last key to touch a pixel. There is only one answer a stack can give that
// promise to, and it is the one on top.
//
// SPACES, audited rather than assumed.
//
// The panel measures a picked hue by decoding the display-encoded probe to linear
// Rec.709 and converting to Oklab - MirageOklabLChOfEncoded, on the same matrices
// this shader's linearToOklab carries. iChannel0 is gamma-encoded by the engine's
// source contract, and decodeToLinear below undoes exactly the transfer the panel
// undoes, so a hue written into Target Hue by the eyedropper and a hue measured here
// are the same number rather than two numbers that happen to agree. Saturation
// matches too: the panel reports Oklab chroma over 0.33 and MAX_CHROMA below is
// 0.33. Hue would survive a mismatch anyway, being an angle in a plane that a
// transfer function scales rather than turns, but Min Saturation would not, so this
// is checked rather than leaned on.

// #slots name="Key" max=6 default=1 min=1

// #float label="Target Hue {n}" group={"Select", "eyedropper"} units="°" min=-180 max=180 default=0 surface="a:+180" puck={"Key {n}", "{n}.circle"} track=0.78 pick=hue
uniform float uTargetHue;

// #float label="Width {n}" group="Select" units="°" min=5 slidermax=180 default=40
uniform float uWidth;

// #percent label="Softness {n}" group="Select" min=0 max=100 default=60
uniform float uSoftness;

// #percent label="Min Saturation {n}" group="Select" min=0 max=100 default=10
uniform float uMinSat;

// #float label="Shift To {n}" group={"Adjust", "camera.filters"} units="°" min=-180 max=180 default=0 surface="a:+180" puck={"Key {n} Adjust", "{n}.square"}
uniform float uShiftTo;

// #percent label="Shift Amount {n}" group="Adjust" min=0 max=100 default=0 surface="r:+40" puck={"Key {n} Adjust", "{n}.square"}
uniform float uShiftAmount;

// #percent label="Saturation {n}" group="Adjust" min=0 max=200 default=100 surface="r:+25" puck={"Key {n} Adjust", "{n}.square"}
uniform float uSaturation;

// #percent label="Brightness {n}" group="Adjust" min=-100 max=100 default=0
uniform float uBrightness;
// #slots-end

// #bool label="Show Selection" group={"Finish", "switch.2"} default=false preview=selection
uniform bool uShowSelection;

// Which key Show Selection is about. Option 0 is every key at once; n narrows it
// to the nth key.
//
// It exists because the union is the wrong picture for TUNING. Judging key 2's
// Width against a frame that also has key 1's and key 4's spill in it is guessing,
// and the temptation is then to widen key 2 until the union looks right - which is
// a key tuned to compensate for keys it has nothing to do with. Narrowing costs
// nothing at render time: the correction below never reads this, so what is graded
// is identical whatever it says.
//
// NO ROW IN THE INSPECTOR, and nothing stored. `preview=` hands the control to the
// Color panel, which feeds the handle you last touched into it while its preview is
// open - so the matte simply follows the puck you are holding, with no control to
// find and nothing to set. Everywhere the panel is not driving it, including Final
// Cut's viewer, it reads the 0 declared here and the matte never appears.
//
// The options are what the panel's numbering means, not a menu anyone sees.
// #choice label="Preview Key" group={"Finish", "switch.2"} options="All,1,2,3,4,5,6" default=0 preview=active-key
uniform int uPreviewKey;

// #percent label="Mix" group={"Finish", "switch.2"} min=0 max=100 default=100
uniform float uMix;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

// The most colourful thing Rec.709 can show sits at about this Oklab chroma, so
// dividing by it turns chroma into a 0..1 colourfulness that Min Saturation can be
// read against.
const float MAX_CHROMA = 0.33;

// Shortest signed way round from one hue to another, -180 to 180. Every hue
// comparison here goes through this: a plain subtraction reports 350 where the eye
// sees -10, which would send a correction the long way round the wheel.
float hueDelta(float from, float to)
{
	return mod(to - from + 540.0, 360.0) - 180.0;
}

// Hue as the bearing of the a/b vector, colourfulness as its length. Both fall out
// of the same pair, so asking twice would measure it twice. Neutrals answer -1:
// their hue is noise, and turning noise says nothing.
float oklabHueDegrees(vec3 lab, out float colourfulness)
{
	float chroma = length(lab.yz);
	colourfulness = clamp(chroma / MAX_CHROMA, 0.0, 1.0);
	if (chroma < 0.0001) return -1.0;
	float h = degrees(atan(lab.z, lab.y));
	return h < 0.0 ? h + 360.0 : h;
}

// The whole correction in one move: turn the a/b vector by the shift, then stretch
// it by the saturation. Lightness is in neither operation, so neither can change how
// bright the pixel is, which is the thing an RGB rotation matrix cannot promise.
vec3 turnAndStretch(vec3 lab, float degreesShift, float chromaScale)
{
	float a = radians(degreesShift);
	float cs = cos(a);
	float sn = sin(a);
	return vec3(lab.x,
	            (lab.y * cs - lab.z * sn) * chromaScale,
	            (lab.y * sn + lab.z * cs) * chromaScale);
}

// The qualifier for one key: how much this pixel belongs to that key's band, 0 to 1.
//
// Two gates, both soft. Hue distance decides the band, and a minimum colourfulness
// keeps near-greys out of it - without that second gate the hue of a shadow, which
// is essentially noise, qualifies as strongly as the hue of a shirt, and the
// correction crawls all over the flat areas. Both are measured in Oklab, the space
// the correction happens in, so the matte and the move agree about what a hue is.
//
// The hue and colourfulness handed in are the SOURCE pixel's, for every key. See the
// anchoring note at the top: a key selects the footage, not the grade above it.
float selection(int key, float hue, float colourfulness)
{
	if (hue < 0.0) return 0.0;
	float distance = abs(hueDelta(uTargetHue[key], hue));
	float halfBand = max(uWidth[key] * 0.5, 0.5);
	// Softness widens the roll-off OUTSIDE the band rather than eating into it, so
	// turning it up never shrinks what you selected.
	float feather = halfBand + max(uSoftness[key], 0.001) * 90.0;
	float band = 1.0 - smoothstep(halfBand, feather, distance);
	float satGate = smoothstep(0.0, max(uMinSat[key], 0.001), colourfulness);
	return band * satGate;
}

void mirageFilterImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;
	vec4 source = texture(iChannel0, uv);

	vec3 linear = max(decodeToLinear(source.rgb), 0.0);
	vec3 lab = linearToOklab(linear);
	float colourfulness;
	float hue = oklabHueDegrees(lab, colourfulness);

	// The stack. `running` carries the colour through the keys in order; `matte` is
	// the union of what they selected, for the diagnostic; `brightness` is collected
	// as a product rather than folded in per key because it is a linear-light
	// multiply and Oklab is not where it belongs.
	//
	// Bounded by uKeyCount and never by the ceiling: a deleted key leaves a zeroed
	// slice behind it, and a zero Width would key a hairline of every hue.
	vec3 running = lab;
	int previewKey = uPreviewKey > uKeyCount ? 0 : uPreviewKey;
	float matte = 0.0;
	float previewMatte = 0.0;
	float brightness = 1.0;
	for (int i = 0; i < uKeyCount; ++i)
	{
		float weight = selection(i, hue, colourfulness);
		matte = max(matte, weight);
		// The DIAGNOSTIC union, which Preview Key is allowed to narrow, kept apart
		// from `matte` - which gates the correction and must stay the union of every
		// key, or narrowing the preview would silently stop grading the others.
		//
		// `previewKey` and not the raw control: a project that pinned key 5 and then
		// deleted down to two still HOLDS the 5, and comparing against it would match
		// nothing and show an empty matte - which reads as a broken key rather than as
		// a stale setting. Falling back to All is the honest answer, and it is
		// self-healing: re-adding the instance brings the pin straight back, because
		// nothing rewrote the stored value to "fix" it.
		if (previewKey == 0 || previewKey == i + 1)
			previewMatte = max(previewMatte, weight);
		if (weight <= 0.0001) continue;

		// Measured on the running colour, so the turn lands this key's selection on
		// the hue this key's handle points at, whatever an earlier key did to it. A
		// pixel an earlier key desaturated to nothing has no hue left to turn, and
		// turning noise says nothing, so the shift drops out and the stretch stands.
		float runningColourfulness;
		float runningHue = oklabHueDegrees(running, runningColourfulness);

		// Each selected pixel is turned TOWARD the destination hue rather than rotated
		// by a fixed amount. That is what makes the gesture mean what it looks like: at
		// full amount the selection LANDS on the colour the puck is pointing at,
		// whatever hue each pixel started from, instead of the whole band sliding by an
		// offset and arriving somewhere nobody aimed for.
		//
		// Lands, exactly. The turn happens in Oklab, where a hue IS an angle and moving
		// it is a rotation of that angle rather than a matrix that approximates one.
		// Measured against the ring the puck is dragged on, the old luma-preserving RGB
		// matrix arrived 15 to 29 degrees away, worst in the blues. This arrives inside
		// a thousandth of a degree, and only the gamut can move it off, never the maths.
		//
		// Every adjustment is scaled by the matte rather than applied and then masked,
		// so a partially-selected pixel gets a partial move and the band's edge stays
		// soft.
		float toward = runningHue < 0.0
		               ? 0.0
		               : hueDelta(runningHue, uShiftTo[i]) * uShiftAmount[i];
		// Saturation rides the same drag, which is why it is not a knob you set
		// afterwards: it is a stretch of the same a/b vector the shift just turned.
		float chromaScale = 1.0 + (uSaturation[i] - 1.0) * weight;
		running = turnAndStretch(running, toward * weight, chromaScale);
		// Brightness stays a slider on purpose, and stays a multiply in linear light,
		// because it is about light rather than colour. Lifting a secondary off the
		// image around it is what makes a correction look pasted on, so it is a
		// decision rather than a side effect of pulling further out.
		brightness *= 1.0 + uBrightness[i] * weight;
	}

	// A matte view, because a secondary you cannot see the matte of is guesswork. It
	// shows the UNION of every key Preview Key admits - all of them by default, which
	// is the region the stack touches at all - and it stays in the encoded domain
	// deliberately: it is a diagnostic, not an image.
	// The union is a max rather than a sum because an overlap is not more selected
	// than either key was - a sum would read past white where two windows met and
	// hide the very place the compositing order matters.
	if (uShowSelection)
	{
		vec3 grey = vec3(dot(source.rgb, LUMA) * 0.25);
		fragColor = vec4(mix(grey, vec3(1.0), previewMatte), source.a);
		return;
	}

	// No key wanted this pixel, so nothing is touched: not re-encoded, not nudged by a
	// round trip out of Oklab and back, not by a single code value.
	if (matte <= 0.0001)
	{
		fragColor = source;
		return;
	}

	vec3 adjusted = oklabToLinear(running) * brightness;

	vec3 graded = encodeFromLinear(max(adjusted, 0.0));
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
