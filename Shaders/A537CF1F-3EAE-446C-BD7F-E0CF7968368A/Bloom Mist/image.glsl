// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template filter

// #alpha
// #color-surface ring=light xaxis="Cool,Warm" yaxis="Clean,Glow"

// #choice label="Quality" group={"Bloom", "sparkles"} options="Draft,Standard,High" default=1
uniform int uQuality;

// #percent label="Threshold" group="Bloom" min=0 max=100 default=58 surface="y:-12" pick=luma
uniform float uThreshold;

// #percent label="Softness" group="Bloom" min=0 max=100 default=35
uniform float uSoftness;

// #int label="Radius" group="Bloom" units="px" min=1 slidermax=120 default=36
uniform float uRadius;

// #percent label="Bloom" group="Bloom" min=0 max=150 default=45 surface="y:+40"
uniform float uBloom;

// #percent label="Diffusion" group={"Mist", "cloud.fog"} min=0 max=100 default=18
uniform float uDiffusion;

// #percent label="Mist" group="Mist" min=0 max=100 default=22 surface="y:+18"
uniform float uMist;

// #percent label="Black Lift" group="Mist" min=0 max=100 default=6
uniform float uBlackLift;

// #percent label="Mix" group={"Finish", "switch.2"} min=0 max=100 default=100
uniform float uMix;

// The tint of the glow is a property of the light making it, so it can be lifted
// off the frame: eyedropper the practical, the window, the sky, and the bloom
// carries that colour instead of a guessed swatch. Warm / Cool then moves it along
// the axis from there.
// #color label="Bloom Colour" default="#FFF2DE" pick=color
uniform vec4 uBloomColor;

// #float label="Warm / Cool" group="Finish" min=-100 max=100 default=0 surface="x:+45"
uniform float uWarmCool;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec3 temperedTint(vec3 tint, float warmCool)
{
	float k = warmCool / 100.0;
	vec3 tempered = tint * vec3(1.0 + 0.60 * k, 1.0 - 0.08 * abs(k), 1.0 - 0.60 * k);
	return tempered * (dot(tint, LUMA) / max(dot(tempered, LUMA), 0.0001));
}

void mirageFilterImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;
	vec4 source = texture(iChannel0, uv);
	vec4 blurredHighlights = texture(iChannel3, uv);

	vec3 bloomTint = temperedTint(
		mix(vec3(1.0), uBloomColor.rgb, uBloomColor.a), uWarmCool);
	vec3 tintedBloom = blurredHighlights.rgb * bloomTint;

	// Diffusion is the close haze around highlights; Mist is the wider veil.
	// Both now come from a continuous separable blur rather than recognizable
	// copies sampled around a spiral.
	vec3 color = source.rgb;
	color += tintedBloom * uDiffusion * 0.35;

	float bloomLuminance = dot(blurredHighlights.rgb, LUMA);
	vec3 veilColor = bloomTint * bloomLuminance;
	color += veilColor * uMist * 0.14;

	vec3 straightSource = source.a > 0.0001 ? source.rgb / source.a : vec3(0.0);
	float sourceLuminance = dot(straightSource, LUMA);
	float shadowMask = 1.0 - smoothstep(0.0, 0.55, sourceLuminance);
	color += bloomTint * shadowMask * uBlackLift * 0.045 * source.a;

	color += tintedBloom * (uBloom * 1.4 + uMist * 0.3);
	fragColor = vec4(mix(source.rgb, color, uMix), source.a);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	mirageFilterImage(fragColor, fragCoord);
	if (fragColor.a > 0.0001)
		fragColor.rgb /= fragColor.a;
	else
		fragColor.rgb = vec3(0.0);
}
