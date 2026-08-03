// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template layout

// #alpha
// #motionblur on

// #choice label="Direction" group={"Motion", "wind"} options="Left,Right,Up,Down" default=0
uniform int uDirection;

// #float label="Rate" group="Motion" units="/s" min=0 max=2 slidermax=0.5 default=0.1
uniform float uRate;

// #percent label="Offset" group="Motion" min=-100 max=100 default=0
uniform float uOffset;

// #percent label="Gap" group={"Tiling", "square.grid.3x3"} min=0 max=200 default=0
uniform float uGap;

const int DIRECTION_LEFT = 0;
const int DIRECTION_RIGHT = 1;
const int DIRECTION_UP = 2;

vec2 scrollDirection()
{
	if (uDirection == DIRECTION_LEFT)
		return vec2(-1.0, 0.0);

	if (uDirection == DIRECTION_RIGHT)
		return vec2(1.0, 0.0);

	if (uDirection == DIRECTION_UP)
		return vec2(0.0, 1.0);

	return vec2(0.0, -1.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;

	vec2 direction = scrollDirection();
	vec2 axis = abs(direction);

	float period = 1.0 + uGap;
	float phase = iTime * uRate + uOffset;

	float travel = dot(uv, axis) - dot(direction, axis) * phase;
	float tileCoordinate = fract(travel / period) * period;

	if (tileCoordinate > 1.0)
	{
		fragColor = vec4(0.0);
		return;
	}

	vec4 source = texture(iChannel0, mix(uv, vec2(tileCoordinate), axis));

	// iChannel0 arrives premultiplied and #alpha premultiplies again on output,
	// so the source has to be divided out here. Returning it verbatim squares
	// the alpha and crushes the soft edges of a title, a graphic, a keyed clip,
	// or another layout instance stacked underneath.
	fragColor = source.a > 1e-4
	            ? vec4(source.rgb / source.a, source.a)
	            : vec4(0.0);
}
