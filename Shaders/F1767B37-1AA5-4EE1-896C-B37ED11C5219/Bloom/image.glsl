// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #percent label="Threshold" default=45
uniform float uThresh;

// #percent label="Intensity" default=80
uniform float uIntensity;

// #int label="Size" min=1 default=14
uniform float uSize;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;
	vec4 base = texture(iChannel0, uv);
	vec3 bloom = vec3(0.0);
	float tot = 0.0;
	for (int i = 0; i < 24; i++)
	{
		float fi = float(i);
		float ang = fi * 2.399963;
		float rad = sqrt(fi / 24.0) * uSize;
		vec2 off = vec2(cos(ang), sin(ang)) * rad / iResolution.xy;
		vec3 s = texture(iChannel0, clamp(uv + off, 0.0, 1.0)).rgb;
		float b = max(dot(s, vec3(0.299, 0.587, 0.114)) - uThresh, 0.0);
		float w = 1.0 - rad / uSize;
		bloom += s * b * w;
		tot += w;
	}
	bloom /= max(tot, 1e-3);
	fragColor = vec4(base.rgb + bloom * uIntensity * 2.0, base.a);
}
