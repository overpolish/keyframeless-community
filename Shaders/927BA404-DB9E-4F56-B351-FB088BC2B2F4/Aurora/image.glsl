// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT
//
// Aurora - holographic iridescent silk. Coupled accumulators fold the field for
// the silk ridges (fast detail); a slow field maps the palette into big smooth
// colour regions; a high-key mapping carries the pearlescent sheen.

// #color label="Colours" min=2 max=4 default="#8FE3FF,#FF9BE3,#C9B8FF"
uniform vec4 uColours[4];

// #int label="Detail" min=4 max=12 default=8
uniform float uDetail;

// #percent label="Warp" default=100
uniform float uWarp;

// #percent label="Colour" default=70
uniform float uTint;

// #point label="Center" osc default="0.5,0.5"
uniform vec2 uCenter;

// #percent label="Scale" default=100 osc=ring link=uCenter
uniform float uScale;

vec3 auroraPalette(float f)
{
	int n = max(uColoursCount, 1);
	if (n == 1)
		return uColours[0].rgb;
	f = clamp(f, 0.0, 1.0) * float(n - 1);
	int i0 = int(floor(f));
	int i1 = min(i0 + 1, n - 1);
	return mix(uColours[i0].rgb, uColours[i1].rgb, fract(f));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	float mr = min(iResolution.x, iResolution.y);
	vec2 p = (fragCoord * 2.0 - iResolution.xy) / mr; // centred, aspect-correct

	vec2 origin = uCenter / iResolution.xy; // #point delivers pixels
	p -= (origin - 0.5) * 2.0 * iResolution.xy / mr; // pan
	p /= max(uScale, 0.01); // zoom

	float t = iTime; // Speed/Seed shape iTime
	float w = uWarp;
	int N = int(uDetail);

	// Coupled accumulators: `q` folds by its own value against the vertical axis
	// for the swept silk ridges; `r` ramps frequency by octave for detail.
	float q = 0.0;
	float r = -t * 0.4;
	for (int i = 0; i < 12; i++)
	{
		if (i >= N)
			break;
		float fi = float(i);
		q += cos(fi + r + q * p.y * w);
		r += sin(fi * p.x - q);
	}
	r += t * 0.4;

	// High-key iridescence -> pearlescent brightness (grayscale sheen + ridges).
	vec3 base = 0.55 + 0.45 * cos(vec3(q, r, q + r) * 0.6 + vec3(0.0, 2.0, 4.0));
	vec3 modl = vec3(cos(0.7 * r), cos(0.7 * q), sin(0.9 * (q + r)));
	vec3 iri = cos(base * modl * 0.5 + 0.5);
	float sheen = dot(iri, vec3(0.299, 0.587, 0.114));

	// SLOW hue field -> big smooth palette regions that gently warp with the
	// folds, so swapping colours visibly re-skins the whole thing.
	float hueField = 0.5 + 0.5 * sin(1.2 * p.x + 0.8 * p.y + 0.25 * q + 0.15 * t);
	vec3 tint = auroraPalette(hueField);
	vec3 recol = sheen * mix(vec3(1.0), tint, 0.9);

	// Colour: 0 = intrinsic iridescence, 1 = your palette.
	vec3 col = mix(iri, recol, uTint);

	fragColor = vec4(col, 1.0);
}