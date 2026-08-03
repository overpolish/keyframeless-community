// SPDX-FileCopyrightText: martiniti
// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template transition

// #choice label="Mode" group={"Wipe", "rotate.3d"} options="Open,Close" default=0
uniform int uMode;

// #point label="Center" group="Wipe" osc=position default="0.5,0.5"
uniform vec2 uCenter;

// #angle label="Rotation" group="Wipe" osc={z} link=uCenter default=0
uniform float uRotation;

// #percent label="Feather" group="Wipe" min=0 max=200 default=100
uniform float uFeather;

float openingMask(float coordinate, float progress)
{
	if (progress <= 0.0)
		return 0.0;

	float regress = 1.0 - progress;
	float shape = 2.0 - abs(coordinate) / max(progress, 0.0001) - 2.0 * regress;

	if (uFeather <= 0.0001)
		return step(0.0, shape);

	return smoothstep(0.0, 0.5 * uFeather, shape);
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

	float aspect = iResolution.x / iResolution.y;
	vec2 center = uCenter / iResolution.xy;
	vec2 position = (uv - center) * vec2(aspect, 1.0);
	vec2 axis = vec2(sin(uRotation), cos(uRotation));

	float halfExtent = 0.5 * (aspect * abs(axis.x) + abs(axis.y));
	float coordinate = dot(position, axis) * 0.5 / max(halfExtent, 0.0001);

	float reveal;

	if (uMode == 0)
		reveal = openingMask(coordinate, progress);
	else
		reveal = 1.0 - openingMask(coordinate, 1.0 - progress);

	fragColor = mixTransitionColors(fromColor, toColor, reveal);
}