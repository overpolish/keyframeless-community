// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT
//
// Prisma - a glowing cellular wave. Animated Voronoi sites in bobbing rows form
// stained-glass cells; the nearest/second-nearest gap draws luminous edges and
// bloom over a soft palette wash.

// #color label="Colours" min=2 max=4 default="#5BC8E8,#B57EE8,#FF8FB0,#FFD98F"
uniform vec4 uColours[4];

// #int label="Cells" min=6 max=28 default=16
uniform float uCells;

// #percent label="Glow" default=100
uniform float uGlow;

// #percent label="Wave" default=100
uniform float uWave;

// #point label="Center" osc default="0.5,0.5"
uniform vec2 uCenter;

// #percent label="Scale" default=100 osc=ring link=uCenter
uniform float uScale;

vec3 prismaPalette(float f)
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
	vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
	uv -= (uCenter - 0.5 * iResolution.xy) / iResolution.y; // #point pan
	uv /= max(uScale, 0.01); // zoom
	uv *= 1.8; // spread to see cells

	float t = iTime * 0.3; // Speed/Seed shape iTime
	int N = int(uCells);

	// Nearest (f1) and second-nearest (f2) site distances, plus the nearest
	// site itself. Sites sit in rows and bob vertically like a wave.
	float f1 = 9.0, f2 = 9.0;
	vec2 near = vec2(0.0);
	for (int i = 0; i < 28; i++)
	{
		if (i >= N)
			break;
		float fi = float(i);
		float row = floor(fi / 5.0);
		vec2 site = vec2(1.6 * sin(fi * 2.3),
		                 -0.75 + 0.5 * row + uWave * 0.28 * sin(fi + t + uv.x));
		float d = distance(uv, site);
		if (d < f1)
		{
			f2 = f1;
			f1 = d;
			near = site;
		}
		else if (d < f2)
		{
			f2 = d;
		}
	}

	// Cell colour from its site; soft palette wash underneath.
	float cellHue = 0.5 + 0.5 * sin(1.5 * near.x + 2.0 * near.y);
	float bgHue = 0.5 + 0.5 * sin(0.8 * uv.x + 0.2 * t);
	vec3 col = mix(prismaPalette(bgHue), prismaPalette(cellHue), 0.6);

	// Luminous edges (f2 ~ f1 at cell borders) + softer bloom around them.
	float edge = 1.0 - smoothstep(0.0, 0.05, f2 - f1);
	float bloom = 1.0 - smoothstep(0.0, 0.25, f2 - f1);
	col += edge * uGlow * vec3(1.0);
	col += bloom * 0.25 * uGlow * prismaPalette(cellHue);

	fragColor = vec4(col * 1.15, 1.0);
}