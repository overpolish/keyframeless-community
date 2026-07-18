// SPDX-FileCopyrightText: 2025 Paul Bakaus
// SPDX-License-Identifier: MIT
//
// Fluid - derived from "Fluid Amber" in radiant-shaders
// (github.com/pbakaus/radiant). Translated to GLSL for Shader and adapted for its
// directive controls. An iterative IQ domain warp (fbm feeding fbm feeding fbm)
// whose field magnitudes composite the palette swatches in layers for a molten,
// marbled flow. Time enters as the 3rd noise dimension, so the field boils in
// place instead of sliding.

// #color label="Colours" min=1 max=4 default="#0A0E2A,#1E4F9C,#3FC7E8,#E8FBFF"
uniform vec4 uColours[4];

// #percent label="Detail" default=50
uniform float uDetail;

// #percent label="Marble" default=100
uniform float uMarble;

// #percent label="Vibrance" default=100
uniform float uVibrance;

// #point label="Center" osc default="0.5,0.5"
uniform vec2 uCenter;

// #percent label="Scale" default=100 osc=ring link=uCenter
uniform float uScale;

vec2 flRotate(vec2 v, float a)
{
	float s = sin(a), c = cos(a);
	return vec2(c * v.x + s * v.y, -s * v.x + c * v.y);
}

float flHash13(vec3 p3)
{
	p3 = fract(p3 * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}

float flVnoise3(vec3 x)
{
	vec3 i = floor(x);
	vec3 f = fract(x);
	vec3 u = f * f * (3.0 - 2.0 * f);
	float n000 = flHash13(i + vec3(0.0, 0.0, 0.0));
	float n100 = flHash13(i + vec3(1.0, 0.0, 0.0));
	float n010 = flHash13(i + vec3(0.0, 1.0, 0.0));
	float n110 = flHash13(i + vec3(1.0, 1.0, 0.0));
	float n001 = flHash13(i + vec3(0.0, 0.0, 1.0));
	float n101 = flHash13(i + vec3(1.0, 0.0, 1.0));
	float n011 = flHash13(i + vec3(0.0, 1.0, 1.0));
	float n111 = flHash13(i + vec3(1.0, 1.0, 1.0));
	float nx00 = mix(n000, n100, u.x);
	float nx10 = mix(n010, n110, u.x);
	float nx01 = mix(n001, n101, u.x);
	float nx11 = mix(n011, n111, u.x);
	float nxy0 = mix(nx00, nx10, u.y);
	float nxy1 = mix(nx01, nx11, u.y);
	return mix(nxy0, nxy1, u.z) * 2.0 - 1.0;
}

float faFbm(vec3 p, float ampDecay)
{
	float val = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++)
	{
		val += amp * flVnoise3(p);
		vec2 rp = flRotate(p.xy, 0.7) * 2.03 + vec2(1.7, 9.2);
		p = vec3(rp, p.z + 2.3);
		amp *= ampDecay;
	}
	return val;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	float aspect = iResolution.x / iResolution.y;
	float t = 0.3 * iTime; // Speed/Seed shape iTime

	vec2 uv = fragCoord / iResolution.xy; // y-up (Shadertoy)
	vec2 origin = uCenter / iResolution.xy; // #point delivers pixels
	uv -= (origin - 0.5);
	vec2 p = uv - 0.5;
	p.x *= aspect;
	p /= max(uScale, 0.01);

	float decay = clamp(uDetail, 0.0, 1.0);
	float marble = uMarble;

	vec2 q = vec2(faFbm(vec3(p, t), decay), faFbm(vec3(p + vec2(5.2, 1.3), t), decay));
	vec2 r = vec2(faFbm(vec3(p + 4.0 * marble * q + vec2(1.7, 9.2), t * 1.1), decay),
	              faFbm(vec3(p + 4.0 * marble * q + vec2(8.3, 2.8), t * 1.1), decay));
	float f = faFbm(vec3(p + 3.5 * marble * r, t * 0.9), decay);

	int cc = max(uColoursCount, 1);
	vec4 s0 = uColours[0];
	vec4 s1 = uColours[min(1, cc - 1)];
	vec4 s2 = uColours[min(2, cc - 1)];
	vec4 s3 = uColours[min(3, cc - 1)];
	vec3 c0 = s0.rgb * s0.a;
	vec3 c1 = s1.rgb * s1.a;
	vec3 c2 = s2.rgb * s2.a;
	vec3 c3 = s3.rgb * s3.a;

	float vib = uVibrance;
	vec3 col = mix(c0, c1, clamp(f * f * 2.0 * vib, 0.0, 1.0));
	col = mix(col, c2, clamp(length(q) * 0.5 * vib, 0.0, 1.0));
	col = mix(col, c3, clamp(abs(r.x) * 0.6 * vib, 0.0, 1.0));

	float highlight = smoothstep(0.5, 1.2, f * f * 3.0 + length(r) * 0.5);
	col += c3 * 0.35 * highlight;

	col = pow(max(col, 0.0), vec3(1.1));

	fragColor = vec4(col, 1.0);
}