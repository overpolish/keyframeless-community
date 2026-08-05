// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #choice label="Quality" options="Draft,Standard,High" default=1
uniform int uQuality;
// #percent label="Threshold" min=0 max=100 default=58
uniform float uThreshold;
// #percent label="Softness" min=0 max=100 default=35
uniform float uSoftness;
// #int label="Radius" units="px" min=1 slidermax=120 default=36
uniform float uRadius;
// #percent label="Bloom" min=0 max=150 default=45
uniform float uBloom;
// #percent label="Diffusion" min=0 max=100 default=18
uniform float uDiffusion;
// #percent label="Mist" min=0 max=100 default=22
uniform float uMist;
// #percent label="Black Lift" min=0 max=100 default=6
uniform float uBlackLift;
// #percent label="Mix" min=0 max=100 default=100
uniform float uMix;
// #color label="Bloom Colour" default="#FFF2DE"
uniform vec4 uBloomColor;
// #float label="Warm / Cool" min=-100 max=100 default=0
uniform float uWarmCool;

vec4 mistBlur(sampler2D tex, vec2 uv, vec2 axis)
{
	int halfTaps = 12;
	if (uQuality == 0) halfTaps = 6;
	if (uQuality == 2) halfTaps = 20;
	float radius = max(uRadius, 1.0);
	vec4 sum = vec4(0.0);
	float weightSum = 0.0;
	for (int i = -20; i <= 20; ++i)
	{
		if (abs(i) > halfTaps) continue;
		float x = float(i) / float(halfTaps);
		float taper = 0.5 + 0.5 * cos(3.14159265 * x);
		float weight = exp(-4.0 * x * x) * taper;
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
	fragColor = mistBlur(iChannel1, fragCoord / iResolution.xy, vec2(1.0, 0.0));
}
