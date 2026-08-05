// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template filter

// #alpha
// Percent because the useful range is a ratio, not a number of anything. 100%
// adds back exactly the detail the blur took out, which is the classic unsharp
// mask. The slider stops at 100 and the field goes to 300, so the everyday
// drag stays in the range that looks like sharpening and the extra is still
// typeable for a soft lens or a heavy downscale.
// #percent label="Amount" group={"Sharpen", "wand.and.rays"} min=0 max=300 slidermax=100 default=40
uniform float uAmount;

// The size of the detail being lifted, in pixels of the rendered frame. Around
// 1 is grain-and-pore fine, 3 or more starts shaping edges rather than
// texture. It is a distance, so it divides by the resolution below and the
// same setting means the same softness at 1080 and at 4K.
// #float label="Radius" group={"Sharpen", "wand.and.rays"} units="px" min=0.5 max=5 default=1
uniform float uRadius;

// Edge masking, and the control that separates a sharpen from a noise
// amplifier. Flat areas have detail too, it is just sensor noise and codec
// mush, and an unmasked unsharp mask lifts it with the same enthusiasm as an
// eyelash. This sets how much local contrast a pixel must already have before
// it is allowed any sharpening at all. At 0 nothing is masked.
// #percent label="Detail" group={"Sharpen", "wand.and.rays"} min=0 max=100 default=25
uniform float uDetail;

// On sharpens the brightness and leaves the colour alone. A full RGB unsharp
// mask sharpens each channel independently, so a red-against-blue edge gets
// its channels pushed in opposite directions and grows a coloured seam that no
// amount of Amount will make look intentional. Off is there for the rare case
// of a flat graphic with no chroma edges to fringe.
// #bool label="Luminance Only" group={"Sharpen", "wand.and.rays"} default=true
uniform bool uLumaOnly;

const vec3 kLumaWeights = vec3(0.2126, 0.7152, 0.0722);

// Two rings of taps rather than a square kernel. A ring is isotropic, which
// matters because an anisotropic blur estimate turns into an anisotropic
// sharpen and diagonal edges come out crunchier than horizontal ones. The
// inner four sit on the diagonals so the rings interleave instead of stacking
// on the same bearings, and the whole thing costs 13 reads instead of the 25 a
// 5x5 Gaussian would want at this radius.
const vec2 kInnerRing[4] = vec2[4](vec2(0.7071, 0.7071), vec2(-0.7071, 0.7071),
                                   vec2(-0.7071, -0.7071), vec2(0.7071, -0.7071));

const vec2 kOuterRing[8] = vec2[8](vec2(1.0, 0.0), vec2(0.7071, 0.7071),
                                   vec2(0.0, 1.0), vec2(-0.7071, 0.7071),
                                   vec2(-1.0, 0.0), vec2(-0.7071, -0.7071),
                                   vec2(0.0, -1.0), vec2(0.7071, -0.7071));

// The Gaussian those three distances land on for a sigma of half the radius:
// exp(0), exp(-0.5) at 0.5r, exp(-2) at r. Ring weights rather than invented
// ones, because the difference between the source and a NON-Gaussian blur has
// ringing built into it before any control is touched.
const float kCenterWeight = 1.0;
const float kInnerWeight = 0.6065;
const float kOuterWeight = 0.1353;

// The mask, measured as contrast RELATIVE to the local level rather than as an
// absolute difference. In linear light the same visible edge is a hundred
// times smaller a number in the shadows than in the highlights, so an absolute
// threshold would mask the shadows out entirely and touch nothing in the
// highlights. A ratio is the same number wherever the edge sits.
//
// The knee runs from a quarter of the threshold up to it, so the mask fades in
// over a range instead of switching, and a gradient drifting past the
// threshold stays smooth rather than growing a contour.
float detailMask(float contrast, float detail)
{
	if (detail <= 0.0)
		return 1.0;
	float knee = detail * 0.2;
	return smoothstep(knee * 0.25, knee, contrast);
}

void mirageFilterImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;
	vec4 src = texture(iChannel0, uv);

	// Everything below happens in linear light. Detail is a difference, and a
	// difference of gamma-encoded code values is not a difference of light: the
	// same edge measures wide in the shadows and narrow in the highlights, so
	// an encoded sharpen quietly favours the dark half of every edge and reads
	// as grubby. Decoding costs 13 curves per pixel and is what makes the
	// overshoot symmetric.
	vec3 source = decodeToLinear(src.rgb);
	float sourceY = dot(source, kLumaWeights);

	vec2 texel = uRadius / iResolution.xy;

	vec3 blur = source * kCenterWeight;
	float weight = kCenterWeight;

	// The neighbourhood extremes, collected on the same taps the blur is built
	// from so the halo clamp at the end costs no extra reads.
	vec3 lo = source;
	vec3 hi = source;
	float loY = sourceY;
	float hiY = sourceY;

	for (int i = 0; i < 4; i++)
	{
		vec3 c = decodeToLinear(texture(iChannel0, uv + kInnerRing[i] * texel * 0.5).rgb);
		blur += c * kInnerWeight;
		weight += kInnerWeight;
		lo = min(lo, c);
		hi = max(hi, c);
		float y = dot(c, kLumaWeights);
		loY = min(loY, y);
		hiY = max(hiY, y);
	}

	for (int i = 0; i < 8; i++)
	{
		vec3 c = decodeToLinear(texture(iChannel0, uv + kOuterRing[i] * texel).rgb);
		blur += c * kOuterWeight;
		weight += kOuterWeight;
		lo = min(lo, c);
		hi = max(hi, c);
		float y = dot(c, kLumaWeights);
		loY = min(loY, y);
		hiY = max(hiY, y);
	}

	blur /= weight;
	float blurY = dot(blur, kLumaWeights);

	// Local contrast from luma alone even in the RGB path, so the mask makes
	// one decision per pixel. Masking each channel by its own contrast would
	// let a channel through on an edge the other two do not see, which is the
	// fringing the Luminance Only switch exists to avoid.
	float contrast = abs(sourceY - blurY) / max(blurY, 0.02);
	float gain = uAmount * detailMask(contrast, uDetail);

	vec3 result;
	if (uLumaOnly)
	{
		// Sharpen the luma and carry the pixel there by a gain, which holds the
		// chromaticity exactly: the ratio between the channels never changes,
		// so a lifted edge gets brighter and not paler. A pure black pixel has
		// no ratio to hold and stays black, which is correct rather than
		// convenient, since there is no colour there to sharpen.
		float y = sourceY + (sourceY - blurY) * gain;

		// The halo clamp, always on and deliberately not a control. Overshoot
		// is what a halo IS: the sharpened value leaves the range of the pixels
		// it was computed from, and a light rim appears alongside every dark
		// edge. Held inside the neighbourhood the edge still gains all its
		// slope, because a real edge has bright pixels a tap away to be clamped
		// against, while a flat area has nothing to overshoot into and so
		// cannot ring. Exposing it would only offer users the artefact.
		y = clamp(y, loY, hiY);
		result = source * (y / max(sourceY, 1e-5));
	}
	else
	{
		result = source + (source - blur) * gain;
		result = clamp(result, lo, hi);
	}

	fragColor = vec4(encodeFromLinear(max(result, 0.0)), src.a);
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
