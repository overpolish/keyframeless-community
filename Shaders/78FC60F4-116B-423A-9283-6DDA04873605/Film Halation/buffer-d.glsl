// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #percent label="Threshold" min=0 max=100 default=70
uniform float uThreshold;
// #percent label="Softness" min=0 max=100 default=25
uniform float uSoftness;
// #percent label="Highlight Protection" min=0 max=100 default=75
uniform float uProtection;
// #percent label="Intensity" min=0 max=200 default=45
uniform float uIntensity;
// #int label="Spread" units="px" min=1 slidermax=80 default=20
uniform float uSpread;
// #percent label="Warmth" min=0 max=100 default=80
uniform float uWarmth;
// #color label="Halation Colour" default="#FF5428"
uniform vec4 uHaloColor;
// #percent label="Mix" min=0 max=100 default=100
uniform float uMix;

vec4 halationBlur(sampler2D tex, vec2 uv, vec2 axis)
{
	vec4 sum = vec4(0.0);
	float weightSum = 0.0;
	for (int i = -16; i <= 16; ++i)
	{
		float x = float(i) / 16.0;
		float taper = 0.5 + 0.5 * cos(3.14159265 * x);
		float weight = exp(-3.5 * x * x) * taper;
		vec2 sampleUV = uv + axis * x * max(uSpread, 1.0) / iResolution.xy;
		if (all(greaterThanEqual(sampleUV, vec2(0.0))) &&
		    all(lessThan(sampleUV, vec2(1.0))))
			sum += texture(tex, sampleUV) * weight;
		weightSum += weight;
	}
	return sum / max(weightSum, 0.0001);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	fragColor = halationBlur(iChannel2, fragCoord / iResolution.xy, vec2(0.0, 1.0));
}
