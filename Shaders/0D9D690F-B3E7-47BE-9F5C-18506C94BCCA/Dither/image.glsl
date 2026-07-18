// SPDX-FileCopyrightText: The paper-design/shaders authors
// SPDX-License-Identifier: Apache-2.0
//
// Dithering - derived from the dithering shader in paper-design/shaders
// (https://github.com/paper-design/shaders). Translated to GLSL for Shader and
// adapted for its directive controls. A procedural field rendered through a
// random or ordered-Bayer dither into a colour palette. Computed in a fixed
// 1080-tall reference frame so the dither cell size is resolution-independent.

// #color label="Colours" min=2 max=6 default="#0A0A12,#F2E9E4"
uniform vec4 uColours[6];

// #choice label="Shape" options="Simplex,Warp,Dots,Wave,Ripple,Swirl" default=0
uniform int uShape;

// #choice label="Dither" options="Random,Bayer 2,Bayer 4,Bayer 8" default=3
uniform int uDither;

// #float label="Pixel Size" min=1 max=32 default=2
uniform float uPixelSize;

// #point label="Center" osc default="0.5,0.5"
uniform vec2 uCenter;

// #percent label="Scale" default=100 osc=ring link=uCenter
uniform float uScale;

const float DTH_TWO_PI = 6.28318530718;

const int bayer2x2[4] = int[](0, 2, 3, 1);
const int bayer4x4[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
const int bayer8x8[64] = int[](
                             0, 32, 8, 40, 2, 34, 10, 42, 48, 16, 56, 24, 50, 18, 58, 26,
                             12, 44, 4, 36, 14, 46, 6, 38, 60, 28, 52, 20, 62, 30, 54, 22,
                             3, 35, 11, 43, 1, 33, 9, 41, 51, 19, 59, 27, 49, 17, 57, 25,
                             15, 47, 7, 39, 13, 45, 5, 37, 63, 31, 55, 23, 61, 29, 53, 21);

float dthHash11(float p)
{
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float dthHash21(vec2 p)
{
	p = fract(p * vec2(0.3183099, 0.3678794)) + 0.1;
	p += dot(p, p + 19.19);
	return fract(p.x * p.y);
}

vec3 dthMod289(vec3 x)
{
	return x - floor(x * (1.0 / 289.0)) * 289.0;
}
vec3 dthPermute(vec3 x)
{
	return dthMod289(((x * 34.0) + 1.0) * x);
}

float dthSnoise(vec2 v)
{
	const vec4 C = vec4(0.211324865405187, 0.366025403784439,
	                    -0.577350269189626, 0.024390243902439);
	vec2 i = floor(v + dot(v, C.yy));
	vec2 x0 = v - i + dot(i, C.xx);
	vec2 i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
	vec4 x12 = x0.xyxy + C.xxzz;
	x12.xy -= i1;
	i = i - floor(i * (1.0 / 289.0)) * 289.0;
	vec3 p = dthPermute(dthPermute(i.y + vec3(0.0, i1.y, 1.0)) + i.x + vec3(0.0, i1.x, 1.0));
	vec3 m = max(0.5 - vec3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), 0.0);
	m = m * m;
	m = m * m;
	vec3 x = 2.0 * fract(p * C.www) - 1.0;
	vec3 h = abs(x) - 0.5;
	vec3 ox = floor(x + 0.5);
	vec3 a0 = x - ox;
	m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);
	vec3 g;
	g.x = a0.x * x0.x + h.x * x0.y;
	g.yz = a0.yz * x12.xz + h.yz * x12.yw;
	return 130.0 * dot(m, g);
}

float dthGetSimplexNoise(vec2 uv, float t)
{
	float noise = 0.5 * dthSnoise(uv - vec2(0.0, 0.3 * t));
	noise += 0.5 * dthSnoise(2.0 * uv + vec2(0.0, 0.32 * t));
	return noise;
}

