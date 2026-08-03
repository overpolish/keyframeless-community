// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template generator

// #speed group={"Motion", "wind"}
// #seed group="Motion"

// #grain label="Grain" group={"Finish", "camera.filters"} default=0 size=2

// #color label="Colours" min=2 max=6 default="#08122E,#123A8C,#2E63D6,#5A5AA8,#FA5A2A,#FF9040"
uniform vec4 uColours[6];

// #int label="Complexity" group={"Pattern", "water.waves"} min=2 max=24 default=18
uniform float uComplexity;

// #percent label="Warp" group="Pattern" min=0 max=200 default=100
uniform float uWarp;

// #point label="Center" group={"Transform", "viewfinder"} osc=position default="0.5,0.5"
uniform vec2 uCenter;

// #percent label="Scale" group="Transform" min=25 max=400 default=100 osc=ring link=uCenter
uniform float uScale;

vec3 palette(float position)
{
	int count = max(uColoursCount, 1);

	if (count == 1)
		return uColours[0].rgb;

	float paletteIndex = clamp(position, 0.0, 1.0) * float(count - 1);
	int lower = int(floor(paletteIndex));
	int upper = min(lower + 1, count - 1);

	return mix(uColours[lower].rgb, uColours[upper].rgb, fract(paletteIndex));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 position =
	    (fragCoord - uCenter) /
	    iResolution.xy /
	    max(uScale, 0.001) +
	    0.5;

	position *= 6.0;

	float time = iTime * 0.1;
	int complexity = int(uComplexity);

	for (int i = 1; i <= 24; ++i)
	{
		if (i > complexity)
			break;

		float frequency = float(i);
		float amplitude = uWarp / frequency;

		position.x +=
		    amplitude *
		    sin(
		        frequency * position.y +
		        time * frequency
		    ) +
		    0.8;

		position.y +=
		    amplitude *
		    sin(
		        position.x +
		        time * frequency
		    ) +
		    1.6;
	}

	float field =
	    cos(position.x + position.y) *
	    0.5 +
	    0.5;

	fragColor = vec4(palette(field), 1.0);
}