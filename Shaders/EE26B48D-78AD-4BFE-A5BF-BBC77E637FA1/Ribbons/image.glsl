// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT
//
// Ribbons - flowing diagonal comic bands. A scrolling ramp is rippled and
// posterised into hard steps, each step coloured from a palette. Original code.

// #color label="Colours" min=2 max=4 default="#2A1B4A,#7A3FA0,#F26D9C,#FFD166"
uniform vec4 uColours[4];

// #int label="Bands" min=2 max=16 default=6
uniform float uBands;

// #percent label="Ripple" default=100
uniform float uRipple;

// #angle label="Direction" default=225
uniform float uAngle;

// #point label="Center" osc default="0.5,0.5"
uniform vec2 uCenter;

// #percent label="Scale" default=100 osc=ring link=uCenter
uniform float uScale;

vec3 ribPalette(float f)
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
	vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
	uv -= (uCenter - 0.5 * iResolution.xy) / iResolution.y; // #point pan
	uv /= max(uScale, 0.01); // zoom = band density

	float t = iTime * 0.3; // Speed/Seed shape iTime

	// Diagonal scrolling ramp.
	float ang = radians(uAngle);
	vec2 dir = vec2(cos(ang), sin(ang));
	float flow = dot(uv, dir) * 3.0 + t;

	// Ripple wobble (two crossed sine fields).
	float rx = sin(uv.x * 12.0 + t * 1.5) * cos(uv.y * 8.0 + t * 2.0) * 0.3;
	float ry = cos(uv.y * 10.0 - t * 1.2) * sin(uv.x * 7.0 + t * 0.8) * 0.4;
	float g = fract(flow + (rx + ry) * 0.5 * uRipple);

	// Posterise into hard bands; each band takes a palette colour.
	float bands = max(floor(uBands), 1.0);
	float stepped = floor(g * bands) / max(bands - 1.0, 1.0);
	vec3 col = ribPalette(stepped);

	fragColor = vec4(col, 1.0);
}