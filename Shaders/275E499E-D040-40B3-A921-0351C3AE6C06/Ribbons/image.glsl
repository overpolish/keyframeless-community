// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template generator

// #speed group={"Motion", "wind"}
// #seed group="Motion"

// #grain label="Grain" group={"Finish", "camera.filters"} default=0 size=2

// #color label="Colours" min=2 max=8 default="#2A1B4A,#7A3FA0,#F26D9C,#FFD166"
uniform vec4 uColours[8];

// #int label="Bands" group={"Pattern", "line.3.horizontal"} min=2 max=16 default=6
uniform float uBands;

// #percent label="Ripple" group="Pattern" min=0 max=200 default=100
uniform float uRipple;

// #point label="Center" group={"Transform", "arrow.up.right"} osc=position default="0.5,0.5"
uniform vec2 uCenter;

// #angle label="Direction" group="Transform" default=225 osc={z} link=uCenter
uniform float uAngle;

// #percent label="Scale" group="Transform" min=25 max=400 default=100 osc=ring link=uCenter
uniform float uScale;

vec3 palette(float position)
{
	int count = max(uColoursCount, 1);

	if (count == 1)
		return uColours[0].rgb;

	float paletteIndex = clamp(position, 0.0, 1.0) * float(count - 1);
	int lower = int(floor(paletteIndex));
	int upper = min(lower + 1, count - 1);

	return mix(uColours[lower].rgb, uColours[upper].rgb, fract(paletteIndex));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 position = (fragCoord - uCenter) / iResolution.y;
	position /= max(uScale, 0.001);

	float time = iTime * 0.3;
	vec2 direction = vec2(cos(uAngle), sin(uAngle));
	float flow = dot(position, direction) * 3.0 + time;

	float horizontalRipple =
	    sin(position.x * 12.0 + time * 1.5) *
	    cos(position.y * 8.0 + time * 2.0) *
	    0.3;

	float verticalRipple =
	    cos(position.y * 10.0 - time * 1.2) *
	    sin(position.x * 7.0 + time * 0.8) *
	    0.4;

	float ramp = fract(
	                 flow +
	                 (horizontalRipple + verticalRipple) * uRipple * 0.5
	             );

	float bandCount = max(floor(uBands), 2.0);
	float stepped = floor(ramp * bandCount) / (bandCount - 1.0);
	vec3 color = palette(stepped);

	fragColor = vec4(color, 1.0);
}