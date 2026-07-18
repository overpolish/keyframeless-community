// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT
//
// Grid Lines - renders the source as a mesh of grid lines displaced within each
// cell by the footage brightness (horizontal + vertical profiles), an
// oscilloscope-style relief. Samples iChannel0 = source. Original code.

// #int label="Lines" min=8 max=128 default=60
uniform float uLines;

// #color label="Line" default="#FFFFFF"
uniform vec4 uLine;

// #int label="Thickness" min=1 default=2
uniform float uThick;

// #percent label="Background" default=0
uniform float uBackground;

float glBri(vec2 p)
{
	return length(texture(iChannel0, clamp(p, 0.0, 1.0)).rgb) / 1.7320508;
}

float glLine(float v)
{
	float aa = fwidth(v) + 1e-6;
	return 1.0 - smoothstep(0.0, aa * uThick, abs(v));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	float N = max(uLines, 1.0);
	vec2 uv = fragCoord / iResolution.xy;
	vec2 gpos = uv * N;
	vec2 cellId = floor(gpos);
	vec2 local = fract(gpos) - 0.5; // -0.5..0.5 within cell
	vec2 cc = (cellId + 0.5) / N; // cell centre uv

	// Horizontal line, displaced by brightness sampled along this row.
	float bh = glBri(vec2(uv.x, cc.y)) - 0.5;
	float lineH = glLine(local.y - bh);

	// Vertical line, displaced by brightness sampled along this column.
	float bv = glBri(vec2(cc.x, uv.y)) - 0.5;
	float lineV = glLine(local.x - bv);

	float line = max(lineH, lineV);

	vec3 bg = mix(vec3(0.0), texture(iChannel0, uv).rgb * 0.35, uBackground);
	fragColor = vec4(mix(bg, uLine.rgb, line), 1.0);
}
