// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT
//
// Mosaic - a tiling pixelation filter over the source clip, with a selectable
// cell shape. Samples iChannel0 = source.

// #choice label="Shape" options="Square,Triangle,Diamond,Hexagon" default=1
uniform int uShape;

// #int label="Tiles" min=4 max=200 default=40
uniform float uTiles;

vec2 mzHexCenter(vec2 g)
{
	vec2 s = vec2(1.0, 1.7320508);
	vec2 a = mod(g, s) - s * 0.5;
	vec2 b = mod(g - s * 0.5, s) - s * 0.5;
	return dot(a, a) < dot(b, b) ? (g - a) : (g - b);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;
	float aspect = iResolution.x / iResolution.y;
	float dens = max(uTiles, 1.0);
	vec2 T = vec2(dens, max(1.0, dens / aspect)); // aspect-corrected square cells

	vec2 s; // representative sample point (uv space)
	if (uShape == 0)
	{
		// Square: cell centre.
		s = (floor(uv * T) + 0.5) / T;
	}
	else if (uShape == 1)
	{
		// Triangle: both diagonals split each cell into 4 facets.
		vec2 base = floor(uv * T) / T;
		vec2 f = fract(uv * T);
		vec2 off = vec2(step(1.0 - f.y, f.x), step(f.x, f.y)) * 0.5 / T;
		s = base + off + 0.25 / T;
	}
	else if (uShape == 2)
	{
		// Diamond: square grid rotated 45 degrees (aspect-corrected so it stays square).
		mat2 Rp = mat2(0.7071, -0.7071, 0.7071, 0.7071);
		mat2 Rn = mat2(0.7071, 0.7071, -0.7071, 0.7071);
		vec2 c = (uv - 0.5) * vec2(aspect, 1.0);
		vec2 q = floor(Rp * c * dens) + 0.5;
		vec2 cc = (Rn * q) / dens;
		s = cc / vec2(aspect, 1.0) + 0.5;
	}
	else
	{
		// Hexagon: nearest hex centre.
		vec2 g = vec2(uv.x * aspect, uv.y) * dens;
		vec2 c = mzHexCenter(g);
		s = vec2((c.x / dens) / aspect, c.y / dens);
	}

	fragColor = texture(iChannel0, clamp(s, 0.0, 1.0));
}