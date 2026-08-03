// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template generator

// #speed group={"Motion", "wind"}
// #seed group="Motion"
// #grain label="Grain" group={"Finish", "camera.filters"} default=0 size=2

// The four swatches are the CORNERS of a bilinear mix, not stops on a ramp.
// A #gradient would collapse them onto one axis.
// #color label="Colours" min=2 max=4 default="#FF5FA2,#FFD166,#4CC9F0,#43E197"
uniform vec4 uColours[4];

// #int label="Complexity" group={"Pattern", "circle.hexagongrid"} min=2 max=24 default=16
uniform float uComplexity;

// #percent label="Warp" group="Pattern" min=0 max=200 default=100
uniform float uWarp;

// #percent label="Frequency" group="Pattern" min=5 max=200 default=50
uniform float uFrequency;

// #point label="Center" group={"Transform", "viewfinder"} osc=position default="0.5,0.5"
uniform vec2 uCenter;

// #percent label="Scale" group="Transform" min=25 max=400 default=100 osc=ring link=uCenter
uniform float uScale;

vec2 mirrorRepeat(vec2 value)
{
	return abs(2.0 * fract(value * 0.5) - 1.0);
}

vec3 cornerPalette(vec2 position)
{
	int colorCount = max(uColoursCount, 1);

	vec3 topLeft = uColours[0].rgb;
	vec3 topRight = uColours[min(1, colorCount - 1)].rgb;
	vec3 bottomLeft = uColours[min(2, colorCount - 1)].rgb;
	vec3 bottomRight = uColours[min(3, colorCount - 1)].rgb;

	vec3 top = mix(topLeft, topRight, position.x);
	vec3 bottom = mix(bottomLeft, bottomRight, position.x);

	return mix(top, bottom, position.y);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 position = (fragCoord - uCenter) / iResolution.xy;
	position /= max(uScale, 0.01);
	position += 0.5;

	float time = iTime;
	int complexity = uComplexity;

	for (int i = 1; i <= 24; ++i)
	{
		if (i > complexity)
			break;

		float frequency = float(i) * 10.0 * uFrequency + 1.0;
		float amplitude = uWarp / frequency;
		float phase = time * 0.4 + frequency * 0.3;

		position.x += amplitude * sin(frequency * position.y + phase);
		position.y += amplitude * sin(frequency * position.x + phase + 30.0);
	}

	vec3 color = cornerPalette(mirrorRepeat(position));

	fragColor = vec4(color, 1.0);
}