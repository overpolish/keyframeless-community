// SPDX-FileCopyrightText: 2024 Giorgi Azmaipharashvili
// SPDX-License-Identifier: MIT

// #template generator
//
// Derived from a silk-fabric shader by Giorgi Azmaipharashvili.

// #speed group={"Motion", "wind"}
// #seed group="Motion"

// #grain label="Grain" group={"Finish", "camera.filters"} default=0 size=2

// #color label="Colours" min=2 max=2 default="#1B1533,#E8DEFF"
uniform vec4 uColours[2];

// #bool label="Invert" group={"Appearance", "circle.lefthalf.filled"} default=true
uniform bool uInvert;

// #percent label="Sheen" group="Appearance" min=0 max=200 default=70
uniform float uSheen;

// #percent label="Weave" group={"Fabric", "square.grid.3x3.fill"} min=0 max=200 default=100
uniform float uWeave;

// #percent label="Ripple" group="Fabric" min=0 max=200 default=100
uniform float uRipple;

// #point label="Center" group={"Transform", "viewfinder"} osc=position default="0.5,0.5"
uniform vec2 uCenter;

// #percent label="Scale" group="Transform" min=25 max=400 default=100 osc=ring link=uCenter
uniform float uScale;

float weaveNoise(vec2 position)
{
	float diagonal = sin((position.x - position.y) * 555.0);
	float vertical = sin(position.y * 1444.0);
	return smoothstep(-0.5, 0.9, diagonal * vertical) - 0.4;
}

float fabricTexture(vec2 position)
{
	const mat2 transform = mat2(1.6, 1.2, -1.2, 1.6);

	float textureValue = weaveNoise(position) * 0.4;
	position = transform * position;
	textureValue += weaveNoise(position) * 0.3;
	position = transform * position;
	textureValue += weaveNoise(position) * 0.2;
	position = transform * position;
	textureValue += weaveNoise(position) * 0.1;

	return textureValue;
}

float silkSurface(vec2 position)
{
	float diagonal = position.x + position.y;

	float wave = sin(
	                 5.0 * (
	                     diagonal +
	                     cos(2.0 * position.x + 5.0 * position.y)
	                 ) +
	                 sin(12.0 * diagonal) -
	                 iTime
	             );

	float surface = 0.7 + 0.3 * (wave * wave * 0.5 + wave);

	float weave = fabricTexture(
	                  position *
	                  min(iResolution.x, iResolution.y) *
	                  0.0006
	              );

	surface *= 0.9 + 0.6 * uWeave * weave;
	return surface * 0.9 + 0.1;
}

float silkDerivative(vec2 position)
{
	float diagonal = position.x + position.y;

	float derivative =
	    (
	        5.0 * (
	            1.0 -
	            2.0 * sin(
	                2.0 * position.x +
	                5.0 * position.y
	            )
	        ) +
	        12.0 * cos(12.0 * diagonal)
	    ) *
	    cos(
	        5.0 * (
	            cos(
	                2.0 * position.x +
	                5.0 * position.y
	            ) +
	            diagonal
	        ) +
	        sin(12.0 * diagonal) -
	        iTime
	    );

	return derivative * (sign(derivative) + 3.0) * 0.005;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	float minSide = min(iResolution.x, iResolution.y);
	vec2 frameCenter = iResolution.xy * (0.5 / minSide);

	vec2 position = (fragCoord - uCenter) / minSide;
	position /= max(uScale, 0.001);
	position += frameCenter;

	position.y +=
	    sin(position.x * 8.0 - iTime) *
	    uRipple *
	    0.03;

	float surface = sqrt(max(silkSurface(position), 0.0));
	float derivative = silkDerivative(position);

	vec3 luminanceColor = vec3(surface);
	luminanceColor +=
	    vec3(1.0, 0.83, 0.6) *
	    derivative *
	    uSheen *
	    0.7;

	luminanceColor *= 1.0 - max(derivative * 0.8, 0.0);
	luminanceColor = max(luminanceColor, vec3(0.0));

	if (uInvert)
	{
		luminanceColor = pow(
		                     luminanceColor,
		                     0.3 / vec3(0.52, 0.5, 0.4)
		                 );

		luminanceColor = 1.0 - luminanceColor;
	}
	else
	{
		luminanceColor = pow(
		                     luminanceColor,
		                     vec3(0.52, 0.5, 0.4)
		                 );
	}

	float luminance = clamp(
	                      dot(
	                          luminanceColor,
	                          vec3(0.299, 0.587, 0.114)
	                      ),
	                      0.0,
	                      1.0
	                  );

	vec3 color = mix(
	                 uColours[0].rgb,
	                 uColours[1].rgb,
	                 luminance
	             );

	fragColor = vec4(color, 1.0);
}