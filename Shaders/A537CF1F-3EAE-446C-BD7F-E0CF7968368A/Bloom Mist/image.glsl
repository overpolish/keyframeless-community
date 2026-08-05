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

const float GOLDEN_ANGLE = 2.39996322973;

float mistHighlight(float luminance)
{
	float knee = max(uSoftness * 0.5, 0.0001);
	float highlight = clamp((luminance - uThreshold + knee) / (2.0 * knee), 0.0, 1.0);
	return highlight * highlight * (3.0 - 2.0 * highlight);
}

vec3 mistSample(vec2 pixelPosition)
{
	vec2 uv = clamp(pixelPosition / iResolution.xy, 0.0, 1.0);
	return texture(iChannel0, uv).rgb;
}

// Warm and cool as opposed ends of one control, applied to the bloom's tint only.
// Red rises as blue falls, then the result is rescaled to the luminance it started
// at, so pulling the puck sideways changes the colour of the glow and nothing else.
// A hue rotation would have been the obvious mapping and is the wrong one: rotating
// an already-warm swatch far enough to read as cool passes through green or magenta
// on the way, so both ends of the axis land somewhere unwanted. It is the same
// reason this control stayed as it is while the hue moves in Chroma and Qualifier
// went to Oklab. This is a gain, the shape of a white balance, not a hue being aimed
// at an angle.
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

	int sampleCount = 24;
	if (uQuality == 0) sampleCount = 12;
	if (uQuality == 2) sampleCount = 40;

	vec3 diffuse = source.rgb;
	vec3 bloom = source.rgb * mistHighlight(dot(source.rgb, LUMA));
	float totalWeight = 1.0;

	for (int i = 0; i < 40; ++i)
	{
		if (i >= sampleCount) break;

		float index = float(i) + 0.5;
		float radiusFraction = sqrt(index / float(sampleCount));
		float angle = index * GOLDEN_ANGLE;
		vec2 direction = vec2(cos(angle), sin(angle));
		vec2 offset = direction * radiusFraction * uRadius * iResolution.y / 1080.0;
		float weight = exp(-2.2 * radiusFraction * radiusFraction);

		vec3 sampleColor = mistSample(fragCoord + offset);
		float luminance = dot(sampleColor, LUMA);

		diffuse += sampleColor * weight;
		bloom += sampleColor * mistHighlight(luminance) * weight;
		totalWeight += weight;
	}

	diffuse /= totalWeight;
	bloom /= totalWeight;

	vec3 bloomTint = temperedTint(mix(vec3(1.0), uBloomColor.rgb, uBloomColor.a), uWarmCool);
	vec3 tintedBloom = bloom * bloomTint;

	vec3 color = mix(source.rgb, diffuse, uDiffusion * 0.35);

	float diffuseLuminance = dot(diffuse, LUMA);
	vec3 veilColor = mix(diffuse, bloomTint * diffuseLuminance, 0.65);
	color = mix(color, veilColor, uMist * 0.14);

	float sourceLuminance = dot(source.rgb, LUMA);
	float shadowMask = 1.0 - smoothstep(0.0, 0.55, sourceLuminance);
	color += bloomTint * shadowMask * uBlackLift * 0.045;

	color += tintedBloom * (uBloom * 1.4 + uMist * 0.3);

	fragColor = vec4(mix(source.rgb, color, uMix), source.a);
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