float dthGetBayerValue(vec2 uv, int size)
{
	ivec2 pos = ivec2(fract(uv / float(size)) * float(size));
	int index = pos.y * size + pos.x;
	if (size == 2) return float(bayer2x2[index]) / 4.0;
	else if (size == 4) return float(bayer4x4[index]) / 16.0;
	else if (size == 8) return float(bayer8x8[index]) / 64.0;
	return 0.0;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	float aspect = iResolution.x / iResolution.y;
	float t = 0.5 * iTime; // Speed/Seed shape iTime

	vec2 refRes = vec2(aspect * 1080.0, 1080.0);
	vec2 refCoord = (fragCoord / iResolution.xy) * refRes;
	float pxSize = max(uPixelSize, 1.0);

	vec2 pxSizeUV = (refCoord - 0.5 * refRes) / pxSize;
	vec2 canvasPixelizedUV = (floor(pxSizeUV) + 0.5) * pxSize;
	vec2 normalizedUV = canvasPixelizedUV / refRes;

	vec2 origin = uCenter / iResolution.xy; // #point delivers pixels
	normalizedUV -= (origin - 0.5);
	normalizedUV /= max(uScale, 0.01);

	vec2 shapeUV;
	if (uShape > 2)
	{
		float minRef = min(refRes.x, refRes.y);
		shapeUV = normalizedUV * (refRes / minRef);
	}
	else
	{
		shapeUV = normalizedUV * refRes + 0.5;
	}

	float shape = 0.0;
	if (uShape == 0) // Simplex
	{
		shapeUV *= 0.001;
		shape = 0.5 + 0.5 * dthGetSimplexNoise(shapeUV, t);
		shape = smoothstep(0.3, 0.9, shape);
	}
	else if (uShape == 1) // Warp
	{
		shapeUV *= 0.003;
		for (float i = 1.0; i < 6.0; i++)
		{
			shapeUV.x += 0.6 / i * cos(i * 2.5 * shapeUV.y + t);
			shapeUV.y += 0.6 / i * cos(i * 1.5 * shapeUV.x + t);
		}
		shape = 0.15 / max(0.001, abs(sin(t - shapeUV.y - shapeUV.x)));
		shape = smoothstep(0.02, 1.0, shape);
	}
	else if (uShape == 2) // Dots
	{
		shapeUV *= 0.05;
		float stripeIdx = floor(2.0 * shapeUV.x / DTH_TWO_PI);
		float rnd = dthHash11(stripeIdx * 10.0);
		rnd = sign(rnd - 0.5) * pow(0.1 + abs(rnd), 0.4);
		shape = sin(shapeUV.x) * cos(shapeUV.y - 5.0 * rnd * t);
		shape = pow(abs(shape), 6.0);
	}
	else if (uShape == 3) // Wave
	{
		shapeUV *= 4.0;
		float wave = cos(0.5 * shapeUV.x - 2.0 * t) * sin(1.5 * shapeUV.x + t) * (0.75 + 0.25 * cos(3.0 * t));
		shape = 1.0 - smoothstep(-1.0, 1.0, shapeUV.y + wave);
	}
	else if (uShape == 4) // Ripple
	{
		float dist = length(shapeUV);
		shape = sin(pow(dist, 1.7) * 7.0 - 3.0 * t) * 0.5 + 0.5;
	}
	else // Swirl
	{
		float l = length(shapeUV);
		float angle = 6.0 * atan(shapeUV.y, shapeUV.x) + 4.0 * t;
		float twist = 1.2;
		float offset = 1.0 / pow(max(l, 1e-6), twist) + angle / DTH_TWO_PI;
		float mid = smoothstep(0.0, 1.0, pow(l, twist));
		shape = mix(0.0, fract(offset), mid);
	}
	shape = clamp(shape, 0.0, 1.0);

	float d;
	if (uDither == 0) d = dthHash21(canvasPixelizedUV);
	else if (uDither == 1) d = dthGetBayerValue(pxSizeUV, 2);
	else if (uDither == 2) d = dthGetBayerValue(pxSizeUV, 4);
	else d = dthGetBayerValue(pxSizeUV, 8);

	int n = max(uColoursCount, 1);
	float fp = shape * float(n - 1);
	int lo = clamp(int(floor(fp)), 0, n - 1);
	int hi = min(lo + 1, n - 1);
	float frac = fp - float(lo);
	vec4 c = (frac > d) ? uColours[hi] : uColours[lo];

	fragColor = vec4(c.rgb, c.a);
}