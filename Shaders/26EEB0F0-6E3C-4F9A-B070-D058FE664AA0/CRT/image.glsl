// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #percent osc=ring label="Curvature" center=0.5,0.5 default=30
uniform float uCurve;

// #percent label="Scanlines" default=60
uniform float uScan;

// #percent label="Mask" default=40
uniform float uMask;

// #percent label="Vignette" default=50
uniform float uVig;

// #percent label="Chroma" default=30
uniform float uChroma;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;
	// Barrel curvature.
	vec2 cc = uv * 2.0 - 1.0;
	cc *= 1.0 + uCurve * 0.25 * dot(cc, cc);
	vec2 suv = cc * 0.5 + 0.5;
	if (suv.x < 0.0 || suv.x > 1.0 || suv.y < 0.0 || suv.y > 1.0)
	{
		fragColor = vec4(0.0, 0.0, 0.0, 1.0);
		return;
	}
	// Chroma bleed.
	vec2 off = (suv - 0.5) * uChroma * 0.02;
	vec3 col;
	col.r = texture(iChannel0, clamp(suv + off, 0.0, 1.0)).r;
	col.g = texture(iChannel0, suv).g;
	col.b = texture(iChannel0, clamp(suv - off, 0.0, 1.0)).b;
	// Scanlines.
	float sl = 0.5 + 0.5 * sin(fragCoord.y * 3.14159);
	col *= 1.0 - uScan * 0.6 * sl;
	// Aperture mask (RGB stripes).
	float m = mod(fragCoord.x, 3.0);
	vec3 mask = vec3(m < 1.0 ? 1.2 : 0.85, (m >= 1.0 && m < 2.0) ? 1.2 : 0.85, m >= 2.0 ? 1.2 : 0.85);
	col *= mix(vec3(1.0), mask, uMask);
	// Vignette.
	float v = 1.0 - uVig * 0.8 * dot(cc, cc) * 0.5;
	col *= clamp(v, 0.0, 1.0);
	fragColor = vec4(col, 1.0);
}