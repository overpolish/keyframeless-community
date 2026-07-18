// SPDX-FileCopyrightText: The paper-design/shaders authors
// SPDX-License-Identifier: Apache-2.0
//
// Grain Gradient - derived from the grain-gradient shader in paper-design/shaders
// (https://github.com/paper-design/shaders). Translated to GLSL for Shader and
// adapted for its directive controls. A procedural shape indexes a colour ramp,
// warped by fbm noise with a grainy overlay, composited over a background.

// #color label="Colours" min=1 max=6 default="#12141C,#3A5BA0,#F4A259,#F7E1A0"
uniform vec4 uColours[6];

// #color label="Background" default="#0A0A12"
uniform vec4 uColorBack;

// #choice label="Shape" options="Wave,Dots,Truchet,Corners,Ripple,Blob" default=0
uniform int uShape;

// #percent label="Intensity" default=50
uniform float uIntensity;

// #percent label="Grain" default=30
uniform float uGrain;

// #percent label="Softness" default=40
uniform float uSoftness;

// #point label="Center" osc default="0.5,0.5"
uniform vec2 uCenter;

// #percent label="Scale" default=100 osc=ring link=uCenter
uniform float uScale;

const float DTH_TWO_PI = 6.28318530718;
const float GG_PATTERN_TILES = 16.0;
const float GG_REF_H = 1080.0;

vec2 ggRotate(vec2 v, float a)
{
	float s = sin(a), c = cos(a);
	return vec2(c * v.x + s * v.y, -s * v.x + c * v.y);
}

