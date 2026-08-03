// SPDX-FileCopyrightText: Yoni Maltsman (@friendlyspinach)
// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template transition

// #multi label="Amplitude" group={"Spiral", "tornado"} fields={X,Y} percent min=0 max=300 default="100,100"
uniform vec2 uAmplitude;

// #float label="Tightness" group="Spiral" min=0.1 max=5 default=1
uniform float uTightness;

// #percent label="Strength" group="Spiral" min=0 max=200 default=100
uniform float uStrength;

// #percent label="Colour Influence" group="Spiral" min=0 max=200 default=100
uniform float uColorInfluence;

// #choice label="Direction" group="Spiral" options="Forward,Reverse" default=0
uniform int uDirection;

// #choice label="Wrapping" group="Spiral" options="Repeat,Mirror,Clamp" default=0
uniform int uWrapping;

float wrapCoordinate(float value)
{
	if (uWrapping == 1)
		return 1.0 - abs(mod(value, 2.0) - 1.0);

	if (uWrapping == 2)
		return clamp(value, 0.0, 1.0);

	return fract(value);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;
	float progress = clamp(iProgress, 0.0, 1.0);

	vec4 fromColor = texture(iChannel0, uv);
	vec4 toColor = texture(iChannel1, uv);

	if (progress <= 0.0)
	{
		fragColor = fromColor;
		return;
	}

	if (progress >= 1.0)
	{
		fragColor = toColor;
		return;
	}

	float sphere = (dot(fromColor.rgb, fromColor.rgb) - 1.0) * uColorInfluence;
	float direction = uDirection == 0 ? 1.0 : -1.0;
	float denominator = progress + 0.01;

	float spiralX = cos(sphere - direction * uv.x * uTightness / denominator);
	float spiralY = sin(sphere - direction * uv.y * uTightness / denominator);

	vec2 warpedUV;
	warpedUV.x = wrapCoordinate(uAmplitude.x * uv.x * spiralX);
	warpedUV.y = wrapCoordinate(uAmplitude.y * uv.y * spiralY);

	vec2 difference = uv - warpedUV;
	vec2 sampleUV = clamp(uv + progress * uStrength * difference, 0.0, 1.0);
	vec4 distortedFrom = texture(iChannel0, sampleUV);

	fragColor = mixTransitionColors(distortedFrom, toColor, progress);
}