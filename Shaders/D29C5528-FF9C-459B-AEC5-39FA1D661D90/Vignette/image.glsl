// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template filter

// Positive darkens, negative lifts. It is a stop count rather than a percentage
// because that is what the falloff physically is, and because a signed slider that
// passes cleanly through zero is one control instead of a direction menu plus a
// depth. A lifted vignette is the useful other half of this effect: it opens a face
// out of a corner the same way a bounce card does.
// #float label="Amount" group={"Vignette", "circle.dashed"} units="stops" min=-4 max=4 default=0.8
uniform float uAmount;

// Where the falloff begins, measured from the centre out to the frame corner, so
// 100% is a vignette that has only just reached the corners.
// The on-screen ring IS the vignette boundary: drag its edge outward to push the
// falloff away, inward to close the vignette down. It rides the Center point.
// #percent label="Size" group="Vignette" min=0 max=100 default=55 osc=ring link=uCenter
uniform float uSize;

// How far past Size the falloff takes to reach full strength. Wide is the point:
// a finishing vignette should be impossible to find the edge of.
// #percent label="Softness" group="Vignette" min=1 max=150 default=60
uniform float uSoftness;

// 100% is a circle, 0% follows the shape of the frame. Neither is right for every
// shot: a round vignette on a wide frame leaves the short edges untouched, and a
// frame-shaped one can read as a border rather than as light falling off.
// #percent label="Roundness" group="Vignette" min=0 max=100 default=100
uniform float uRoundness;

// #point label="Center" group="Vignette" osc=position default="0.5,0.5"
uniform vec2 uCenter;

// A colour for the shaded region only. Warm-neutral by default because the classic
// reason to tint a vignette is to stop the corners going blue as they go down, which
// is what an untinted darkening does to a daylight-balanced shot.
// #color label="Tint" default="#FFDDB8"
uniform vec4 uTint;

// Zero by default: the tint is an option, not part of the look, and a template that
// arrives already casting warm is one the user has to undo before using.
// #percent label="Tint Amount" group={"Tint", "paintbrush"} min=0 max=100 default=0
uniform float uTintAmount;

// #percent label="Mix" group={"Finish", "switch.2"} min=0 max=100 default=100
uniform float uMix;

// 0 at the centre, 1 at the frame corner, and monotone outward along any ray.
float vignetteMask(vec2 uv, vec2 resolution)
{
	float aspect = resolution.x / resolution.y;
	vec2 offset = (uv - uCenter / resolution) * 2.0;

	// Two readings of the same offset. The pixel-corrected one measures both axes in
	// units of frame HEIGHT, so a circle drawn in it is round on a 16:9 frame instead
	// of being stretched into the shape of the picture. The frame-relative one
	// measures each axis against its own half-extent, so a superellipse drawn in it
	// hugs the frame's own proportions. Roundness crossfades the coordinates AND the
	// exponent together, because a rounded rectangle needs both: the square-ish
	// exponent alone in circular coordinates gives a square on a wide frame.
	float roundness = clamp(uRoundness, 0.0, 1.0);
	vec2 corrected = offset * vec2(aspect, 1.0);
	vec2 p = mix(offset, corrected, roundness);
	float power = mix(4.0, 2.0, roundness);

	// The corner is measured with the SAME metric, so Size keeps meaning "fraction of
	// the way to the corner" at every roundness and every aspect ratio. Without this
	// the default look would change with the shape of the frame.
	vec2 cornerRef = mix(vec2(1.0), vec2(aspect, 1.0), roundness);
	float corner = pow(pow(cornerRef.x, power) + pow(cornerRef.y, power), 1.0 / power);
	float d = pow(pow(abs(p.x), power) + pow(abs(p.y), power), 1.0 / power);

	float radius = d / max(corner, 0.0001);
	float size = clamp(uSize, 0.0, 1.0);
	float feather = max(uSoftness, 0.001);

	return smoothstep(size, size + feather, radius);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 resolution = iResolution.xy;
	vec2 uv = fragCoord / resolution;
	vec4 source = texture(iChannel0, uv);

	float mask = vignetteMask(uv, resolution);
	vec3 linear = decodeToLinear(source.rgb);

	// EXPOSURE, not a multiply on the code values. A vignette is the lens losing light
	// towards the edge of the field, so the honest control is a stop count and the
	// honest operation is exp2 in linear light: the corner keeps the ratios between
	// its own tones and simply sits lower, exactly as an underexposed frame does.
	// The same darkening applied to the encoded picture is not a stop at all - it
	// compresses hardest where the encoding is steepest, so the shadows in the corner
	// hit black while the highlights have barely moved, which is the flat, dirty
	// vignette that gets blamed on the plugin.
	linear *= exp2(-uAmount * mask);

	// The tint is a filter normalised to luminance 1, so Tint Amount bends the colour
	// of the shaded region and nothing else. Multiplying the raw swatch in would make
	// every tint a second, hidden darkening, and the Amount slider would stop being
	// the only answer to "how deep is it".
	vec3 tint = decodeToLinear(uTint.rgb);
	float tintLuma = dot(tint, vec3(0.2126, 0.7152, 0.0722));
	vec3 tintFilter = tintLuma > 0.0001 ? tint / tintLuma : vec3(1.0);
	linear *= mix(vec3(1.0), tintFilter, clamp(uTintAmount, 0.0, 1.0) * mask);

	vec3 graded = encodeFromLinear(max(linear, 0.0));
	fragColor = vec4(mix(source.rgb, graded, uMix), source.a);
}
