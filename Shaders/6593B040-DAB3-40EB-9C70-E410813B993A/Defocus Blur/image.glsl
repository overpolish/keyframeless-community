// SPDX-FileCopyrightText: Sergey Kosarevsky
// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template transition
//
// Derived from https://gist.github.com/corporateshark/b9f8e5675c647e615419
// Poisson offsets from https://github.com/spite/Wagner

// #percent label="Blur Amount" group={"Blur", "drop"} min=0 max=50 slidermax=20 default=2
uniform float uBlurSize;

// #choice label="Quality" group="Blur" options="Draft,Standard,High" default=1
uniform int uQuality;

// #choice label="Edges" group="Blur" options="Clamp,Mirror" default=0
uniform int uEdges;

// #percent label="Blur Peak" group={"Timing", "clock"} min=5 max=95 default=50
uniform float uPeak;

// #float label="Blur Curve" group="Timing" min=0.25 max=4 default=1
uniform float uCurve;

const vec2 POISSON[24] = vec2[](
                             vec2(-0.326, -0.406),
                             vec2(-0.840, -0.074),
                             vec2(-0.696, 0.457),
                             vec2(-0.203, 0.621),
                             vec2(0.962, -0.195),
                             vec2(0.473, -0.480),
                             vec2(0.519, 0.767),
                             vec2(0.185, -0.893),
                             vec2(0.507, 0.064),
                             vec2(0.896, 0.412),
                             vec2(-0.322, -0.933),
                             vec2(-0.792, -0.598),
                             vec2(0.326, 0.406),
                             vec2(0.840, 0.074),
                             vec2(0.696, -0.457),
                             vec2(0.203, -0.621),
                             vec2(-0.962, 0.195),
                             vec2(-0.473, 0.480),
                             vec2(-0.519, -0.767),
                             vec2(-0.185, 0.893),
                             vec2(-0.507, -0.064),
                             vec2(-0.896, -0.412),
                             vec2(0.322, 0.933),
                             vec2(0.792, 0.598)
                         );

float sat(float value)
{
	return clamp(value, 0.0, 1.0);
}

vec2 mirrorUV(vec2 uv)
{
	return 1.0 - abs(mod(uv, 2.0) - 1.0);
}

vec2 resolveUV(vec2 uv)
{
	if (uEdges == 1)
		return mirrorUV(uv);

	return clamp(uv, 0.0, 1.0);
}

float blurEnvelope(float progress)
{
	float peak = clamp(uPeak, 0.001, 0.999);
	float envelope = progress < peak ? progress / peak : (1.0 - progress) / (1.0 - peak);
	return pow(sat(envelope), uCurve);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;
	float progress = clamp(iProgress, 0.0, 1.0);

	if (progress <= 0.0)
	{
		fragColor = texture(iChannel0, uv);
		return;
	}

	if (progress >= 1.0)
	{
		fragColor = texture(iChannel1, uv);
		return;
	}

	float radius = uBlurSize * blurEnvelope(progress);
	float aspect = iResolution.x / iResolution.y;
	vec2 aspectCorrection = vec2(1.0 / aspect, 1.0);

	int tapCount = 12;

	if (uQuality == 0)
		tapCount = 6;
	else if (uQuality == 2)
		tapCount = 24;

	vec4 fromColor = texture(iChannel0, uv);
	vec4 toColor = texture(iChannel1, uv);

	for (int i = 0; i < 24; ++i)
	{
		if (i >= tapCount)
			break;

		vec2 offset = POISSON[i] * radius * aspectCorrection;
		vec2 sampleUV = resolveUV(uv + offset);

		fromColor += texture(iChannel0, sampleUV);
		toColor += texture(iChannel1, sampleUV);
	}

	float sampleCount = float(tapCount + 1);
	fromColor /= sampleCount;
	toColor /= sampleCount;

	fragColor = mixTransitionColors(fromColor, toColor, progress);
}