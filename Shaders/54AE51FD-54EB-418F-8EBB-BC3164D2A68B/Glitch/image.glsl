// SPDX-FileCopyrightText: 2011 Ashima Arts (simplex noise, Ian McEwan / stegu)
// SPDX-License-Identifier: MIT
//
// Analog Glitch - a VHS-style distortion filter: simplex-noise horizontal
// tearing, chroma (RGB) shift, scanlines and static over the source clip.
// The snoise() function is Ashima Arts' 2D simplex noise (webgl-noise, MIT).
// Effect credit: <add the source you took the glitch effect from>.
// Adapted to GLSL directive controls for Shader; samples iChannel0 = source.

// #percent label="Amount" default=100
uniform float uAmount;

// #percent label="RGB Shift" default=100
uniform float uRGBShift;

// #percent label="Interference" default=100
uniform float uInterference;

// #percent label="Scanlines" default=100
uniform float uScanlines;

vec3 agMod289(vec3 x)
{
	return x - floor(x * (1.0 / 289.0)) * 289.0;
}
vec2 agMod289(vec2 x)
{
	return x - floor(x * (1.0 / 289.0)) * 289.0;
}
vec3 agPermute(vec3 x)
{
	return agMod289(((x * 34.0) + 1.0) * x);
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
	i = agMod289(i);
	vec3 p = agPermute(agPermute(i.y + vec3(0.0, i1.y, 1.0)) + i.x + vec3(0.0, i1.x, 1.0));
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

float agRand(vec2 co)
{
	return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord.xy / iResolution.xy;
	float time = iTime * 2.0; // Speed/Seed shape iTime

	// Large incidental noise waves + smaller constant waves.
	float noise = max(0.0, snoise(vec2(time, uv.y * 0.3)) - 0.3) * (1.0 / 0.7);
	noise = noise + (snoise(vec2(time * 10.0, uv.y * 2.4)) - 0.5) * 0.15;
	noise *= uAmount; // master glitch amount

	// Horizontal displacement per scanline.
	float xpos = uv.x - noise * noise * 0.25;
	fragColor = texture(iChannel0, vec2(xpos, uv.y));

	// Random line interference.
	fragColor.rgb = mix(fragColor.rgb, vec3(agRand(vec2(uv.y * time))), noise * 0.3 * uInterference);

	// Darken a line pattern every 4 pixels.
	if (floor(mod(fragCoord.y * 0.25, 2.0)) == 0.0)
		fragColor.rgb *= 1.0 - (0.15 * noise * uScanlines);

	// Shift green/blue channels off the red channel (chroma tear).
	float shift = noise * 0.05 * uRGBShift;
	fragColor.g = mix(fragColor.r, texture(iChannel0, vec2(xpos + shift, uv.y)).g, 0.25);
	fragColor.b = mix(fragColor.r, texture(iChannel0, vec2(xpos - shift, uv.y)).b, 0.25);
}
