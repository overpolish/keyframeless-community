// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template filter

// #percent label="Threshold" group={"Bloom", "sparkles"} min=0 max=100 default=45
uniform float uThresh;

// #percent label="Intensity" group="Bloom" min=0 max=200 default=80
uniform float uIntensity;

// #int label="Radius" group="Bloom" units="px" min=1 max=600 slidermax=200 default=14
uniform float uSize;

// #int label="Quality" group="Bloom" min=8 max=48 default=24
uniform int uSamples;

const float GOLDEN_ANGLE = 2.399963;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;
	vec4 source = texture(iChannel0, uv);

	float radius = max(float(uSize), 1.0);
	float sampleCount = float(uSamples);

	vec3 bloom = vec3(0.0);
	float totalWeight = 0.0;

	for (int i = 0; i < 48; ++i)
	{
		if (i >= uSamples)
			break;

		float index = float(i);
		float angle = index * GOLDEN_ANGLE;
		float distance = sqrt(index / sampleCount) * radius;
		vec2 direction = vec2(cos(angle), sin(angle));
		vec2 offset = direction * distance / iResolution.xy;

		vec3 sampleColor = texture(
		                       iChannel0,
		                       clamp(uv + offset, 0.0, 1.0)
		                   ).rgb;

		float luminance = dot(sampleColor, vec3(0.299, 0.587, 0.114));
		float brightness = max(luminance - uThresh, 0.0);
		float weight = 1.0 - distance / radius;

		bloom += sampleColor * brightness * weight;
		totalWeight += weight;
	}

	bloom /= max(totalWeight, 0.001);

	vec3 color = source.rgb + bloom * uIntensity * 2.0;
	fragColor = vec4(color, source.a);
}
