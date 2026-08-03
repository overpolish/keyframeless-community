// SPDX-FileCopyrightText: Rich Harris
// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template transition
//
// Random function derived from:
// http://byteblacksmith.com/improvements-to-the-canonical-one-liner-glsl-rand-for-opengl-es-2-0/
//
// Value noise based on work by Morgan McGuire:
// https://www.shadertoy.com/view/4dS3Wd

// #float label="Detail" group={"Pattern", "circle.hexagongrid"} min=0.5 max=80 slidermax=40 default=4
uniform float uScale;

// #int label="Octaves" group="Pattern" min=1 max=5 default=1
uniform float uOctaves;

// #float label="Contrast" group="Pattern" min=0.25 max=4 default=1
uniform float uContrast;

// #choice label="Order" group="Pattern" options="Low First,High First" default=0
uniform int uOrder;

// #bool label="Square Cells" group="Pattern" default=0
uniform bool uSquareCells;

// #angle label="Rotation" group="Pattern" osc={z} default=0
uniform float uRotation;

// #multi label="Offset" group="Pattern" fields={X,Y} percent min=-100 max=100 default="0,0"
uniform vec2 uOffset;

// #random label="Seed" group="Pattern" default=13
uniform float uSeed;

// #percent label="Softness" group={"Dissolve", "sparkles"} min=0 max=50 default=1
uniform float uSmoothness;

float randomValue(vec2 position)
{
	float first = uSeed;
	float second = 78.233;
	float value = dot(position, vec2(first, second));
	value = mod(value, 3.14);
	return fract(sin(value) * 43758.5453);
}

float valueNoise(vec2 position)
{
	vec2 cell = floor(position);
	vec2 local = fract(position);

	float bottomLeft = randomValue(cell);
	float bottomRight = randomValue(cell + vec2(1.0, 0.0));
	float topLeft = randomValue(cell + vec2(0.0, 1.0));
	float topRight = randomValue(cell + vec2(1.0, 1.0));

	vec2 blend = local * local * (3.0 - 2.0 * local);

	return mix(bottomLeft, bottomRight, blend.x)
	       + (topLeft - bottomLeft) * blend.y * (1.0 - blend.x)
	       + (topRight - bottomRight) * blend.x * blend.y;
}

float fractalNoise(vec2 position)
{
	float value = 0.0;
	float totalWeight = 0.0;
	float amplitude = 1.0;
	int octaveCount = int(uOctaves);

	for (int i = 0; i < 5; ++i)
	{
		if (i >= octaveCount)
			break;

		value += valueNoise(position) * amplitude;
		totalWeight += amplitude;
		position = position * 2.03 + vec2(17.1, 9.2);
		amplitude *= 0.5;
	}

	return value / max(totalWeight, 0.0001);
}

vec2 rotatePattern(vec2 position, float angle)
{
	float sine = sin(angle);
	float cosine = cos(angle);
	return mat2(cosine, -sine, sine, cosine) * position;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;
	float progress = clamp(iProgress, 0.0, 1.0);

	vec4 fromColor = texture(iChannel0, uv);
	vec4 toColor = texture(iChannel1, uv);

	if (progress <= 0.0)
	{
		fragColor = fromColor;
		return;
	}

	if (progress >= 1.0)
	{
		fragColor = toColor;
		return;
	}

	vec2 patternPosition = uv - 0.5;

	if (uSquareCells)
		patternPosition.x *= iResolution.x / iResolution.y;

	patternPosition = rotatePattern(patternPosition, uRotation);
	patternPosition += 0.5 + uOffset;

	float noiseValue = fractalNoise(patternPosition * uScale);
	noiseValue = clamp(0.5 + (noiseValue - 0.5) * uContrast, 0.0, 1.0);

	if (uOrder == 1)
		noiseValue = 1.0 - noiseValue;

	float softness = max(uSmoothness, 0.0001);
	float threshold = mix(-softness, 1.0 + softness, progress);
	float reveal = 1.0 - smoothstep(threshold - softness, threshold + softness, noiseValue);

	fragColor = mixTransitionColors(fromColor, toColor, reveal);
}