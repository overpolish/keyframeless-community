// SPDX-FileCopyrightText: chenkai
// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template transition
//
// Derived from https://codertw.com/%E7%A8%8B%E5%BC%8F%E8%AA%9E%E8%A8%80/671116/

// #motionblur off

// #point label="Hinge" group={"Rotation", "rotate.3d"} osc=position default="1.0,0.0"
uniform vec2 uAnchor;

// #choice label="Direction" group="Rotation" options="Clockwise,Counterclockwise" default=0
uniform int uDirection;

// #angle label="Rotation" group="Rotation" osc={z} link=uAnchor default=180
uniform float uRotation;

// #choice label="Edges" group="Rotation" options="Repeat,Mirror,Clamp" default=0
uniform int uEdges;

// #percent label="Switch Point" group={"Timing", "clock"} min=10 max=90 default=50
uniform float uSwitchPoint;

// #percent label="Crossfade" group="Timing" min=0 max=30 default=0
uniform float uCrossfade;

// #percent label="Motion Blur" group={"Motion Blur", "wind"} min=0 max=200 default=100
uniform float uMotionBlur;

// #choice label="Quality" group="Motion Blur" options="Draft,Standard,High" default=2
uniform int uQuality;

float randomValue(vec2 position)
{
	return fract(sin(dot(position, vec2(12.9898, 78.233))) * 43758.5453);
}

float bezierA(float first, float second)
{
	return 1.0 - 3.0 * second + 3.0 * first;
}

float bezierB(float first, float second)
{
	return 3.0 * second - 6.0 * first;
}

float bezierC(float first)
{
	return 3.0 * first;
}

float bezierSlope(float time, float first, float second)
{
	return 3.0 * bezierA(first, second) * time * time + 2.0 * bezierB(first, second) * time + bezierC(first);
}

float calculateBezier(float time, float first, float second)
{
	return ((bezierA(first, second) * time + bezierB(first, second)) * time + bezierC(first)) * time;
}

float solveBezierTime(float value, float first, float second)
{
	float guess = value;

	for (int i = 0; i < 4; ++i)
	{
		float slope = bezierSlope(guess, first, second);

		if (abs(slope) < 0.00001)
			break;

		guess -= (calculateBezier(guess, first, second) - value) / slope;
	}

	return guess;
}

float keySpline(float value, float x1, float y1, float x2, float y2)
{
	if (x1 == y1 && x2 == y2)
		return value;

	return calculateBezier(solveBezierTime(value, x1, x2), y1, y2);
}

// The spin's signature curve, kept as authored. A near-linear middle with a
// long settle is what stops a full rotation from looking mechanical, and the
// control points are the measured ones - do not round them.
float spinCurve(float progress)
{
	return keySpline(progress, 0.68, 0.01, 0.17, 0.98);
}

vec2 resolveUV(vec2 uv)
{
	if (uEdges == 1)
		return 1.0 - abs(mod(uv, 2.0) - 1.0);

	if (uEdges == 2)
		return clamp(uv, 0.0, 1.0);

	return fract(uv);
}

vec4 sampleChannel(vec2 uv, int channel)
{
	vec2 sampleUV = resolveUV(uv);

	if (channel == 0)
		return texture(iChannel0, sampleUV);

	return texture(iChannel1, sampleUV);
}

vec2 rotateUV(vec2 uv, float angle)
{
	float aspect = iResolution.x / iResolution.y;
	vec2 anchor = uAnchor / iResolution.xy;

	uv.y /= aspect;
	anchor.y /= aspect;

	uv -= anchor;

	float sine = sin(angle);
	float cosine = cos(angle);
	uv = mat2(cosine, -sine, sine, cosine) * uv;

	uv += anchor;
	uv.y *= aspect;

	return uv;
}

float rotationAtTime(float time, int channel)
{
	float switchPoint = clamp(uSwitchPoint, 0.001, 0.999);
	float direction = uDirection == 0 ? 1.0 : -1.0;
	float halfRotation = abs(uRotation) * 0.5;

	if (channel == 0)
		return direction * halfRotation * time / switchPoint;

	return direction * halfRotation * ((time - switchPoint) / (1.0 - switchPoint) - 1.0);
}

vec4 motionBlurSample(vec2 uv, vec2 speed, int channel)
{
	if (uMotionBlur <= 0.0001)
		return sampleChannel(uv, channel);

	int sampleCount = 21;

	if (uQuality == 0)
		sampleCount = 7;
	else if (uQuality == 1)
		sampleCount = 13;

	float denominator = float(sampleCount - 1);
	float offset = randomValue(uv);
	vec4 color = vec4(0.0);
	float totalWeight = 0.0;

	for (int i = 0; i < 21; ++i)
	{
		if (i >= sampleCount)
			break;

		float percent = (float(i) + offset) / denominator;
		float weight = 4.0 * (percent - percent * percent);
		color += sampleChannel(uv + speed * percent, channel) * weight;
		totalWeight += weight;
	}

	return color / max(totalWeight, 0.0001);
}

vec4 rotatingFrame(vec2 uv, float time, int channel)
{
	const float timeInterval = 0.0334;

	float currentRotation = rotationAtTime(time, channel);
	float nextRotation = rotationAtTime(time + timeInterval, channel);

	vec2 currentUV = rotateUV(uv, currentRotation);
	vec2 nextUV = rotateUV(uv, nextRotation);

	float blurEnvelope = exp(-20.0 * (time - 0.5) * (time - 0.5));
	vec2 speed = (nextUV - currentUV) / timeInterval;
	speed *= blurEnvelope * 0.5 * uMotionBlur;

	return motionBlurSample(currentUV, speed, channel);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;
	float rampProgress = clamp(iProgress, 0.0, 1.0);

	if (rampProgress <= 0.0)
	{
		fragColor = texture(iChannel0, uv);
		return;
	}

	if (rampProgress >= 1.0)
	{
		fragColor = texture(iChannel1, uv);
		return;
	}

	float progress = clamp(spinCurve(rampProgress), 0.0, 1.0);
	float switchPoint = clamp(uSwitchPoint, 0.001, 0.999);

	if (uCrossfade <= 0.0001)
	{
		int channel = progress <= switchPoint ? 0 : 1;
		fragColor = rotatingFrame(uv, progress, channel);
		return;
	}

	float halfCrossfade = uCrossfade * 0.5;
	float blend = smoothstep(switchPoint - halfCrossfade, switchPoint + halfCrossfade, progress);

	vec4 fromColor = rotatingFrame(uv, progress, 0);
	vec4 toColor = rotatingFrame(uv, progress, 1);
	fragColor = mixTransitionColors(fromColor, toColor, blend);
}