// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT
//
// Dither - a retro dithering filter over the source clip. Quantises colour depth
// and breaks the banding with an ordered Bayer or noise threshold. Original code.
// Samples iChannel0 = source.

// #choice label="Mode" options="Colour,Mono,Duotone" default=2
uniform int uMode;

// #choice label="Pattern" options="Bayer 2,Bayer 4,Bayer 8,Noise" default=2
uniform int uPattern;

// #int label="Levels" min=2 max=8 default=3
uniform float uLevels;

// #int label="Pixel Size" min=1 max=16 default=6
uniform float uPixelSize;

// #color label="Duotone" min=2 max=2 default="#0A0A12,#F2E9E4"
uniform vec4 uColours[2];

const int bayer2[4] = int[](0, 2, 3, 1);
const int bayer4[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
const int bayer8[64] = int[](
                           0, 32, 8, 40, 2, 34, 10, 42, 48, 16, 56, 24, 50, 18, 58, 26,
                           12, 44, 4, 36, 14, 46, 6, 38, 60, 28, 52, 20, 62, 30, 54, 22,
                           3, 35, 11, 43, 1, 33, 9, 41, 51, 19, 59, 27, 49, 17, 57, 25,
                           15, 47, 7, 39, 13, 45, 5, 37, 63, 31, 55, 23, 61, 29, 53, 21);

float dHash(vec2 p)
{
	p = fract(p * vec2(0.3183099, 0.3678794)) + 0.1;
	p += dot(p, p + 19.19);
	return fract(p.x * p.y);
}

float dThreshold(vec2 cell, int pat)
{
	if (pat == 0)
	{
		ivec2 q = ivec2(mod(cell, 2.0));
		return (float(bayer2[q.y * 2 + q.x]) + 0.5) / 4.0;
	}
	else if (pat == 1)
	{
		ivec2 q = ivec2(mod(cell, 4.0));
		return (float(bayer4[q.y * 4 + q.x]) + 0.5) / 16.0;
	}
	else if (pat == 2)
	{
		ivec2 q = ivec2(mod(cell, 8.0));
		return (float(bayer8[q.y * 8 + q.x]) + 0.5) / 64.0;
	}
	return dHash(cell);
}

float dQuant(float v, float th, float L)
{
	float step = 1.0 / (L - 1.0);
	v += (th - 0.5) * step; // dither offset
	return clamp(floor(v / step + 0.5) * step, 0.0, 1.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	float px = max(uPixelSize, 1.0);
	vec2 cell = floor(fragCoord / px);
	vec2 uvCell = (cell * px + 0.5 * px) / iResolution.xy;
	vec4 src = texture(iChannel0, clamp(uvCell, 0.0, 1.0));

	float th = dThreshold(cell, uPattern);
	float L = max(uLevels, 2.0);

	vec3 col;
	if (uMode == 1) // Mono
	{
		float lum = dot(src.rgb, vec3(0.299, 0.587, 0.114));
		col = vec3(dQuant(lum, th, L));
	}
	else if (uMode == 2) // Duotone
	{
		float lum = dot(src.rgb, vec3(0.299, 0.587, 0.114));
		col = mix(uColours[0].rgb, uColours[1].rgb, dQuant(lum, th, L));
	}
	else // Colour
	{
		col = vec3(dQuant(src.r, th, L), dQuant(src.g, th, L), dQuant(src.b, th, L));
	}

	fragColor = vec4(col, src.a);
}
