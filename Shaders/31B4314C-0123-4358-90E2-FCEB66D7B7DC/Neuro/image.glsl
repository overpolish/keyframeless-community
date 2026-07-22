// SPDX-FileCopyrightText: The paper-design/shaders authors
// SPDX-License-Identifier: Apache-2.0
//
// Neuro Noise - derived from the neuro-noise shader in paper-design/shaders
// (https://github.com/paper-design/shaders; original algorithm by zozuar).
// Translated to GLSL for Mirage and adapted for its directive controls.
// A glowing web of accumulated rotated sine layers, coloured by intensity.

// #color label="Colours" min=2 max=5 default="#06080F,#1B4A6B,#57E0FF"
uniform vec4 uColours[5];

// #percent label="Brightness" default=20
uniform float uBrightness;

// #percent label="Contrast" default=15
uniform float uContrast;

// #point label="Center" osc default="0.5,0.5"
uniform vec2 uCenter;

// #percent label="Scale" default=100 osc=ring link=uCenter
uniform float uScale;

vec2 nRotate(vec2 v, float a)
{
	float s = sin(a), c = cos(a);
	return vec2(c * v.x + s * v.y, -s * v.x + c * v.y);
}

float neuroShape(vec2 uv, float t)
{
	vec2 sineAcc = vec2(0.0);
	vec2 res = vec2(0.0);
	float scale = 8.0;
	for (int j = 0; j < 15; j++)
	{
		uv = nRotate(uv, 1.0);
		sineAcc = nRotate(sineAcc, 1.0);
		vec2 layer = uv * scale + float(j) + sineAcc - t;
		sineAcc += sin(layer);
		res += (0.5 + 0.5 * cos(layer)) / scale;
		scale *= 1.2;
	}
	return res.x + res.y;
}

vec4 neuroPalette(float pos, int count)
{
	int n = max(count, 1);
	float fp = clamp(pos, 0.0, 1.0) * float(n - 1);
	int lo = clamp(int(floor(fp)), 0, n - 1);
	int hi = min(lo + 1, n - 1);
	return mix(uColours[lo], uColours[hi], fp - float(lo));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	float aspect = iResolution.x / iResolution.y;
	float t = 0.5 * iTime; // Speed/Seed shape iTime

	vec2 origin = uCenter / iResolution.xy; // #point delivers pixels
	vec2 c = fragCoord / iResolution.xy - (origin - 0.5) - 0.5;
	c.x *= aspect;
	c /= max(uScale, 0.01);
	vec2 vPatternUV = c * 10.0; // pattern tiles

	vec2 shapeUV = vPatternUV * 0.13;
	float noise = neuroShape(shapeUV, t);
	noise = (1.0 + uBrightness) * noise * noise;
	noise = pow(noise, 0.7 + 6.0 * uContrast);
	noise = min(1.4, noise);

	float q = clamp(noise / 1.4, 0.0, 1.0);
	fragColor = neuroPalette(q, uColoursCount);
}