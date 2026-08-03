// SPDX-FileCopyrightText: Eke Péter <peterekepeter@gmail.com>
// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template transition

// #point label="Center" group={"Wipe", "rotate.3d"} osc=position default="0.5,0.5"
uniform vec2 uCenter;

// #angle label="Rotation" group="Wipe" osc={z} link=uCenter default=0
uniform float uRotation;

// #choice label="Direction" group="Wipe" options="Forward,Reverse" default=0
uniform int uDirection;

// #percent label="Width" group="Wipe" min=0 max=200 default=100
uniform float uWidth;

// #percent label="Zoom Amount" group={"Zoom", "arrow.up.left.and.arrow.down.right"} min=0 max=100 default=100
uniform float uZoomAmount;

// #choice label="Zoom Clips" group="Zoom" options="Both,Outgoing,Incoming" default=0
uniform int uZoomClips;

float wipeCoordinate(vec2 uv)
{
	float aspect = iResolution.x / iResolution.y;
	vec2 center = uCenter / iResolution.xy;
	vec2 position = (uv - center) * vec2(aspect, 1.0);
	vec2 axis = vec2(cos(uRotation), sin(uRotation));
	float halfExtent = 0.5 * (aspect * abs(axis.x) + abs(axis.y));
	float coordinate = 0.5 + dot(position, axis) / max(2.0 * halfExtent, 0.0001);

	if (uDirection == 1)
		coordinate = 1.0 - coordinate;

	return coordinate;
}

float wipeReveal(float progress, float coordinate)
{
	float position = progress * 2.0 + coordinate - 1.0;

	if (uWidth <= 0.0001)
		return step(0.5, position);

	float halfWidth = 0.5 * uWidth;
	return smoothstep(0.5 - halfWidth, 0.5 + halfWidth, position);
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

	float reveal = wipeReveal(progress, wipeCoordinate(uv));

	bool zoomOutgoing = uZoomClips == 0 || uZoomClips == 1;
	bool zoomIncoming = uZoomClips == 0 || uZoomClips == 2;

	float fromScale = zoomOutgoing ? 1.0 - uZoomAmount * reveal : 1.0;
	float toScale = zoomIncoming ? 1.0 - uZoomAmount * (1.0 - reveal) : 1.0;

	vec2 fromUV = zoomUV(uv, center, fromScale);
	vec2 toUV = zoomUV(uv, center, toScale);

	vec4 fromColor = texture(iChannel0, clamp(fromUV, 0.0, 1.0));
	vec4 toColor = texture(iChannel1, clamp(toUV, 0.0, 1.0));

	fragColor = mixTransitionColors(fromColor, toColor, reveal);
}