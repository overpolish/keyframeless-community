// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template filter

// #choice label="Style" group={"Noise", "aqi.medium"} options="Fine,Film,Coarse,Colour" default=0
uniform int uStyle;

// #percent label="Amount" group="Noise" min=0 max=100 default=4
uniform float uAmount;

// #int label="Size" group="Noise" units="px" min=1 max=32 slidermax=12 default=1
uniform float uSize;

// #percent label="Softness" group="Noise" min=0 max=100 default=0
uniform float uSoftness;

// #random label="Seed" group="Noise" default=0
uniform float uSeed;

// #choice label="Animation" group={"Motion", "wind"} options="Static,Flicker,Drift" default=0
uniform int uAnimation;

// #float label="Rate" group="Motion" units="×" min=0 max=8 default=1 visibleby=uAnimation visiblevalues={1,2}
uniform float uRate;

// #choice label="Range" group={"Response", "camera.aperture"} options="Even,Shadows,Midtones,Highlights" default=0
uniform int uRange;

// #percent label="Protect Blacks" group="Response" min=0 max=100 default=0
uniform float uProtectBlacks;

// #percent label="Protect Whites" group="Response" min=0 max=100 default=0
uniform float uProtectWhites;

// #choice label="Blend" group={"Finish", "slider.horizontal.3"} options="Natural,Additive,Overlay" default=0
uniform int uBlend;

// #percent label="Mix" group="Finish" min=0 max=100 default=100
uniform float uMix;

float noiseHash(vec2 p, float seed)
{
	p = fract((p + seed * vec2(0.071, 0.113)) * vec2(0.3183099, 0.3678794)) + 0.1;
	p += dot(p, p + 19.19);
	return fract(p.x * p.y);
}

float valueNoise(vec2 p, float seed)
{
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 curve = f * f * (3.0 - 2.0 * f);

	float a = noiseHash(cell, seed);
	float b = noiseHash(cell + vec2(1.0, 0.0), seed);
	float c = noiseHash(cell + vec2(0.0, 1.0), seed);
	float d = noiseHash(cell + vec2(1.0, 1.0), seed);

	return mix(mix(a, b, curve.x), mix(c, d, curve.x), curve.y);
}

float noiseSample(vec2 p, float seed, float softness)
{
	float crisp = noiseHash(floor(p), seed);
	float smoothed = valueNoise(p, seed);
	return mix(crisp, smoothed, softness) * 2.0 - 1.0;
}

float filmNoise(vec2 p, float seed, float softness)
{
	float a = noiseSample(p, seed, softness);
	float b = noiseSample(p + vec2(17.3, 41.7), seed + 23.0, softness);
	float c = noiseSample(p + vec2(53.1, 11.9), seed + 71.0, softness);
	float grain = (a + b + c) / 3.0;
	return sign(grain) * pow(abs(grain), 0.8);
}

float rangeWeight(float luminance, int range)
{
	if (range == 1)
		return 1.0 - smoothstep(0.15, 0.8, luminance);
	if (range == 2)
		return 4.0 * luminance * (1.0 - luminance);
	if (range == 3)
		return smoothstep(0.2, 0.85, luminance);
	return 1.0;
}

vec3 overlayBlend(vec3 base, vec3 blend)
{
	vec3 low = 2.0 * base * blend;
	vec3 high = 1.0 - 2.0 * (1.0 - base) * (1.0 - blend);
	return mix(low, high, step(vec3(0.5), base));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;
	vec4 source = texture(iChannel0, uv);

	float seed = uSeed;
	vec2 motion = vec2(0.0);
	if (uAnimation == 1)
		seed += floor(iTime * uRate * 24.0) * 37.0;
	else if (uAnimation == 2)
		motion = iTime * uRate * vec2(5.7, -3.9);

	vec2 p = fragCoord / max(uSize, 1.0) + motion;
	vec3 noise;

	if (uStyle == 1)
	{
		float n = filmNoise(p, seed, uSoftness);
		noise = vec3(n);
	}
	else if (uStyle == 2)
	{
		float n = noiseSample(p * 0.25, seed, max(uSoftness, 0.65));
		noise = vec3(n);
	}
	else if (uStyle == 3)
	{
		noise = vec3(noiseSample(p, seed + 0.0, uSoftness),
		             noiseSample(p, seed + 47.0, uSoftness),
		             noiseSample(p, seed + 101.0, uSoftness));
	}
	else
	{
		noise = vec3(noiseSample(p, seed, uSoftness));
	}

	float luminance = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
	float response = rangeWeight(luminance, uRange);
	response *= mix(1.0, smoothstep(0.0, 0.25, luminance), uProtectBlacks);
	response *= mix(1.0, 1.0 - smoothstep(0.75, 1.0, luminance), uProtectWhites);

	float strength = pow(uAmount, 1.35) * 0.35 * response;
	vec3 effected;

	if (uBlend == 1)
	{
		effected = source.rgb + noise * strength;
	}
	else if (uBlend == 2)
	{
		vec3 noiseColour = clamp(0.5 + 0.5 * noise, 0.0, 1.0);
		effected = mix(source.rgb, overlayBlend(source.rgb, noiseColour),
		               clamp(strength * 2.85, 0.0, 1.0));
	}
	else
	{
		vec3 headroom = 2.0 * sqrt(max(source.rgb * (1.0 - source.rgb), vec3(0.0)));
		effected = source.rgb + noise * strength * headroom;
	}

	vec3 result = mix(source.rgb, clamp(effected, 0.0, 1.0), uMix);
	fragColor = vec4(result, source.a);
}
