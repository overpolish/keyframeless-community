// SPDX-FileCopyrightText: mernking (GitLab: Godswork)
// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template transition

// #int label="Tracking Lines" group={"Signal", "antenna.radiowaves.left.and.right"} min=20 max=300 default=120
uniform float uTrackingLines;

// #percent label="Tear Chance" group="Signal" min=0 max=50 default=8
uniform float uTearChance;

// #percent label="Tear Amount" group="Signal" min=0 max=300 default=100
uniform float uTearAmount;

// #int label="Scanline Density" group={"Scanlines", "line.3.horizontal"} min=100 max=1800 default=900
uniform float uScanlineDensity;

// #percent label="Scanline Amount" group="Scanlines" min=0 max=200 default=100
uniform float uScanlineAmount;

float tvHash(vec2 position)
{
	return fract(sin(dot(position, vec2(127.1, 311.7))) * 43758.5453);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;
	float progress = clamp(iProgress, 0.0, 1.0);
	float strength = sin(progress * 3.14159265);

	vec4 fromColor = texture(iChannel0, uv);
	vec4 toColor = texture(iChannel1, uv);
	vec4 color = mixTransitionColors(fromColor, toColor, progress);

	float lineY = floor(uv.y * uTrackingLines);
	float noise = tvHash(vec2(lineY, progress * 20.0));
	float line = step(1.0 - uTearChance, noise);

	float drift = sin(uv.y * 30.0 + progress * 10.0);
	drift *= 0.02 * uTearAmount * strength;

	vec2 shiftedUV = clamp(uv + vec2(drift, 0.0), 0.0, 1.0);
	vec4 shiftedFrom = texture(iChannel0, shiftedUV);
	vec4 shiftedTo = texture(iChannel1, shiftedUV);
	vec4 lineColor = mixTransitionColors(shiftedFrom, shiftedTo, progress);

	color = mixTransitionColors(color, lineColor, line * strength);

	float scanline = sin(uv.y * uScanlineDensity) * 0.03;
	float coverage = max(fromColor.a, toColor.a);
	// Gated by coverage: an additive term on .rgb alone leaves rgb above alpha,
	// which is not a valid premultiplied pixel. In In/Out mode one endpoint is
	// transparent, so ungated this paints onto transparent black.
	color.rgb -= scanline * uScanlineAmount * strength * coverage;

	fragColor = color;
}