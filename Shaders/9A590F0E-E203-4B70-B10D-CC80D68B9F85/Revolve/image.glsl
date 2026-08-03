// SPDX-FileCopyrightText: bread
// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template transition

// #motionblur off

// #point label="Center" group={"Transform", "move.3d"} osc=position default="0.46,0.52"
uniform vec2 uCenter;

// #choice label="Direction" group={"Motion", "rotate.3d"} options="Clockwise,Counterclockwise" default=0
uniform int uDirection;

// #angle label="Rotation" group="Motion" default=112
uniform float uRotation;

// #angle label="Core Swirl" group="Motion" default=163
uniform float uSwirl;

// #percent label="Peak Zoom" group="Motion" min=100 max=400 default=222
uniform float uPeakZoom;

// #percent label="Barrel" group="Motion" min=0 max=150 default=38
uniform float uBarrel;

// #percent label="Motion Blur" group="Motion" min=0 max=100 default=100
uniform float uMotionBlur;

// #multi label="Switch" group={"Timing", "clock"} fields={Start,End} percent min=0 max=100 default="30,50"
uniform vec2 uSwitch;

// #percent label="Edge Shadow" group={"Finish", "circle.lefthalf.filled"} min=0 max=100 default=16
uniform float uShadow;

float sat(float value)
{
	return clamp(value, 0.0, 1.0);
}

float ease(float value)
{
	value = sat(value);
	return value * value * (3.0 - 2.0 * value);
}

float revolveEnvelope(float time)
{
	float rise = ease((time - 0.10) / 0.33);
	float fall = 1.0 - ease((time - 0.43) / 0.29);
	return rise * fall;
}

vec2 rotate2(vec2 position, float angle)
{
	float sine = sin(angle);
	float cosine = cos(angle);
	return vec2(cosine * position.x - sine * position.y, sine * position.x + cosine * position.y);
}

vec2 warpUV(vec2 uv, float time)
{
	float envelope = revolveEnvelope(time);
	float aspect = iResolution.x / iResolution.y;
	float direction = uDirection == 0 ? -1.0 : 1.0;
	vec2 center = uCenter / iResolution.xy;

	vec2 position = uv - center;
	position.x *= aspect;

	float radius = length(position);
	float edgeSpin = abs(uRotation) * envelope;
	float coreSpin = abs(uSwirl) * envelope * pow(1.0 - sat(radius / 0.96), 1.55);
	float visibleAngle = direction * (edgeSpin + coreSpin);

	position = rotate2(position, -visibleAngle);

	float scale = 1.0 + (uPeakZoom - 1.0) * pow(envelope, 0.85);
	position /= scale;

	float warpedRadius = length(position);
	position *= 1.0 + uBarrel * envelope * warpedRadius * warpedRadius * 2.8;

	position.x /= aspect;
	return clamp(position + center, vec2(0.001), vec2(0.999));
}

vec4 sampleRevolve(vec2 uv, float time)
{
	vec2 warpedUV = warpUV(uv, time);
	float switchStart = min(uSwitch.x, uSwitch.y);
	float switchEnd = max(uSwitch.x, uSwitch.y);
	float reveal = smoothstep(switchStart, max(switchEnd, switchStart + 0.001), time);
	return mixTransitionColors(texture(iChannel0, warpedUV), texture(iChannel1, warpedUV), reveal);
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

	float envelope = revolveEnvelope(progress);
	float span = 0.060 * uMotionBlur * envelope;
	vec4 color = vec4(0.0);
	float totalWeight = 0.0;

	for (int i = -8; i <= 8; ++i)
	{
		float offset = float(i) / 8.0;
		float weight = 1.0 - abs(offset);
		weight = weight * weight + 0.01;

		float sampleTime = sat(progress + offset * span);
		color += sampleRevolve(uv, sampleTime) * weight;
		totalWeight += weight;
	}

	color /= totalWeight;

	vec2 centeredUV = uv - 0.5;
	centeredUV.x *= iResolution.x / iResolution.y;
	float vignette = 1.0 - uShadow * envelope * smoothstep(0.35, 0.95, length(centeredUV));
	color.rgb *= vignette;

	fragColor = color;
}