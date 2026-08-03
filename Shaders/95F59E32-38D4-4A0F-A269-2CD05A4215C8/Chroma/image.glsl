// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template filter

// #color-surface ring=hue

// #percent label="Saturation" group={"Chroma", "camera.filters"} min=0 max=200 default=100 surface="r:+35"
uniform float uSaturation;

// #float label="Hue Rotate" group={"Chroma", "camera.filters"} units="°" min=-180 max=180 default=0 surface="a:+180"
uniform float uHueRotate;

// #percent label="Vibrance" group={"Chroma", "camera.filters"} min=-100 max=100 default=0
uniform float uVibrance;

// #percent label="Protect Skin" group={"Protect", "circle.dashed"} min=0 max=100 default=0
uniform float uProtectSkin;

// #percent label="Shadow Desaturation" group={"Protect", "circle.dashed"} min=0 max=100 default=0
uniform float uShadowDesat;

// #percent label="Mix" group={"Finish", "switch.2"} min=0 max=100 default=100
uniform float uMix;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

// The most colourful thing Rec.709 can show sits at about this Oklab chroma, so
// dividing by it turns chroma into the 0..1 reading Vibrance weights itself by.
const float MAX_CHROMA = 0.33;

// Hue rotation as what it actually is: the a/b vector turned by the angle asked for.
// This was a luma-preserving RGB matrix, which is an approximation of that turn and
// misses the hue it aimed at by up to 29 degrees measured against the panel's own
// ring. Turning the vector cannot miss, and it leaves lightness alone because
// lightness is not one of the two numbers it touches.
vec3 turnHue(vec3 lab, float degreesShift)
{
	float a = radians(degreesShift);
	float cs = cos(a);
	float sn = sin(a);
	return vec3(lab.x,
	            lab.y * cs - lab.z * sn,
	            lab.y * sn + lab.z * cs);
}

// How colourful a pixel already is, 0..1. Vibrance needs it: it is not a global
// amount, it is an amount weighted by what is there. Turning a hue does not change
// it, so it is read once, after the turn.
float colourfulness(vec3 lab)
{
	return clamp(length(lab.yz) / MAX_CHROMA, 0.0, 1.0);
}

// A soft window around the skin hues, from orange through to red. Rolls off rather
// than switching, because a hard hue window shows itself as an edge across a face
// the moment saturation moves at all.
float skinWeight(vec3 lab)
{
	if (length(lab.yz) < 0.0001) return 0.0;
	float hue = degrees(atan(lab.z, lab.y));
	if (hue < 0.0) hue += 360.0;
	// Centred on 56 degrees, which is where the orange-red band skin occupies lands
	// in Oklab. Same window as the RGB-wheel one it replaces, re-measured in the
	// space the saturation move now happens in, so the protection sits on the thing
	// it is protecting rather than a few degrees to one side of it.
	float distance = abs(mod(hue - 56.0 + 180.0, 360.0) - 180.0);
	return 1.0 - smoothstep(30.0, 58.0, distance);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;
	vec4 source = texture(iChannel0, uv);

	vec3 linear = decodeToLinear(source.rgb);
	float luminance = dot(linear, LUMA);

	// Hue and saturation are both moves on the a/b vector, so the pixel goes to Oklab
	// once and comes back once, and everything in between is an angle and a length
	// rather than three channels pulling against each other.
	vec3 rotated = turnHue(linearToOklab(max(linear, 0.0)), uHueRotate);

	// Vibrance rides on top of saturation and pulls in the opposite direction to how
	// colourful the pixel already is, so it opens up flat colour without pushing
	// what is already saturated into a clipped primary.
	float already = colourfulness(rotated);
	float amount = uSaturation + uVibrance * (1.0 - already);

	// Both protections work by pulling the LOCAL amount back toward 1.0 rather than
	// by desaturating afterwards, so they cannot fight the move the puck just made.
	// The shadow gate reads luminance rather than lightness because it is a question
	// about light: how dark is this pixel, not what colour is it.
	float protect = skinWeight(rotated) * uProtectSkin;
	float shadow = (1.0 - smoothstep(0.0, 0.35, luminance)) * uShadowDesat;
	amount = mix(amount, 1.0, clamp(protect, 0.0, 1.0));
	amount = mix(amount, 0.0, clamp(shadow, 0.0, 1.0));

	// Saturation as a stretch of the chroma vector. At zero it lands on a true
	// neutral of the lightness the pixel already had, instead of on a luma-weighted
	// grey that reads light or dark depending on which hue it came from.
	vec3 saturated = oklabToLinear(vec3(rotated.x, rotated.y * amount, rotated.z * amount));

	vec3 graded = encodeFromLinear(saturated);
	fragColor = vec4(mix(source.rgb, graded, uMix), source.a);
}
