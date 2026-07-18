// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT
//
// Tide - slow descending wave bands from an asymmetric flow-field loop: the
// horizontal displacement ramps frequency with the vertical coordinate (the
// waves), the vertical term stays broad; a cosine reads it into a palette.

// #color label="Colours" min=2 max=6 default="#08122E,#123A8C,#2E63D6,#5A5AA8,#FA5A2A,#FF9040"
uniform vec4 uColours[6];

// #int label="Complexity" min=2 max=24 default=18
uniform float uComplexity;

// #percent label="Warp" default=100
uniform float uWarp;

// #point label="Center" osc default="0.5,0.5"
uniform vec2 uCenter;

// #percent label="Scale" default=100 osc=ring link=uCenter
uniform float uScale;

vec3 tidePalette(float f)
{
	int n = max(uColoursCount, 1);
	if (n == 1)
		return uColours[0].rgb;
	f = clamp(f, 0.0, 1.0) * float(n - 1);
	int i0 = int(floor(f));
	int i1 = min(i0 + 1, n - 1);
	return mix(uColours[i0].rgb, uColours[i1].rgb, fract(f));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;
	uv -= uCenter / iResolution.xy - 0.5; // #point pan
	uv = (uv - 0.5) / max(uScale, 0.01) + 0.5; // zoom
	uv *= 6.0;

	float t = iTime * 0.1; // Speed/Seed shape iTime
	int N = int(uComplexity);

	// Asymmetric flow loop: x-displacement ramps frequency with uv.y (the wave
	// detail) and drifts down with +t; y-displacement stays broad (frequency 1).
	for (int i = 1; i < 24; i++)
	{
		if (i >= N)
			break;
		float fi = float(i);
		float amp = uWarp / fi;
		uv.x += amp * sin(fi * uv.y + t * fi) + 0.8;
		uv.y += amp * sin(uv.x + t * fi) + 1.6;
	}

	float g = cos(uv.x + uv.y) * 0.5 + 0.5;
	vec3 col = tidePalette(g);
	fragColor = vec4(col, 1.0);
}