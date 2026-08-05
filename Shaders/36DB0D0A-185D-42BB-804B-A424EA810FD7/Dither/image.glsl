// SPDX-FileCopyrightText: The paper-design/shaders authors
// SPDX-License-Identifier: Apache-2.0

// #template generator
// #alpha
// SPDX-FileContributor: Modified by overpolish in 2026

// Derived from https://github.com/paper-design/shaders

// #speed group={"Motion", "wind"}
// #seed group="Motion"

// The two BRACKETING swatches are compared against the dither threshold, so
// both are needed whole. A #gradient returns one interpolated colour, which
// turns the dither into a blur.
// #color label="Colours" min=2 max=6 default="#0A0A12,#F2E9E4"
uniform vec4 uColours[6];

// #choice label="Shape" group={"Pattern", "circle.grid.3x3.fill"} options="Simplex,Warp,Dots,Wave,Ripple,Swirl" default=0
uniform int uShape;

// #choice label="Dither" group="Pattern" options="Random,Bayer 2,Bayer 4,Bayer 8" default=3
uniform int uDither;

// #int label="Pixel Size" group="Pattern" units="px" min=1 max=32 default=2
uniform float uPixelSize;

// #point label="Center" group={"Transform", "viewfinder"} osc=position default="0.5,0.5"
uniform vec2 uCenter;

// #percent label="Scale" group="Transform" min=25 max=400 default=100 osc=ring link=uCenter
uniform float uScale;

const float TAU = 6.28318530718;

const int SHAPE_SIMPLEX = 0;
const int SHAPE_WARP = 1;
const int SHAPE_DOTS = 2;
const int SHAPE_WAVE = 3;
const int SHAPE_RIPPLE = 4;

const int DITHER_RANDOM = 0;
const int DITHER_BAYER_2 = 1;
const int DITHER_BAYER_4 = 2;

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

float hash11(float value)
{
	value = fract(value * 0.1031);
	value *= value + 33.33;
	value *= value + value;

	return fract(value);
}

float hash21(vec2 value)
{
	value = fract(value * vec2(0.3183099, 0.3678794)) + 0.1;
	value += dot(value, value + 19.19);

	return fract(value.x * value.y);
}

vec3 mod289(vec3 value)
{
	return value - floor(value / 289.0) * 289.0;
}

vec3 permute(vec3 value)
{
	return mod289((value * 34.0 + 1.0) * value);
}

float simplexNoise(vec2 position)
{
	const vec4 coefficients = vec4(
	                              0.211324865405187,
	                              0.366025403784439,
	                              -0.577350269189626,
	                              0.024390243902439
	                          );

	vec2 cell = floor(position + dot(position, coefficients.yy));
	vec2 local = position - cell + dot(cell, coefficients.xx);
	vec2 offset = local.x > local.y ? vec2(1.0, 0.0) : vec2(0.0, 1.0);

	vec4 corners = local.xyxy + coefficients.xxzz;
	corners.xy -= offset;

	cell = mod(cell, 289.0);

	vec3 permutation = permute(
	                       permute(cell.y + vec3(0.0, offset.y, 1.0)) +
	                       cell.x +
	                       vec3(0.0, offset.x, 1.0)
	                   );

	vec3 weight = max(
	                  0.5 - vec3(
	                      dot(local, local),
	                      dot(corners.xy, corners.xy),
	                      dot(corners.zw, corners.zw)
	                  ),
	                  0.0
	              );

	weight *= weight;
	weight *= weight;

	vec3 gradient = 2.0 * fract(permutation * coefficients.www) - 1.0;
	vec3 height = abs(gradient) - 0.5;
	vec3 rounded = floor(gradient + 0.5);
	vec3 remainder = gradient - rounded;

	weight *=
	    1.79284291400159 -
	    0.85373472095314 *
	    (remainder * remainder + height * height);

	vec3 contribution;
	contribution.x = remainder.x * local.x + height.x * local.y;
	contribution.yz = remainder.yz * corners.xz + height.yz * corners.yw;

	return 130.0 * dot(weight, contribution);
}

float layeredNoise(vec2 position, float time)
{
	float noise = 0.5 * simplexNoise(position - vec2(0.0, time * 0.3));
	noise += 0.5 * simplexNoise(position * 2.0 + vec2(0.0, time * 0.32));

	return noise;
}

