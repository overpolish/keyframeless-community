// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT
//
// Fold - a liquid marbled gradient. An iterative sine domain warp distorts the
// coordinate, which samples a 4-corner palette gradient with mirror-repeat wrap
// so the colour bands fold into flowing symmetric ripples. Original code.

// #color label="Colours" min=2 max=4 default="#FF5FA2,#FFD166,#4CC9F0,#43E197"
uniform vec4 uColours[4];

// #int label="Complexity" min=2 max=24 default=16
uniform float uComplexity;

// #percent label="Warp" default=100
uniform float uWarp;

// #percent label="Frequency" default=50
uniform float uFrequency;

// #point label="Center" osc default="0.5,0.5"
uniform vec2 uCenter;

// #percent label="Scale" default=100 osc=ring link=uCenter
uniform float uScale;

vec2 foldMirror(vec2 v)
{
	return abs(2.0 * fract(v * 0.5) - 1.0);
}

// Bilinear 4-corner gradient from the palette (TL, TR, BL, BR).
vec3 foldCorners(vec2 g)
{
	vec3 tl = uColours[0].rgb;
	vec3 tr = uColours[min(1, uColoursCount - 1)].rgb;
	vec3 bl = uColours[min(2, uColoursCount - 1)].rgb;
	vec3 br = uColours[min(3, uColoursCount - 1)].rgb;
	vec3 top = mix(tl, tr, g.x);
	vec3 bot = mix(bl, br, g.x);
	return mix(top, bot, g.y);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 p = fragCoord / iResolution.xy; // 0..1
	p -= uCenter / iResolution.xy - 0.5; // #point pan
	p = (p - 0.5) / max(uScale, 0.01) + 0.5; // zoom about centre

	float t = iTime; // Speed/Seed shape iTime
	int N = int(uComplexity);

	// Iterative sine domain warp: frequency ramps, amplitude decays as 1/f.
	for (int i = 1; i < 24; i++)
	{
		if (i >= N)
			break;
		float f = float(i) * 10.0 * uFrequency + 1.0;
		float amp = uWarp / f;
		p.x += amp * sin(f * p.y + t * 0.4 + 0.3 * f);
		p.y += amp * sin(f * p.x + t * 0.4 + 0.3 * f + 30.0);
	}

	vec3 col = foldCorners(foldMirror(p));
	fragColor = vec4(col, 1.0);
}