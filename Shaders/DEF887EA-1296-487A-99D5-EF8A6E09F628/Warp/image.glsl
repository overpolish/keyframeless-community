// SPDX-FileCopyrightText: The paper-design/shaders authors
// SPDX-License-Identifier: Apache-2.0
//
// Warp - derived from the warp shader in paper-design/shaders
// (https://github.com/paper-design/shaders). Translated to GLSL for Mirage and
// adapted for its directive controls. Colour fields warped by noise + iterative
// swirl over a checks / stripes / edge base pattern.

// #color label="Colours" min=1 max=6 default="#1A1035,#5B2A8C,#E86BFF,#FFD27A"
uniform vec4 uColours[6];

// #choice label="Shape" options="Checks,Stripes,Edge" default=0
uniform int uShape;

// #percent label="Shape Scale" default=30
uniform float uShapeScale;

// #percent label="Distortion" default=25
uniform float uDistortion;

// #percent label="Swirl" default=30
uniform float uSwirl;

// #int label="Swirl Iterations" min=1 max=20 default=8
uniform float uSwirlIterations;

// #percent label="Proportion" default=50
uniform float uProportion;

// #percent label="Softness" default=100
uniform float uSoftness;

// #point label="Center" osc default="0.5,0.5"
uniform vec2 uCenter;

// #percent label="Scale" default=100 osc=ring link=uCenter
uniform float uScale;

float warpHash(vec2 p)
{
	p = fract(p * vec2(0.3183099, 0.3678794)) + 0.1;
	p += dot(p, p + 19.19);
	return fract(p.x * p.y);
}

float warpNoise(vec2 st)
{
	vec2 i = floor(st);
	vec2 f = fract(st);
	float a = warpHash(i);
	float b = warpHash(i + vec2(1.0, 0.0));
	float c = warpHash(i + vec2(0.0, 1.0));
	float d = warpHash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	float aspect = iResolution.x / iResolution.y;
	float t = 0.0625 * (iTime + 118.0); // Speed/Seed shape iTime

	vec2 origin = uCenter / iResolution.xy; // #point delivers pixels
	vec2 uv = fragCoord / iResolution.xy - (origin - 0.5) - 0.5;
	uv.x *= aspect;
	uv /= max(uScale, 0.01);
	uv *= 4.0; // pattern tiles
	uv *= 0.5;

	float n1 = warpNoise(uv * 1.0 + t);
	float n2 = warpNoise(uv * 2.0 - t);
	float angle = n1 * 6.28318530718;
	uv.x += 4.0 * uDistortion * n2 * cos(angle);
	uv.y += 4.0 * uDistortion * n2 * sin(angle);

	for (int i = 1; i <= 20; i++)
	{
		if (i >= int(uSwirlIterations))
			break;
		float fi = float(i);
		uv.x += uSwirl / fi * cos(t + fi * 1.5 * uv.y);
		uv.y += uSwirl / fi * cos(t + fi * 1.0 * uv.x);
	}

	float proportion = clamp(uProportion, 0.0, 1.0);
	float cCount = max(float(uColoursCount), 1.0);

	float shape = 0.0;
	if (uShape == 0) // Checks
	{
		vec2 s = uv * (0.5 + 3.5 * uShapeScale);
		shape = 0.5 + 0.5 * sin(s.x) * cos(s.y);
		shape += 0.48 * sign(proportion - 0.5) * pow(abs(proportion - 0.5), 0.5);
	}
	else if (uShape == 1) // Stripes
	{
		vec2 s = uv * (2.0 * uShapeScale);
		float f = fract(s.y);
		shape = smoothstep(0.0, 0.55, f) * (1.0 - smoothstep(0.45, 1.0, f));
		shape += 0.48 * sign(proportion - 0.5) * pow(abs(proportion - 0.5), 0.5);
	}
	else // Edge
	{
		float ss = 5.0 * (1.0 - uShapeScale);
		float e0 = 0.45 - ss;
		float e1 = 0.55 + ss;
		shape = smoothstep(min(e0, e1), max(e0, e1), 1.0 - uv.y + 0.3 * (proportion - 0.5));
	}

	float mixer = shape * (cCount - 1.0);
	vec4 gradient = uColours[0];
	gradient.rgb *= gradient.a;
	float aa = fwidth(shape);
	for (int i = 1; i < 6; i++)
	{
		if (i >= int(cCount))
			break;
		float m = clamp(mixer - float(i - 1), 0.0, 1.0);
		float localStart = floor(m);
		float softness = 0.5 * uSoftness + fwidth(m);
		float smoothed = smoothstep(max(0.0, 0.5 - softness - aa),
		                            min(1.0, 0.5 + softness + aa), m - localStart);
		float stepped = localStart + smoothed;
		m = mix(stepped, m, uSoftness);
		vec4 c = uColours[i];
		c.rgb *= c.a;
		gradient = mix(gradient, c, m);
	}

	float a = gradient.a;
	vec3 rgb = a > 1e-4 ? gradient.rgb / a : gradient.rgb; // un-premultiply
	fragColor = vec4(rgb, a);
}