// SPDX-FileCopyrightText: Tianshuo
// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template transition

// #point label="Center" group={"Motion", "arrow.up.left.and.arrow.down.right"} osc=position default="0.5,0.5"
uniform vec2 uCenter;

// #choice label="Direction" group="Motion" options="Zoom Out,Zoom In" default=0
uniform int uDirection;

// #percent label="Zoom Amount" group="Motion" min=0 max=100 default=100
uniform float uZoomAmount;

// #percent label="Motion Duration" group={"Timing", "clock"} min=20 max=100 default=80
uniform float uDuration;

// #choice label="Blend" group="Timing" options="Fade,Cut" default=0
uniform int uBlend;

float sat(float value)
{
	return clamp(value, 0.0, 1.0);
}

// The zoom eases inside its own Duration window rather than across the sweep, so
// it settles rather than stopping dead. The Progress lane shapes the whole
// transition and cannot reach inside that window, so this curve stays baked in.
float shapeProgress(float progress)
{
	return progress * progress * (3.0 - 2.0 * progress);
}

vec2 zoomUV(vec2 uv, vec2 center, float scale)
{
	return center + (uv - center) * scale;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;
	vec2 center = uCenter / iResolution.xy;
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

	float duration = max(uDuration, 0.001);
	float motionStart = 1.0 - duration;
	float localProgress = sat((progress - motionStart) / duration);
	float motionProgress = shapeProgress(localProgress);
	float minimumScale = 1.0 - uZoomAmount;

	if (uDirection == 0)
	{
		float scale = mix(minimumScale, 1.0, motionProgress);
		vec4 zoomedTo = texture(iChannel1, zoomUV(uv, center, scale));
		float blend = uBlend == 0 ? motionProgress : step(0.0001, localProgress);
		fragColor = mixTransitionColors(fromColor, zoomedTo, blend);
	}
	else
	{
		float scale = mix(1.0, minimumScale, motionProgress);
		vec4 zoomedFrom = texture(iChannel0, zoomUV(uv, center, scale));
		float blend = uBlend == 0 ? motionProgress : step(0.9999, localProgress);
		fragColor = mixTransitionColors(zoomedFrom, toColor, blend);
	}
}