// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #int label="Levels" min=2 max=8 default=4
uniform float uLevels;

// #percent label="Edges" default=100
uniform float uEdges;

// #color label="Edge Colour" default="#0A0A0A"
uniform vec4 uEdgeCol;

float lumAt(vec2 uv)
{
	return dot(texture(iChannel0, clamp(uv, 0.0, 1.0)).rgb, vec3(0.299, 0.587, 0.114));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;
	vec2 px = 1.0 / iResolution.xy;
	vec4 src = texture(iChannel0, uv);

	// Posterise.
	float L = max(uLevels, 2.0);
	vec3 post = floor(src.rgb * (L - 1.0) + 0.5) / (L - 1.0);

	// Sobel edge on luminance.
	float gx = lumAt(uv + px * vec2(1, -1)) + 2.0 * lumAt(uv + px * vec2(1, 0)) + lumAt(uv + px * vec2(1, 1))
	           - lumAt(uv + px * vec2(-1, -1)) - 2.0 * lumAt(uv + px * vec2(-1, 0)) - lumAt(uv + px * vec2(-1, 1));
	float gy = lumAt(uv + px * vec2(-1, 1)) + 2.0 * lumAt(uv + px * vec2(0, 1)) + lumAt(uv + px * vec2(1, 1))
	           - lumAt(uv + px * vec2(-1, -1)) - 2.0 * lumAt(uv + px * vec2(0, -1)) - lumAt(uv + px * vec2(1, -1));
	float edge = smoothstep(0.4, 1.2, length(vec2(gx, gy))) * uEdges;

	fragColor = vec4(mix(post, uEdgeCol.rgb, edge), src.a);
}
