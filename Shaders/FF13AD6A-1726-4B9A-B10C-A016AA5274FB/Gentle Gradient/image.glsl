// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template generator

// #speed group={"Motion", "wind"}
// #seed group="Motion"
// #grain label="Grain" group={"Finish", "camera.filters"} default=0 size=2

// A two-axis bilinear corner mix despite the name, not a 1-D ramp. A ramp
// (#gradient) can express one axis, so the second corner pair would be lost.
// #color label="Colours" min=2 max=3 default="#8C00FF,#FF0080,#00FFFF"
uniform vec4 uColours[3];

// #percent label="Swirl" group={"Pattern", "circle.hexagongrid"} min=0 max=200 default=100
uniform float uSwirl;

// #percent label="Gloss" group={"Appearance", "sparkles"} min=0 max=200 default=100
uniform float uGloss;

// #point label="Center" group={"Transform", "viewfinder"} osc=position default="0.5,0.5"
uniform vec2 uCenter;

// #percent label="Scale" group="Transform" min=25 max=400 default=100 osc=ring link=uCenter
uniform float uScale;

vec2 swirlField(vec2 position, float time, float amount)
{
	float angle =
	    sin(position.x * 2.0 + time) +
	    cos(position.y * 2.3 - time * 0.7);

	angle *= amount * 0.6;

	float cosine = cos(angle);
	float sine = sin(angle);

	return mat2(cosine, -sine, sine, cosine) * position;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 position = (fragCoord - uCenter) / iResolution.y;
	position /= max(uScale, 0.01);

	float time = iTime * 0.5;
	vec2 swirled = swirlField(position, time, uSwirl);
	vec2 gradientPosition = swirled * 0.5 + 0.5;

	int colorCount = max(uColoursCount, 1);

	vec3 color0 = uColours[0].rgb;
	vec3 color1 = uColours[min(1, colorCount - 1)].rgb;
	vec3 color2 = uColours[min(2, colorCount - 1)].rgb;

	vec3 color = mix(
	                 color0,
	                 color1,
	                 clamp(gradientPosition.x, 0.0, 1.0)
	             );

	color = mix(
	            color,
	            color2,
	            clamp(gradientPosition.y, 0.0, 1.0)
	        );

	vec3 gloss = vec3(0.85) + color * 0.35;
	color *= mix(vec3(1.0), gloss, uGloss);
	color = clamp(color, 0.0, 1.0);

	fragColor = vec4(color, 1.0);
}