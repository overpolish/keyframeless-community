// SPDX-FileCopyrightText: The paper-design/shaders authors
// SPDX-License-Identifier: Apache-2.0
//
// God Rays - derived from the god-rays shader in paper-design/shaders
// (https://github.com/paper-design/shaders). Translated to GLSL for Shader and
// adapted for its directive controls. Rays of light radiate from the centre,
// blended through up to 5 ray colours over a background, with a central glow
// and a bloom overlay.

// #color label="Ray Colours" min=1 max=5 default="#FFE9A8,#FFC46B,#FF9E5E"
uniform vec4 uColours[5];

// #color label="Background" default="#0A0A14"
uniform vec4 uColorBack;

// #color label="Bloom Colour" default="#FFF3C0"
uniform vec4 uColorBloom;

// #percent label="Spotty" default=30
uniform float uSpotty;

// #percent label="Intensity" default=60
uniform float uIntensity;

// #percent label="Density" default=50
uniform float uDensity;

// #percent label="Bloom" default=40
uniform float uBloom;

// #percent label="Mid Size" default=40
uniform float uMidSize;

// #percent label="Mid Intensity" default=60
uniform float uMidIntensity;

// #point label="Center" osc default="0.5,1.0"
uniform vec2 uCenter;

// #percent label="Scale" default=100 osc=ring link=uCenter
uniform float uScale;

const float GR_TWO_PI = 6.28318530718;

float grHash11(float p)
{
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float grHash21(vec2 p)
{
	p = fract(p * vec2(0.3183099, 0.3678794)) + 0.1;
	p += dot(p, p + 19.19);
	return fract(p.x * p.y);
}

vec2 grRotate(vec2 v, float a)
{
	float s = sin(a), c = cos(a);
	return vec2(c * v.x + s * v.y, -s * v.x + c * v.y);
}

float grValueNoise(vec2 st)
{
	vec2 i = floor(st);
	vec2 f = fract(st);
	float a = grHash21(i);
	float b = grHash21(i + vec2(1.0, 0.0));
	float c = grHash21(i + vec2(0.0, 1.0));
	float d = grHash21(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float grRaysShape(vec2 uv, float r, float freq, float intensity)
{
	float a = atan(uv.y, uv.x);
	vec2 left = vec2(a * freq, r);
	vec2 right = vec2(fract(a / GR_TWO_PI) * GR_TWO_PI * freq, r);
	float n_left = pow(grValueNoise(left), intensity);
	float n_right = pow(grValueNoise(right), intensity);
	return mix(n_right, n_left, smoothstep(-0.15, 0.15, uv.x));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	float aspect = iResolution.x / iResolution.y;
	float t = 0.2 * iTime; // Speed/Seed shape iTime

	vec2 uv = fragCoord / iResolution.xy;
	vec2 origin = uCenter / iResolution.xy; // #point delivers pixels
	uv -= (origin - 0.5);
	vec2 shapeUV = uv - 0.5;
	shapeUV.x *= aspect; // aspect-correct: round rays
	shapeUV /= max(uScale, 0.01);

	float radius = length(shapeUV);
	float spots = 6.5 * abs(uSpotty);
	float intensity = 4.0 - 3.0 * clamp(uIntensity, 0.0, 1.0);

	float midSize = 10.0 * abs(uMidSize);
	float ms_lo = 0.02 * midSize;
	float ms_hi = max(midSize, 1e-6);
	float middleShape = pow(uMidIntensity, 0.3) * (1.0 - smoothstep(ms_lo, ms_hi, 3.0 * radius));
	middleShape = pow(middleShape, 5.0);

	float density = 6.0 * uDensity + step(0.5, uDensity) * pow(4.5 * (uDensity - 0.5), 4.0);

	vec3 accumColor = vec3(0.0);
	float accumAlpha = 0.0;

	for (int i = 0; i < 5; i++)
	{
		if (i >= uColoursCount) break;

		vec2 rotatedUV = grRotate(shapeUV, float(i) + 1.0);

		float r1 = radius * (1.0 + 0.4 * float(i)) - 3.0 * t;
		float r2 = 0.5 * radius * (1.0 + spots) - 2.0 * t;
		float f = mix(1.0, 3.0 + 0.5 * float(i), grHash11(float(i) * 15.0)) * density;

		float ray = grRaysShape(rotatedUV, r1, 5.0 * f, intensity);
		ray *= grRaysShape(rotatedUV, r2, 4.0 * f, intensity);
		ray += (1.0 + 4.0 * ray) * middleShape;
		ray = clamp(ray, 0.0, 1.0);

		float srcAlpha = uColours[i].a * ray;
		vec3 srcColor = uColours[i].rgb * srcAlpha;

		vec3 alphaBlendColor = accumColor + (1.0 - accumAlpha) * srcColor;
		float alphaBlendAlpha = accumAlpha + (1.0 - accumAlpha) * srcAlpha;

		vec3 addBlendColor = accumColor + srcColor;
		float addBlendAlpha = accumAlpha + srcAlpha;

		accumColor = mix(alphaBlendColor, addBlendColor, uBloom);
		accumAlpha = mix(alphaBlendAlpha, addBlendAlpha, uBloom);
	}

	float overlayAlpha = uColorBloom.a;
	vec3 overlayColor = uColorBloom.rgb * overlayAlpha;
	vec3 colorWithOverlay = accumColor + accumAlpha * overlayColor;
	accumColor = mix(accumColor, colorWithOverlay, uBloom);

	vec3 bgColor = uColorBack.rgb * uColorBack.a;
	vec3 color = accumColor + (1.0 - accumAlpha) * bgColor;
	float opacity = accumAlpha + (1.0 - accumAlpha) * uColorBack.a;
	color = clamp(color, 0.0, 1.0);
	opacity = clamp(opacity, 0.0, 1.0);

	vec3 rgb = opacity > 1e-4 ? color / opacity : color; // un-premultiply
	fragColor = vec4(rgb, opacity);
}