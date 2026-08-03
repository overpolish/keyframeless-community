// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template generator

// #speed group={"Motion", "wind"}
// #seed group="Motion"
// #grain label="Grain" group={"Finish", "camera.filters"} default=0 size=2

// #color label="Colours" min=2 max=8 default="#8FE3FF,#FF9BE3,#C9B8FF"
uniform vec4 uColours[8];

// #int label="Detail" group={"Pattern", "circle.hexagongrid"} min=4 max=12 default=8
uniform float uDetail;

// #percent label="Warp" group="Pattern" min=0 max=250 default=100
uniform float uWarp;

// #point label="Center" group="Pattern" osc=position default="0.5,0.5"
uniform vec2 uCenter;

// #percent label="Scale" group="Pattern" min=25 max=400 default=100 osc=ring link=uCenter
uniform float uScale;

// #percent label="Palette Mix" group={"Appearance", "sparkles"} min=0 max=100 default=70
uniform float uTint;

// #percent label="Sheen" group="Appearance" min=0 max=200 default=100
uniform float uSheen;

vec3 auroraPalette(float position)
{
	int count = max(uColoursCount, 1);

	if (count == 1)
		return uColours[0].rgb;

	float paletteIndex = clamp(position, 0.0, 1.0) * float(count - 1);
	int lower = int(floor(paletteIndex));
	int upper = min(lower + 1, count - 1);

	return mix(uColours[lower].rgb, uColours[upper].rgb, fract(paletteIndex));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	float minSide = min(iResolution.x, iResolution.y);
	vec2 p = (fragCoord - uCenter) * (2.0 / minSide);
	p /= max(uScale, 0.001);

	float t = iTime;
	int detail = uDetail;

	float q = 0.0;
	float r = -t * 0.4;

	for (int i = 0; i < 12; ++i)
	{
		if (i >= detail)
			break;

		float octave = float(i);
		q += cos(octave + r + q * p.y * uWarp);
		r += sin(octave * p.x - q);
	}

	r += t * 0.4;

	vec3 base =
	    0.55 +
	    0.45 * cos(vec3(q, r, q + r) * 0.6 + vec3(0.0, 2.0, 4.0));

	vec3 modulation = vec3(
	                      cos(0.7 * r),
	                      cos(0.7 * q),
	                      sin(0.9 * (q + r))
	                  );

	vec3 iridescence = cos(base * modulation * 0.5 + 0.5);
	float sheen = dot(iridescence, vec3(0.299, 0.587, 0.114));
	sheen = clamp(0.5 + (sheen - 0.5) * uSheen, 0.0, 1.0);

	float hueField =
	    0.5 +
	    0.5 * sin(1.2 * p.x + 0.8 * p.y + 0.25 * q + 0.15 * t);

	vec3 palette = auroraPalette(hueField);
	vec3 recoloured = sheen * mix(vec3(1.0), palette, 0.9);
	vec3 color = mix(iridescence, recoloured, uTint);

	fragColor = vec4(color, 1.0);
}