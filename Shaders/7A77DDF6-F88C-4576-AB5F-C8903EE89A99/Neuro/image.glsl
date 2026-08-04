// SPDX-FileCopyrightText: The paper-design/shaders authors
// SPDX-FileContributor: Modified by overpolish in 2026
// SPDX-License-Identifier: Apache-2.0

// #template generator
// #alpha
//
// Derived from https://github.com/paper-design/shaders

// #speed group={"Motion", "wind"}
// #seed group="Motion"

// #grain label="Grain" group={"Finish", "camera.filters"} default=0 size=2

// #color label="Colours" min=2 max=5 default="#06080F,#1B4A6B,#57E0FF"
uniform vec4 uColours[5];

// #int label="Complexity" group={"Pattern", "point.3.connected.trianglepath.dotted"} min=4 max=20 default=15
uniform float uComplexity;

// #percent label="Brightness" group={"Appearance", "sun.max.fill"} min=0 max=200 default=20
uniform float uBrightness;

// #percent label="Contrast" group="Appearance" min=0 max=100 default=15
uniform float uContrast;

// #point label="Center" group={"Transform", "viewfinder"} osc=position default="0.5,0.5"
uniform vec2 uCenter;

// #percent label="Scale" group="Transform" min=25 max=400 default=100 osc=ring link=uCenter
uniform float uScale;

vec2 rotate(vec2 value, float angle)
{
	float sine = sin(angle);
	float cosine = cos(angle);
	return vec2(
	           cosine * value.x + sine * value.y,
	           -sine * value.x + cosine * value.y
	       );
}

float neuroShape(vec2 position)
{
	vec2 sineAccumulator = vec2(0.0);
	vec2 result = vec2(0.0);
	float frequency = 8.0;
	int complexity = int(uComplexity);

	for (int i = 0; i < 20; ++i)
	{
		if (i >= complexity)
			break;

		position = rotate(position, 1.0);
		sineAccumulator = rotate(sineAccumulator, 1.0);

		vec2 layer = position * frequency + float(i) + sineAccumulator - iTime * 0.5;
		sineAccumulator += sin(layer);
		result += (0.5 + 0.5 * cos(layer)) / frequency;
		frequency *= 1.2;
	}

	return result.x + result.y;
}

vec4 palette(float position)
{
	int count = max(uColoursCount, 1);

	if (count == 1)
		return uColours[0];

	float paletteIndex = clamp(position, 0.0, 1.0) * float(count - 1);
	int lower = int(floor(paletteIndex));
	int upper = min(lower + 1, count - 1);

	return mix(uColours[lower], uColours[upper], fract(paletteIndex));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 position = (fragCoord - uCenter) / iResolution.y;
	position /= max(uScale, 0.001);

	float field = neuroShape(position * 1.3);
	field = (1.0 + uBrightness) * field * field;
	field = pow(max(field, 0.0), 0.7 + 6.0 * uContrast);
	field = clamp(field / 1.4, 0.0, 1.0);

	fragColor = palette(field);
}