float ggHash11(float p)
{
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float ggHash21(vec2 p)
{
	p = fract(p * vec2(0.3183099, 0.3678794)) + 0.1;
	p += dot(p, p + 19.19);
	return fract(p.x * p.y);
}

vec3 ggMod289(vec3 x)
{
	return x - floor(x * (1.0 / 289.0)) * 289.0;
}
vec3 ggPermute(vec3 x)
{
	return ggMod289(((x * 34.0) + 1.0) * x);
}

float ggSnoise(vec2 v)
{
	const vec4 C = vec4(0.211324865405187, 0.366025403784439,
	                    -0.577350269189626, 0.024390243902439);
	vec2 i = floor(v + dot(v, C.yy));
	vec2 x0 = v - i + dot(i, C.xx);
	vec2 i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
	vec4 x12 = x0.xyxy + C.xxzz;
	x12.xy -= i1;
	i = i - floor(i * (1.0 / 289.0)) * 289.0;
	vec3 p = ggPermute(ggPermute(i.y + vec3(0.0, i1.y, 1.0)) + i.x + vec3(0.0, i1.x, 1.0));
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

float ggValueNoise(vec2 st)
{
	vec2 i = floor(st);
	vec2 f = fract(st);
	float a = ggHash21(i);
	float b = ggHash21(i + vec2(1.0, 0.0));
	float c = ggHash21(i + vec2(0.0, 1.0));
	float d = ggHash21(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

vec4 ggFbm(vec2 n0, vec2 n1, vec2 n2, vec2 n3)
{
	float amplitude = 0.2;
	vec4 total = vec4(0.0);
	for (int i = 0; i < 3; i++)
	{
		n0 = ggRotate(n0, 0.3);
		n1 = ggRotate(n1, 0.3);
		n2 = ggRotate(n2, 0.3);
		n3 = ggRotate(n3, 0.3);
		total.x += ggValueNoise(n0) * amplitude;
		total.y += ggValueNoise(n1) * amplitude;
		total.z += ggValueNoise(n2) * amplitude;
		total.z += ggValueNoise(n3) * amplitude;
		n0 *= 1.99;
		n1 *= 1.99;
		n2 *= 1.99;
		n3 *= 1.99;
		amplitude *= 0.6;
	}
	return total;
}

vec2 ggTruchet(vec2 uv, float idx)
{
	idx = fract((idx - 0.5) * 2.0);
	if (idx > 0.75) uv = vec2(1.0) - uv;
	else if (idx > 0.5) uv = vec2(1.0 - uv.x, uv.y);
	else if (idx > 0.25) uv = 1.0 - vec2(1.0 - uv.x, uv.y);
	return uv;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	float aspect = iResolution.x / iResolution.y;
	float t = 0.1 * (iTime + 7.0); // Speed/Seed shape iTime

	vec2 uv = fragCoord / iResolution.xy; // y-up (Shadertoy)
	vec2 origin = uCenter / iResolution.xy; // #point delivers pixels
	uv -= (origin - 0.5);

	vec2 vObjectUV = uv - 0.5;
	vObjectUV.x *= aspect;
	vObjectUV /= max(uScale, 0.01);
	vec2 vPatternUV = vObjectUV * GG_PATTERN_TILES;

	vec2 shapeUV, grainUV;
	if (uShape > 2)
	{
		shapeUV = vObjectUV;
		grainUV = vObjectUV * vec2(aspect * GG_REF_H, GG_REF_H) * 0.7;
	}
	else
	{
		shapeUV = 0.5 * vPatternUV;
		grainUV = 160.0 * vPatternUV;
	}

	float cCount = max(float(uColoursCount), 1.0);
	float shape = 0.0;

	if (uShape == 0) // Wave
	{
		float wave = cos(0.5 * shapeUV.x - 4.0 * t) * sin(1.5 * shapeUV.x + 2.0 * t) * (0.75 + 0.25 * cos(6.0 * t));
		shape = 1.0 - smoothstep(-1.0, 1.0, shapeUV.y + wave);
	}
	else if (uShape == 1) // Dots
	{
		float stripeIdx = floor(2.0 * shapeUV.x / DTH_TWO_PI);
		float rnd = ggHash11(stripeIdx * 100.0);
		rnd = sign(rnd - 0.5) * pow(4.0 * abs(rnd), 0.3);
		shape = sin(shapeUV.x) * cos(shapeUV.y - 5.0 * rnd * t);
		shape = pow(abs(shape), 4.0);
	}
	else if (uShape == 2) // Truchet
	{
		float n2 = ggValueNoise(shapeUV * 0.4 - 3.75 * t);
		shapeUV.x += 10.0;
		shapeUV *= 0.6;
		vec2 tile = ggTruchet(fract(shapeUV), ggHash21(floor(shapeUV)));
		float d1 = length(tile);
		float d2 = length(tile - vec2(1.0));
		n2 -= 0.5;
		n2 *= 0.1;
		shape = smoothstep(0.2, 0.55, d1 + n2) * (1.0 - smoothstep(0.45, 0.8, d1 - n2));
		shape += smoothstep(0.2, 0.55, d2 + n2) * (1.0 - smoothstep(0.45, 0.8, d2 - n2));
		shape = pow(shape, 1.5);
	}
	else if (uShape == 3) // Corners
	{
		shapeUV *= 0.6;
		vec2 outer = vec2(0.5);
		vec2 bl = smoothstep(vec2(0.0), outer, shapeUV + vec2(0.1 + 0.1 * sin(3.0 * t), 0.2 - 0.1 * sin(5.25 * t)));
		vec2 tr = smoothstep(vec2(0.0), outer, 1.0 - shapeUV);
		shape = 1.0 - bl.x * bl.y * tr.x * tr.y;
		shapeUV = -shapeUV;
		bl = smoothstep(vec2(0.0), outer, shapeUV + vec2(0.1 + 0.1 * sin(3.0 * t), 0.2 - 0.1 * cos(5.25 * t)));
		tr = smoothstep(vec2(0.0), outer, 1.0 - shapeUV);
		shape -= bl.x * bl.y * tr.x * tr.y;
		shape = 1.0 - smoothstep(0.0, 1.0, shape);
	}
	else if (uShape == 4) // Ripple
	{
		shapeUV *= 2.0;
		float dist = length(0.4 * shapeUV);
		shape = sin(pow(dist, 1.2) * 5.0 - 3.0 * t) * 0.5 + 0.5;
	}
	else // Blob
	{
		float tt = t * 2.0;
		vec2 f1 = 0.25 * vec2(1.3 * sin(tt), 0.2 + 1.3 * cos(0.6 * tt + 4.0));
		vec2 f2 = 0.2 * vec2(1.2 * sin(-tt), 1.3 * sin(1.6 * tt));
		vec2 f3 = 0.25 * vec2(1.7 * cos(-0.6 * tt), cos(-1.6 * tt));
		vec2 f4 = 0.3 * vec2(1.4 * cos(0.8 * tt), 1.2 * sin(-0.6 * tt - 3.0));
		shape = 0.5 * pow(1.0 - clamp(length(shapeUV + f1), 0.0, 1.0), 5.0);
		shape += 0.5 * pow(1.0 - clamp(length(shapeUV + f2), 0.0, 1.0), 5.0);
		shape += 0.5 * pow(1.0 - clamp(length(shapeUV + f3), 0.0, 1.0), 5.0);
		shape += 0.5 * pow(1.0 - clamp(length(shapeUV + f4), 0.0, 1.0), 5.0);
		shape = smoothstep(0.0, 0.9, shape);
		float edge = smoothstep(0.25, 0.3, shape);
		shape = mix(0.0, shape, edge);
	}

	float baseNoise = ggSnoise(grainUV * 0.5);
	vec4 fbmVals = ggFbm(0.002 * grainUV + 10.0, 0.003 * grainUV, 0.001 * grainUV, ggRotate(0.4 * grainUV, 2.0));
	float grainDist = baseNoise * ggSnoise(grainUV * 0.2) - fbmVals.x - fbmVals.y;
	float rawNoise = 0.75 * baseNoise - fbmVals.w - fbmVals.z;
	float noise = clamp(rawNoise, 0.0, 1.0);

	shape += uIntensity * 2.0 / cCount * (grainDist + 0.5);
	shape += uGrain * 10.0 / cCount * noise;

	float aa = fwidth(shape);
	shape = clamp(shape - 0.5 / cCount, 0.0, 1.0);
	float totalShape = smoothstep(0.0, uSoftness + 2.0 * aa, clamp(shape * cCount, 0.0, 1.0));
	float mixer = shape * (cCount - 1.0);

	int cntStop = int(cCount) - 1;
	vec4 gradient = uColours[0];
	gradient.rgb *= gradient.a;
	for (int i = 1; i < 6; i++)
	{
		if (i > cntStop) break;
		float localT = clamp(mixer - float(i - 1), 0.0, 1.0);
		localT = smoothstep(0.5 - 0.5 * uSoftness - aa, 0.5 + 0.5 * uSoftness + aa, localT);
		vec4 c = uColours[i];
		c.rgb *= c.a;
		gradient = mix(gradient, c, localT);
	}

	vec3 color = gradient.rgb * totalShape;
	float opacity = gradient.a * totalShape;
	vec3 bgColor = uColorBack.rgb * uColorBack.a;
	color = color + bgColor * (1.0 - opacity);
	opacity = opacity + uColorBack.a * (1.0 - opacity);

	vec3 rgb = opacity > 1e-4 ? color / opacity : color; // un-premultiply
	fragColor = vec4(rgb, opacity);
}