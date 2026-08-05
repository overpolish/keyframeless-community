// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #percent label="Threshold" min=0 max=100 default=45
uniform float uThresh;
// #percent label="Intensity" min=0 max=200 default=80
uniform float uIntensity;
// #int label="Radius" units="px" min=1 max=600 slidermax=200 default=14
uniform float uSize;
// #int label="Quality" min=8 max=48 default=24
uniform int uSamples;

vec4 bloomBlur(sampler2D tex, vec2 uv, vec2 axis)
{
	int halfTaps = clamp(uSamples / 2, 4, 24);
	float radius = max(uSize, 1.0);
	vec4 sum = vec4(0.0);
	float weightSum = 0.0;

	for (int i = -24; i <= 24; ++i)
	{
		if (abs(i) > halfTaps)
			continue;
		float x = float(i) / float(halfTaps);
		float taper = 0.5 + 0.5 * cos(3.14159265 * x);
		float weight = exp(-4.5 * x * x) * taper;
		vec2 sampleUV = uv + axis * x * radius / iResolution.xy;
		if (all(greaterThanEqual(sampleUV, vec2(0.0))) &&
		    all(lessThan(sampleUV, vec2(1.0))))
			sum += texture(tex, sampleUV) * weight;
		weightSum += weight;
	}
	return sum / max(weightSum, 0.0001);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	fragColor = bloomBlur(iChannel2, fragCoord / iResolution.xy, vec2(0.0, 1.0));
}
