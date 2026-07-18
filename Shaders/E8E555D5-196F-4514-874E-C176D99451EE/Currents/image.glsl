// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT
//
// Flux - a flowing liquid gradient. Animated value noise perturbs an
// amplitude-decaying sine domain warp (fluid turbulence), and the warped
// coordinate drives a smooth palette for drifting ink-in-water colour.

// #color label="Colours" min=2 max=4 default="#0A2A5E,#1E7FA8,#6FD0C8,#B8A0E8"
uniform vec4 uColours[4];

// #int label="Detail" min=2 max=8 default=5
uniform float uDetail;

// #percent label="Warp" default=100
uniform float uWarp;

// #percent label="Turbulence" default=100
uniform float uTurb;

// #point label="Center" osc default="0.5,0.5"
uniform vec2 uCenter;

// #percent label="Scale" default=100 osc=ring link=uCenter
uniform float uScale;

float flowHash(vec3 p)
{
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

// 3D value noise (trilinear), 0..1 - time as the third axis animates it in place.
float flowNoise(vec3 x)
{
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = flowHash(i + vec3(0.0, 0.0, 0.0));
	float n100 = flowHash(i + vec3(1.0, 0.0, 0.0));
	float n010 = flowHash(i + vec3(0.0, 1.0, 0.0));
	float n110 = flowHash(i + vec3(1.0, 1.0, 0.0));
	float n001 = flowHash(i + vec3(0.0, 0.0, 1.0));
	float n101 = flowHash(i + vec3(1.0, 0.0, 1.0));
	float n011 = flowHash(i + vec3(0.0, 1.0, 1.0));
	float n111 = flowHash(i + vec3(1.0, 1.0, 1.0));
	return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
	           mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}

vec3 fluxPalette(float f)
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
	vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y; // centred, aspect-correct
	p -= (uCenter - 0.5 * iResolution.xy) / iResolution.y; // #point pan
	p /= max(uScale, 0.01); // zoom

	float t = iTime * 0.4; // Speed/Seed shape iTime
	float w = uWarp;
	int N = int(uDetail);

	// One organic noise sample (time = 3rd axis) perturbs the warp's phase.
	float h = (flowNoise(vec3(p * 2.0, t)) * 2.0 - 1.0) * uTurb;

	// Amplitude-decaying sine domain warp: each pass pushes the coordinate by
	// finer, weaker sine offsets whose phase the noise bends -> fluid drift.
	vec2 q = p * 1.2;
	float amp = 0.7;
	for (int i = 0; i < 8; i++)
	{
		if (i >= N)
			break;
		float fi = float(i) + 1.0;
		vec2 off = vec2(sin(fi * q.y + t + h * fi), cos(fi * q.x - t + h));
		q -= w * amp * off;
		amp *= 0.6;
	}

	// Warped coordinate -> smooth palette (big flowing bands), with soft shading.
	float field = 0.5 + 0.5 * sin(0.8 * (q.x + q.y) + h);
	vec3 col = fluxPalette(field);
	float field2 = 0.5 + 0.5 * cos(q.x - q.y);
	col = mix(col, fluxPalette(field2), 0.35);
	col *= 0.75 + 0.25 * sin(q.y + h);

	fragColor = vec4(col, 1.0);
}