float bayerValue(vec2 position, int size)
{
	ivec2 cell = ivec2(fract(position / float(size)) * float(size));
	int index = cell.y * size + cell.x;

	if (size == 2)
		return float(BAYER_2[index]) / 4.0;

	if (size == 4)
		return float(BAYER_4[index]) / 16.0;

	if (size == 8)
		return float(BAYER_8[index]) / 64.0;

	return 0.0;
}

float shapeField(vec2 position, float time)
{
	if (uShape == SHAPE_SIMPLEX)
	{
		position *= 0.001;

		float shape = 0.5 + 0.5 * layeredNoise(position, time);
		return smoothstep(0.3, 0.9, shape);
	}

	if (uShape == SHAPE_WARP)
	{
		position *= 0.003;

		for (float i = 1.0; i < 6.0; i += 1.0)
		{
			position.x += 0.6 / i * cos(i * 2.5 * position.y + time);
			position.y += 0.6 / i * cos(i * 1.5 * position.x + time);
		}

		float shape =
		    0.15 /
		    max(0.001, abs(sin(time - position.y - position.x)));

		return smoothstep(0.02, 1.0, shape);
	}

	if (uShape == SHAPE_DOTS)
	{
		position *= 0.05;

		float stripe = floor(2.0 * position.x / TAU);
		float randomValue = hash11(stripe * 10.0);
		randomValue = sign(randomValue - 0.5) * pow(0.1 + abs(randomValue), 0.4);

		float shape =
		    sin(position.x) *
		    cos(position.y - 5.0 * randomValue * time);

		return pow(abs(shape), 6.0);
	}

	if (uShape == SHAPE_WAVE)
	{
		position *= 4.0;

		float wave =
		    cos(position.x * 0.5 - time * 2.0) *
		    sin(position.x * 1.5 + time) *
		    (0.75 + 0.25 * cos(time * 3.0));

		return 1.0 - smoothstep(-1.0, 1.0, position.y + wave);
	}

	if (uShape == SHAPE_RIPPLE)
	{
		float distance = length(position);
		return sin(pow(distance, 1.7) * 7.0 - time * 3.0) * 0.5 + 0.5;
	}

	float distance = length(position);
	float angle = 6.0 * atan(position.y, position.x) + time * 4.0;
	float twist = 1.2;
	float offset = 1.0 / pow(max(distance, 0.000001), twist) + angle / TAU;
	float centerBlend = smoothstep(0.0, 1.0, pow(distance, twist));

	return mix(0.0, fract(offset), centerBlend);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	float aspect = iResolution.x / iResolution.y;
	float time = iTime * 0.5;

	vec2 referenceResolution = vec2(aspect * 1080.0, 1080.0);
	float pixelSize = max(float(uPixelSize), 1.0);

	vec2 pixelCoord = (fragCoord - iResolution.xy * 0.5) / pixelSize;
	vec2 pixelizedCoord = (floor(pixelCoord) + 0.5) * pixelSize;
	vec2 normalizedPosition = pixelizedCoord / iResolution.xy;

	vec2 center = uCenter / iResolution.xy;
	normalizedPosition -= center - 0.5;
	normalizedPosition /= max(uScale, 0.01);

	vec2 shapePosition;

	if (uShape > SHAPE_DOTS)
	{
		float minReference = min(referenceResolution.x, referenceResolution.y);
		shapePosition = normalizedPosition * (referenceResolution / minReference);
	}
	else
	{
		shapePosition = normalizedPosition * referenceResolution + 0.5;
	}

	float shape = clamp(shapeField(shapePosition, time), 0.0, 1.0);
	float threshold;

	if (uDither == DITHER_RANDOM)
		threshold = hash21(pixelizedCoord);
	else if (uDither == DITHER_BAYER_2)
		threshold = bayerValue(pixelCoord, 2);
	else if (uDither == DITHER_BAYER_4)
		threshold = bayerValue(pixelCoord, 4);
	else
		threshold = bayerValue(pixelCoord, 8);

	int colorCount = max(uColoursCount, 1);
	float palettePosition = shape * float(colorCount - 1);
	int lower = clamp(int(floor(palettePosition)), 0, colorCount - 1);
	int upper = min(lower + 1, colorCount - 1);
	float blend = palettePosition - float(lower);

	vec4 color = blend > threshold ? uColours[upper] : uColours[lower];

	fragColor = color;
}
