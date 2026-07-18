// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT
//
// Grid Hills - an undulating neon grid terrain fading into black fog. Raymarched
// heightfield with a grid overlay: hot-pink lines on deep blue. Original code.

// #color label="Base" default="#000D33"
uniform vec4 uBase;

// #color label="Grid" default="#FF3399"
uniform vec4 uGrid;

// #percent label="Hills" default=50
uniform float uHills;

// #percent label="Grid Size" default=50
uniform float uGridSize;

// #percent label="Fog" default=50
uniform float uFog;

float ghHeight(vec2 xz, float t)
{
	return (sin(xz.x * 0.6 + t * 0.5) + sin(xz.y * 0.5 - t * 0.3)
	        + 0.5 * sin(xz.x * 0.25 + xz.y * 0.3 + t * 0.2)) * uHills * 1.2;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
	float t = iTime * 0.4;

	// Camera above the terrain, drifting forward with a gentle sway.
	vec3 ro = vec3(sin(t * 0.1) * 2.0, 3.2, -t * 2.0);
	vec3 ta = ro + vec3(sin(t * 0.1) * 0.3, -0.9, 1.0);
	vec3 fwd = normalize(ta - ro);
	vec3 rgt = normalize(cross(vec3(0.0, 1.0, 0.0), fwd));
	vec3 up = cross(fwd, rgt);
	vec3 rd = normalize(uv.x * rgt + uv.y * up + fwd * 1.3);

	// March the heightfield (p.y - height(x,z)).
	float d = 0.0;
	bool hit = false;
	vec3 pos = ro;
	for (int i = 0; i < 120; i++)
	{
		pos = ro + rd * d;
		float h = pos.y - ghHeight(pos.xz, t);
		if (h < 0.001 * d)
		{
			hit = true;
			break;
		}
		d += h * 0.5;
		if (d > 40.0) break;
	}

	vec3 col = vec3(0.0); // black background
	if (hit)
	{
		vec2 g = pos.xz;
		float cell = mix(1.2, 0.3, uGridSize);
		vec2 gl = abs(fract(g / cell) - 0.5) * cell;
		float dl = min(gl.x, gl.y);
		float w = 0.02 * cell + fwidth(dl);
		float line = 1.0 - smoothstep(0.0, w, dl);
		col = mix(uBase.rgb, uGrid.rgb, line);
		float fogEnd = mix(40.0, 12.0, uFog); // distance fog to black
		col *= 1.0 - smoothstep(0.0, fogEnd, d);
	}

	fragColor = vec4(col, 1.0);
}