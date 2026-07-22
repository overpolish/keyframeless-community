// SPDX-FileCopyrightText: 2025 Paul Bakaus
// SPDX-License-Identifier: MIT
//
// Strata - derived from "Painted Strata" in radiant-shaders
// (github.com/pbakaus/radiant). Translated to GLSL for Mirage and adapted for its
// directive controls. Stacked geological strata with folded boundaries, a
// tectonic domain warp, per-layer palette colour and washi-paper grain. Each
// layer hashes to a palette swatch.

// #color label="Colours" min=1 max=6 default="#3B2A1F,#6B4A2F,#A9744F,#D8B08C,#8C6B4A"
uniform vec4 uColours[6];

// #int label="Layers" min=1 max=24 default=12
uniform float uLayers;

// #percent label="Tectonics" default=60
uniform float uTectonics;

// #percent label="Texture" default=70
uniform float uTexture;

// #point label="Center" osc default="0.5,0.5"
uniform vec2 uCenter;

// #percent label="Scale" default=100 osc=ring link=uCenter
uniform float uScale;

float psHash11(float p)
{
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float psHash21(vec2 p)
{
	vec3 p3 = fract(vec3(p.x, p.y, p.x) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float psVnoise(vec2 p)
{
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = psHash21(i);
	float b = psHash21(i + vec2(1.0, 0.0));
	float c = psHash21(i + vec2(0.0, 1.0));
	float d = psHash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float psFbm(vec2 p)
{
	float v = 0.0, a = 0.5;
	vec2 shift = vec2(100.0);
	mat2 rot = mat2(cos(0.5), sin(0.5), -sin(0.5), cos(0.5));
	for (int i = 0; i < 5; i++)
	{
		v += a * psVnoise(p);
		p = rot * p * 2.0 + shift;
		a *= 0.5;
	}
	return v;
}

vec2 psTectonicWarp(vec2 uv, float t, float tect)
{
	float slow = t * 0.15;
	float warpX = psFbm(uv * 1.5 + vec2(slow * 0.7, slow * 0.3)) - 0.5;
	float warpY = psFbm(uv * 1.5 + vec2(slow * 0.5 + 50.0, slow * 0.8 + 30.0)) - 0.5;
	float compress = sin(uv.x * 2.0 + slow * 0.4) * 0.08;
	float shear = sin(uv.y * 3.0 + slow * 0.6) * 0.06;
	return vec2(uv.x + (warpX * 0.25 + shear) * tect, uv.y + (warpY * 0.18 + compress) * tect);
}

float psLayerBoundary(float x, float baseY, float idx, float t, float tect)
{
	float h1 = psHash11(idx * 7.13);
	float h2 = psHash11(idx * 13.37);
	float h3 = psHash11(idx * 23.71);
	float freq1 = 1.5 + h1 * 2.5;
	float freq2 = 3.0 + h2 * 3.0;
	float amp1 = (0.04 + h1 * 0.06) * tect;
	float amp2 = (0.015 + h2 * 0.025) * tect;
	float phase1 = t * (0.1 + h3 * 0.15);
	float phase2 = t * (0.08 + h1 * 0.12);
	float fold = amp1 * sin(x * freq1 + phase1 + h2 * 6.28);
	fold += amp2 * sin(x * freq2 + phase2 + h3 * 6.28);
	fold += 0.02 * tect * psVnoise(vec2(x * 4.0 + h1 * 100.0, t * 0.2 + idx));
	return baseY + fold;
}

float psGrainTexture(vec2 uv, float layerIdx)
{
	float h = psHash11(layerIdx * 41.93);
	float fiberAngle = h * 3.14 * 0.3;
	float ca = cos(fiberAngle), sa = sin(fiberAngle);
	vec2 rotUV = vec2(uv.x * ca - uv.y * sa, uv.x * sa + uv.y * ca);
	float fiber1 = psVnoise(vec2(rotUV.x * 120.0, rotUV.y * 18.0) + layerIdx * 30.0);
	float fiber2 = psVnoise(vec2(rotUV.x * 80.0, rotUV.y * 12.0) + layerIdx * 50.0 + 100.0);
	float intensity = fiber1 * 0.08 + fiber2 * 0.05;
	float crossf = psVnoise(vec2(rotUV.x * 15.0, rotUV.y * 70.0) + layerIdx * 40.0);
	intensity += crossf * 0.03;
	intensity += psVnoise(uv * 50.0 + layerIdx * 25.0) * 0.025;
	return intensity - 0.04;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	float aspect = iResolution.x / iResolution.y;
	float t = 0.5 * iTime; // Speed/Seed shape iTime

	vec2 uvn = fragCoord / iResolution.xy; // y-up (Shadertoy)
	vec2 c = uvn - 0.5;
	c /= max(uScale, 0.01);
	vec2 uv = c + 0.5;
	vec2 origin = uCenter / iResolution.xy; // #point delivers pixels
	uv -= (origin - 0.5);

	vec2 uvAspect = vec2(uv.x * aspect, uv.y);
	float tect = uTectonics;
	float layerCount = max(floor(uLayers), 1.0);

	vec2 warped = psTectonicWarp(uvAspect, t, tect);

	float layerSpacing = 1.0 / (layerCount + 1.0);
	float currentLayer = -1.0;
	float layerPos = 0.0;
	float prevBound = -0.2;
	for (int i = 0; i < 24; i++)
	{
		if (float(i) >= layerCount) break;
		float fi = float(i);
		float baseY = (fi + 1.0) * layerSpacing;
		float bound = psLayerBoundary(warped.x, baseY, fi, t, tect);
		if (warped.y >= prevBound && warped.y < bound)
		{
			currentLayer = fi;
			float thickness = bound - prevBound;
			layerPos = (warped.y - prevBound) / max(thickness, 0.001);
			break;
		}
		prevBound = bound;
	}
	if (currentLayer < 0.0)
	{
		currentLayer = layerCount;
		layerPos = 0.5;
	}

	int cc2 = max(uColoursCount, 1);
	float hpick = psHash11(currentLayer * 17.31 + 3.7);
	int ci = int(mod(floor(hpick * float(cc2)), float(cc2)));
	vec4 sw = uColours[ci];
	vec3 col = sw.rgb * sw.a;
	float h2 = psHash11(currentLayer * 31.17);
	col += (h2 - 0.5) * 0.06;

	col += psGrainTexture(warped, currentLayer) * uTexture;

	float edgeShade = smoothstep(0.0, 0.15, layerPos) * smoothstep(1.0, 0.85, layerPos);
	col *= 0.85 + 0.15 * edgeShade;
	float edgeShadow = smoothstep(0.0, 0.08, layerPos);
	col *= 0.82 + 0.18 * edgeShadow;
	float topHighlight = smoothstep(1.0, 0.92, layerPos);
	col += vec3(0.04, 0.035, 0.025) * (1.0 - topHighlight);

	float vig = 1.0 - 0.3 * length((uv - 0.5) * 1.5);
	col *= vig;

	float paperTex = psVnoise(fragCoord * 0.15) * 0.03 * uTexture;
	paperTex += (psHash21(fragCoord + fract(t * 0.1) * 1000.0) - 0.5) * 0.015 * uTexture;
	col += paperTex;

	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(lum), col, 0.82);

	fragColor = vec4(col, 1.0);
}