// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #color label="Colours" min=2 max=5 default="#0B1026,#3A2E6B,#C0466B,#F2A65A,#FFF3C0"
uniform vec4 uColours[5];
// #percent label="Mix" default=100
uniform float uMix;

vec3 gmPalette(float f)
{
	int n = max(uColoursCount, 1);
	if (n == 1) return uColours[0].rgb;
	f = clamp(f, 0.0, 1.0) * float(n - 1);
	int i0 = int(floor(f));
	int i1 = min(i0 + 1, n - 1);
	return mix(uColours[i0].rgb, uColours[i1].rgb, fract(f));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec4 src = texture(iChannel0, fragCoord / iResolution.xy);
	float lum = dot(src.rgb, vec3(0.299, 0.587, 0.114));
	fragColor = vec4(mix(src.rgb, gmPalette(lum), uMix), src.a);
}
