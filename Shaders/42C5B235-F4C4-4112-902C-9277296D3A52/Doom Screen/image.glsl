// SPDX-FileCopyrightText: Zeh Fernando
// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template transition

// #choice label="Mode" group={"Bars", "square.grid.3x3"} options="Slide Out,Slide In" default=0
uniform int uMode;

// #choice label="Direction" group="Bars" options="Down,Up,Left,Right" default=0
uniform int uDirection;

// #int label="Bar Count" group="Bars" min=2 max=200 default=30
uniform float uBars;

// #float label="Speed Variation" group="Bars" min=0 max=8 default=2
uniform float uAmplitude;

// #percent label="Randomness" group="Bars" min=0 max=100 default=10
uniform float uNoise;

// #float label="Wave Frequency" group="Bars" min=0 max=5 default=0.5
uniform float uFrequency;

// #percent label="Drip" group="Bars" min=0 max=200 default=50
uniform float uDripScale;

// #choice label="Drip Shape" group="Bars" options="Middle,Edges" default=0
uniform int uDripShape;

// #random label="Seed" group="Bars" default=0
uniform float uSeed;

// #percent label="Feather" group={"Edges", "sparkles"} min=0 max=20 default=0
uniform float uFeather;

float barRandom(int index)
{
	float value = float(index) + uSeed;
	return fract(mod(value * 67123.313, 12.0) * sin(value * 10.3) * cos(value));
}

float barWave(int index, int count)
{
	float frequency = float(index) * uFrequency * 0.1 * float(count);
	return cos(frequency * 0.5) * cos(frequency * 0.13) * sin((frequency + 10.0) * 0.3) * 0.5 + 0.5;
}

float barDrip(int index, int count)
{
	float position = float(index) / max(float(count - 1), 1.0);
	float middle = sin(position * 3.14159265);

	if (uDripShape == 1)
		middle = 1.0 - middle;

	return middle * uDripScale;
}

float barPosition(int index, int count)
{
	float wave = barWave(index, count);
	float variation = mix(wave, barRandom(index), uNoise);
	return variation + barDrip(index, count);
}

vec2 movementAxis()
{
	if (uDirection == 1)
		return vec2(0.0, -1.0);

	if (uDirection == 2)
		return vec2(1.0, 0.0);

	if (uDirection == 3)
		return vec2(-1.0, 0.0);

	return vec2(0.0, 1.0);
}

float boundaryDistance(vec2 uv, vec2 sampleDirection)
{
	if (sampleDirection.x > 0.5)
		return 1.0 - uv.x;

	if (sampleDirection.x < -0.5)
		return uv.x;

	if (sampleDirection.y > 0.5)
		return 1.0 - uv.y;

	return uv.y;
}

float insideMask(float distance)
{
	if (uFeather <= 0.0001)
		return step(0.0, distance);

	return smoothstep(-uFeather, uFeather, distance);
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

	int barCount = max(int(uBars), 2);
	bool vertical = uDirection < 2;
	float barCoordinate = vertical ? uv.x : uv.y;
	int bar = clamp(int(floor(barCoordinate * float(barCount))), 0, barCount - 1);

	float speed = 1.0 + barPosition(bar, barCount) * uAmplitude;
	float phase = progress * speed;
	vec2 axis = movementAxis();

	if (uMode == 0)
	{
		vec2 sampleUV = uv + axis * phase;
		float inside = insideMask(boundaryDistance(sampleUV, axis));
		vec4 movingFrom = texture(iChannel0, clamp(sampleUV, 0.0, 1.0));
		fragColor = mixTransitionColors(toColor, movingFrom, inside);
	}
	else
	{
		float remaining = 1.0 - clamp(phase, 0.0, 1.0);
		vec2 sampleDirection = -axis;
		vec2 sampleUV = uv + sampleDirection * remaining;
		float inside = insideMask(boundaryDistance(sampleUV, sampleDirection));
		vec4 movingTo = texture(iChannel1, clamp(sampleUV, 0.0, 1.0));
		fragColor = mixTransitionColors(fromColor, movingTo, inside);
	}
}