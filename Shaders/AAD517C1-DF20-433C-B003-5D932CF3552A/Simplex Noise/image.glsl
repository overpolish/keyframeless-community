// SPDX-FileCopyrightText: The paper-design/shaders authors
// SPDX-License-Identifier: Apache-2.0
//
// Simplex Noise - derived from the simplex-noise shader in paper-design/shaders
// (https://github.com/paper-design/shaders). Translated to GLSL for Mirage and
// adapted for its directive controls. A palette mapped through two layered
// simplex noises, then quantised into soft bands.

// #color label="Colours" min=1 max=6 default="#0B1026,#274690,#5FA8D3,#F6E27A"
uniform vec4 uColours[6];

// #int label="Steps per Colour" min=1 max=12 default=4
uniform float uSteps;

// #percent label="Softness" default=60
uniform float uSoftness;

// #point label="Center" osc default="0.5,0.5"
uniform vec2 uCenter;

// #percent label="Scale" default=100 osc=ring link=uCenter
uniform float uScale;

vec3 snMod289(vec3 x)
{
	return x - floor(x * (1.0 / 289.0)) * 289.0;
}
vec3 snPermute(vec3 x)
{
	return snMod289(((x * 34.0) + 1.0) * x);
}

float snoise(vec2 v)
{
	const vec4 C = vec4(0.211324865405187, 0.366025403784439,
	                    -0.577350269189626, 0.024390243902439);
	vec2 i = floor(v + dot(v, C.yy));
	vec2 x0 = v - i + dot(i, C.xx);
	vec2 i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
	vec4 x12 = x0.xyxy + C.xxzz;
	x12.xy -= i1;
	i = i - floor(i * (1.0 / 289.0)) * 289.0;
	vec3 p = snPermute(snPermute(i.y + vec3(0.0, i1.y, 1.0)) + i.x + vec3(0.0, i1.x, 1.0));
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

float snGetNoise(vec2 uv, float t)
{
	float noise = 0.5 * snoise(uv - vec2(0.0, 0.3 * t));
	noise += 0.5 * snoise(2.0 * uv + vec2(0.0, 0.32 * t));
	return noise;
}

float snSteppedSmooth(float m, float steps, float softness)
{
	float stepT = floor(m * steps) / steps;
	float f = m * steps - floor(m * steps);
	float fw = steps * fwidth(m);
	float smoothed = smoothstep(0.5 - softness, min(1.0, 0.5 + softness + fw), f);
	return stepT + smoothed / steps;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	float aspect = iResolution.x / iResolution.y;
	float t = 0.2 * iTime; // Speed/Seed shape iTime

	vec2 origin = uCenter / iResolution.xy; // #point delivers pixels
	vec2 uv = fragCoord / iResolution.xy - (origin - 0.5) - 0.5;
	uv.x *= aspect;
	uv /= max(uScale, 0.01);
	uv *= 8.0; // pattern tiles

	float shape = 0.5 + 0.5 * snGetNoise(uv * 0.1, t);

	float cCount = max(float(uColoursCount), 1.0);
	float mixer = (shape - 0.5 / cCount) * cCount; // extraSides wrap
	float steps = max(1.0, uSteps);

	vec4 gradient = uColours[0];
	gradient.rgb *= gradient.a;
	for (int i = 1; i < 6; i++)
	{
		if (i >= int(cCount))
			break;
		float localM = clamp(mixer - float(i - 1), 0.0, 1.0);
		localM = snSteppedSmooth(localM, steps, 0.5 * uSoftness);
		vec4 c = uColours[i];
		c.rgb *= c.a;
		gradient = mix(gradient, c, localM);
	}

	// Wrap the ramp past both ends so the band gradient is seamless.
	if ((mixer < 0.0) || (mixer > (cCount - 1.0)))
	{
		float localM = (mixer > (cCount - 1.0)) ? (mixer - (cCount - 1.0)) : (mixer + 1.0);
		localM = snSteppedSmooth(localM, steps, 0.5 * uSoftness);
		vec4 cFst = uColours[0];
		cFst.rgb *= cFst.a;
		int lastIdx = int(cCount - 1.0);
		vec4 cLast = uColours[lastIdx];
		cLast.rgb *= cLast.a;
		gradient = mix(cLast, cFst, localM);
	}

	float a = gradient.a;
	vec3 rgb = a > 1e-4 ? gradient.rgb / a : gradient.rgb; // un-premultiply
	fragColor = vec4(rgb, a);
}