// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template filter

// #choice label="Mode" group={"Style", "circle.lefthalf.filled"} options="Colour,Mono,Duotone" default=2
uniform int uMode;

// #int label="Levels" group="Style" min=2 max=8 default=3
uniform float uLevels;

// #choice label="Pattern" group={"Dither", "circle.grid.3x3.fill"} options="Bayer 2,Bayer 4,Bayer 8,Noise" default=2
uniform int uPattern;

// #int label="Pixel Size" group="Dither" units="px" min=1 max=16 default=6
uniform float uPixelSize;

// #random label="Noise Seed" group="Dither" default=0
uniform float uSeed;

// #percent label="Mix" group={"Output", "slider.horizontal.below.rectangle"} min=0 max=100 default=100
uniform float uMix;

// #color label="Duotone" min=2 max=2 default="#0A0A12,#F2E9E4"
uniform vec4 uColours[2];

const int MODE_COLOUR = 0;
const int MODE_MONO = 1;
const int MODE_DUOTONE = 2;

const int PATTERN_BAYER_2 = 0;
const int PATTERN_BAYER_4 = 1;
const int PATTERN_BAYER_8 = 2;

const int BAYER_2[4] = int[](
                           0, 2,
                           3, 1
                       );

const int BAYER_4[16] = int[](
                            0, 8, 2, 10,
                            12, 4, 14, 6,
                            3, 11, 1, 9,
                            15, 7, 13, 5
                        );

const int BAYER_8[64] = int[](
                            0, 32, 8, 40, 2, 34, 10, 42,
                            48, 16, 56, 24, 50, 18, 58, 26,
                            12, 44, 4, 36, 14, 46, 6, 38,
                            60, 28, 52, 20, 62, 30, 54, 22,
                            3, 35, 11, 43, 1, 33, 9, 41,
                            51, 19, 59, 27, 49, 17, 57, 25,
                            15, 47, 7, 39, 13, 45, 5, 37,
                            63, 31, 55, 23, 61, 29, 53, 21
                        );

float hash21(vec2 value)
{
	value = fract(value * vec2(0.3183099, 0.3678794)) + 0.1;
	value += dot(value, value + 19.19);

	return fract(value.x * value.y);
}

float ditherThreshold(vec2 cell)
{
	if (uPattern == PATTERN_BAYER_2)
	{
		ivec2 position = ivec2(mod(cell, 2.0));
		int index = position.y * 2 + position.x;

		return (float(BAYER_2[index]) + 0.5) / 4.0;
	}

	if (uPattern == PATTERN_BAYER_4)
	{
		ivec2 position = ivec2(mod(cell, 4.0));
		int index = position.y * 4 + position.x;

		return (float(BAYER_4[index]) + 0.5) / 16.0;
	}

	if (uPattern == PATTERN_BAYER_8)
	{
		ivec2 position = ivec2(mod(cell, 8.0));
		int index = position.y * 8 + position.x;

		return (float(BAYER_8[index]) + 0.5) / 64.0;
	}

	return hash21(cell + uSeed * 0.017);
}

float quantize(float value, float threshold, float levels)
{
	float stepSize = 1.0 / (levels - 1.0);
	value += (threshold - 0.5) * stepSize;

	return clamp(
	           floor(value / stepSize + 0.5) * stepSize,
	           0.0,
	           1.0
	       );
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;
	vec4 source = texture(iChannel0, uv);

	float pixelSize = max(float(uPixelSize), 1.0);
	vec2 cell = floor(fragCoord / pixelSize);
	vec2 samplePosition = (cell + 0.5) * pixelSize / iResolution.xy;
	vec4 sampled = texture(iChannel0, clamp(samplePosition, 0.0, 1.0));

	float threshold = ditherThreshold(cell);
	float levels = max(float(uLevels), 2.0);
	vec3 filtered;

	if (uMode == MODE_MONO)
	{
		float luminance = dot(sampled.rgb, vec3(0.299, 0.587, 0.114));
		filtered = vec3(quantize(luminance, threshold, levels));
	}
	else if (uMode == MODE_DUOTONE)
	{
		float luminance = dot(sampled.rgb, vec3(0.299, 0.587, 0.114));
		float amount = quantize(luminance, threshold, levels);
		filtered = mix(uColours[0].rgb, uColours[1].rgb, amount);
	}
	else
	{
		filtered = vec3(
		               quantize(sampled.r, threshold, levels),
		               quantize(sampled.g, threshold, levels),
		               quantize(sampled.b, threshold, levels)
		           );
	}

	vec3 color = mix(source.rgb, filtered, uMix);
	float alpha = mix(source.a, sampled.a, uMix);

	fragColor = vec4(color, alpha);
}
