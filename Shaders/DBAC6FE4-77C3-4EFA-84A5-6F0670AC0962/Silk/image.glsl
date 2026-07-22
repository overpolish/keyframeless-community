// SPDX-FileCopyrightText: 2025 Paul Bakaus
// SPDX-License-Identifier: MIT
//
// Silk - derived from the "Silk Cascade" shader in pbakaus/radiant
// (https://github.com/pbakaus/radiant, radiant-shaders.com). Translated to GLSL
// for Mirage and adapted for its directive controls. Three domain-warped fabric
// layers with Kajiya-Kay anisotropic sheen, lit and composited back-to-front.

// #color label="Colours" min=1 max=3 default=3
uniform vec4 uColours[3];

// #color label="Background"
uniform vec4 uBackground;

// #float label="Folds" min=0.3 max=2.5 default=1
uniform float uFolds;

// #percent label="Drape" default=100
uniform float uDrape;

// #percent label="Sheen" default=100
uniform float uSheen;

// #point label="Center" osc default="0.5,0.5"
uniform vec2 uCenter;

// #percent label="Scale" default=100 osc=ring link=uCenter
uniform float uScale;

float scHash12(vec2 p)
{
	vec3 p3 = fract(vec3(p.x, p.y, p.x) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float scVnoise(vec2 p)
{
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = scHash12(i);
	float b = scHash12(i + vec2(1.0, 0.0));
	float c = scHash12(i + vec2(0.0, 1.0));
	float d = scHash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float scFbm3(vec2 p)
{
	float v = 0.0, a = 0.5;
	mat2 rot = mat2(0.8, -0.6, 0.6, 0.8);
	for (int i = 0; i < 3; i++)
	{
		v += a * scVnoise(p);
		p = rot * p * 2.0;
		a *= 0.5;
	}
	return v;
}

float scFbm2(vec2 p)
{
	float v = 0.5 * scVnoise(p);
	p = mat2(0.8, -0.6, 0.6, 0.8) * p * 2.0;
	v += 0.25 * scVnoise(p);
	return v;
}

vec2 scWarp(vec2 p, float t, float scale, float seed)
{
	return vec2(scFbm3(p * scale + vec2(1.7 + seed, 9.2) + t * 0.15),
	            scFbm3(p * scale + vec2(8.3, 2.8 + seed) - t * 0.12));
}

vec2 scWarpLite(vec2 p, float t, float scale, float seed)
{
	return vec2(scFbm2(p * scale + vec2(1.7 + seed, 9.2) + t * 0.15),
	            scFbm2(p * scale + vec2(8.3, 2.8 + seed) - t * 0.12));
}

vec3 scFabricFold(vec2 p, float t, float seed, float freq, float flow, float drape, bool lite)
{
	float ts = t * flow;
	vec2 warp = lite ? scWarpLite(p + seed * 3.7, ts, 1.2, seed)
	            : scWarp(p + seed * 3.7, ts, 1.2, seed);
	vec2 wp = p + warp * 0.55 * drape;
	float h = 0.0;
	vec2 g = vec2(0.0);

	float f1x = freq * 0.7, f1y = freq * 0.4;
	float ph1 = wp.x * f1x + wp.y * f1y + ts * 0.3 + seed * 2.1;
	h += sin(ph1) * 0.35;
	g += cos(ph1) * 0.35 * vec2(f1x, f1y);

	float f2x = -freq * 0.3, f2y = freq * 0.9;
	float ph2 = wp.x * f2x + wp.y * f2y + ts * 0.25 + seed * 1.3;
	h += sin(ph2) * 0.25;
	g += cos(ph2) * 0.25 * vec2(f2x, f2y);

	float f3 = freq * 0.6;
	float ph3 = (wp.x + wp.y) * f3 + ts * 0.2 + seed * 4.5;
	h += sin(ph3) * 0.18;
	g += cos(ph3) * 0.18 * vec2(f3, f3);

	float f4x = freq * 1.8, f4y = freq * 1.2;
	float ph4 = wp.x * f4x + wp.y * f4y - ts * 0.35 + seed * 0.7;
	h += sin(ph4) * 0.08;
	g += cos(ph4) * 0.08 * vec2(f4x, f4y);

	if (!lite)
		h += scVnoise(wp * freq * 0.9 + seed * 10.0 + ts * 0.04) * 0.12 - 0.06;
	return vec3(h, g);
}

float scKajiyaSpec(vec2 grad, vec3 L, vec3 V, float shine)
{
	float gl2 = dot(grad, grad);
	if (gl2 < 0.0001) return 0.0;
	vec2 tg = vec2(-grad.y, grad.x) / sqrt(gl2);
	vec3 T = normalize(vec3(tg, 0.0));
	vec3 H = normalize(L + V);
	float TdH = dot(T, H);
	return pow(sqrt(max(1.0 - TdH * TdH, 0.0)), shine);
}

vec4 scShadeLayer(vec2 p, float t, float seed, float freq, float flow, float drape,
                  vec3 darkCol, vec3 midCol, vec3 brightCol, vec3 specCol,
                  float opacity, float shine, vec3 L1, vec3 L2, vec3 V, float sheenMul)
{
	vec3 fold = scFabricFold(p, t, seed, freq, flow, drape, opacity < 0.35);
	float h = fold.x;
	vec2 grad = fold.yz;
	vec3 N = normalize(vec3(-grad * 1.8, 1.0));

	float NdL1 = max(dot(N, L1), 0.0);
	float NdL2 = max(dot(N, L2), 0.0);
	float lit = NdL1 * 0.75 + NdL2 * 0.12;

	float depth = smoothstep(-0.8, 0.4, h);

	float shade = lit * depth;
	float midBlend = smoothstep(0.0, 0.35, shade);
	float brightBlend = smoothstep(0.25, 0.7, shade);
	vec3 fabric = mix(darkCol, midCol, midBlend);
	fabric = mix(fabric, brightCol, brightBlend * 0.5);

	float sp = scKajiyaSpec(grad, L1, V, shine) * 0.9;
	sp += scKajiyaSpec(grad, L2, V, shine * 0.6) * 0.15;
	sp *= sheenMul;
	float specPow = sp * sp * sp;
	fabric += specCol * specPow * 0.9;

	float trans = smoothstep(0.3, 0.9, depth) * lit * 0.08;
	fabric += vec3(0.45, 0.28, 0.15) * trans;

	float alpha = opacity * (0.65 + depth * 0.35);
	return vec4(fabric, alpha);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	float aspect = iResolution.x / iResolution.y;
	float t = iTime * 0.4; // Speed/Seed shape iTime

	vec2 origin = uCenter / iResolution.xy; // #point delivers pixels
	vec2 uvn = fragCoord / iResolution.xy - (origin - 0.5);
	vec2 p = (uvn - 0.5) * vec2(aspect, 1.0);
	p /= max(uScale, 0.01);

	vec3 L1 = normalize(vec3(0.4 + sin(t * 0.07) * 0.3, 0.9 + cos(t * 0.09) * 0.15, 0.8));
	vec3 L2 = normalize(vec3(-0.7 + cos(t * 0.06) * 0.2, -0.3 + sin(t * 0.08) * 0.15, 0.6));
	vec3 V = vec3(0.0, 0.0, 1.0);

	float bgD = length(p);
	vec3 col = uBackground.rgb * uBackground.a;
	col += uBackground.rgb * uBackground.a * 0.5 * exp(-bgD * bgD * 2.0);

	float folds = uFolds;
	float drape = uDrape;
	float sheen = uSheen;

	int cc = max(uColoursCount, 1);
	vec4 h1 = uColours[0];
	vec4 h2 = uColours[min(1, cc - 1)];
	vec4 h3 = uColours[min(2, cc - 1)];
	vec3 c1 = h1.rgb * h1.a, c2 = h2.rgb * h2.a, c3 = h3.rgb * h3.a;

	vec4 ly1 = scShadeLayer(p * 0.8 + vec2(0.15, t * 0.015), t, 0.0, 2.0 * folds, 0.5, drape,
	                        c1 * 0.14, c1 * 0.55, c1 * 0.95, mix(c1, vec3(1.0), 0.72), 0.30, 26.0, L1, L2, V, sheen * 0.7);
	vec4 ly2 = scShadeLayer(p * 1.0 + vec2(t * 0.012, -0.1), t, 1.0, 3.2 * folds, 0.75, drape,
	                        c2 * 0.14, c2 * 0.55, c2 * 0.95, mix(c2, vec3(1.0), 0.72), 0.38, 40.0, L1, L2, V, sheen * 0.9);
	vec4 ly3 = scShadeLayer(p * 1.2 + vec2(-t * 0.008, t * 0.02), t, 2.0, 4.5 * folds, 1.0, drape,
	                        c3 * 0.14, c3 * 0.55, c3 * 0.95, mix(c3, vec3(1.0), 0.72), 0.50, 55.0, L1, L2, V, sheen);

	col = mix(col, ly1.rgb, ly1.a);
	col += c1 * 0.10 * ly1.a * ly2.a;
	col = mix(col, ly2.rgb, ly2.a);
	col += c2 * 0.08 * ly2.a * ly3.a;
	col = mix(col, ly3.rgb, ly3.a);

	float cov = (ly1.a + ly2.a + ly3.a) * 0.333;
	col += c3 * 0.05 * cov;

	float vig = 1.0 - smoothstep(0.25, 1.15, length(p * vec2(0.85, 1.0)));
	col *= 0.6 + 0.4 * vig;

	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(lum), col, 1.35);

	col = col * (2.51 * col + 0.03) / (col * (2.43 * col + 0.59) + 0.14); // ACES
	col = max(col, vec3(0.0));

	fragColor = vec4(col, 1.0);
}