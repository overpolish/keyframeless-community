// SPDX-FileCopyrightText: The paper-design/shaders authors
// SPDX-License-Identifier: Apache-2.0

// #template generator
// SPDX-FileContributor: Modified by overpolish in 2026

// Derived from https://github.com/paper-design/shaders

// #speed group={"Motion", "wind"}
// #seed group="Motion"
// #grain label="Grain" group={"Finish", "camera.filters"} default=0 size=2

// One swatch per ray layer, composited with its own alpha. Not a #gradient:
// a ramp carries no per-stop alpha to composite with.
// #color label="Ray Colours" min=1 max=5 default="#FFE9A8,#FFC46B,#FF9E5E"
uniform vec4 uColours[5];

// #color label="Background" default="#0A0A14"
uniform vec4 uColorBack;

// #color label="Bloom Colour" default="#FFF3C0"
uniform vec4 uColorBloom;

// #percent label="Spotty" group={"Rays", "sun.max"} min=0 max=200 default=30
uniform float uSpotty;

// #percent label="Intensity" group="Rays" min=0 max=100 default=60
uniform float uIntensity;

// #percent label="Density" group="Rays" min=0 max=200 default=50
uniform float uDensity;

// #percent label="Bloom" group={"Glow", "sparkles"} min=0 max=100 default=40
uniform float uBloom;

// #percent label="Center Size" group="Glow" min=0 max=100 default=40
uniform float uMidSize;

// #percent label="Center Intensity" group="Glow" min=0 max=100 default=60
uniform float uMidIntensity;

// #point label="Center" group={"Transform", "viewfinder"} osc=position default="0.5,1.0"
uniform vec2 uCenter;

// #percent label="Scale" group="Transform" min=25 max=400 default=100 osc=ring link=uCenter
uniform float uScale;

const float TAU = 6.28318530718;

float hash11(float value)
{
	value = fract(value * 0.1031);
	value *= value + 33.33;
	value *= value + value;

	return fract(value);
}

float hash21(vec2 value)
{
	value = fract(value * vec2(0.3183099, 0.3678794)) + 0.1;
	value += dot(value, value + 19.19);

	return fract(value.x * value.y);
}

vec2 rotate2D(vec2 value, float angle)
{
	float sine = sin(angle);
	float cosine = cos(angle);

	return vec2(
	           cosine * value.x + sine * value.y,
	           -sine * value.x + cosine * value.y
	       );
}

float valueNoise(vec2 position)
{
	vec2 cell = floor(position);
	vec2 local = fract(position);
	vec2 blend = local * local * (3.0 - 2.0 * local);

	float bottomLeft = hash21(cell);
	float bottomRight = hash21(cell + vec2(1.0, 0.0));
	float topLeft = hash21(cell + vec2(0.0, 1.0));
	float topRight = hash21(cell + vec2(1.0, 1.0));

	return mix(
	           mix(bottomLeft, bottomRight, blend.x),
	           mix(topLeft, topRight, blend.x),
	           blend.y
	       );
}

float rayShape(vec2 position, float radius, float frequency, float intensity)
{
	float angle = atan(position.y, position.x);

	vec2 leftPosition = vec2(angle * frequency, radius);
	vec2 rightPosition = vec2(
	                         fract(angle / TAU) * TAU * frequency,
	                         radius
	                     );

	float leftNoise = pow(valueNoise(leftPosition), intensity);
	float rightNoise = pow(valueNoise(rightPosition), intensity);
	float seamBlend = smoothstep(-0.15, 0.15, position.x);

	return mix(rightNoise, leftNoise, seamBlend);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 position = (fragCoord - uCenter) / iResolution.y;
	position /= max(uScale, 0.01);

	float time = iTime * 0.2;
	float radius = length(position);
	float spots = 6.5 * uSpotty;
	float intensity = 4.0 - 3.0 * clamp(uIntensity, 0.0, 1.0);

	float centerSize = 10.0 * uMidSize;
	float centerStart = centerSize * 0.02;
	float centerEnd = max(centerSize, 0.000001);

	float centerShape =
	    pow(uMidIntensity, 0.3) *
	    (
	        1.0 -
	        smoothstep(
	            centerStart,
	            centerEnd,
	            radius * 3.0
	        )
	    );

	centerShape = pow(centerShape, 5.0);

	float density =
	    6.0 * uDensity +
	    step(0.5, uDensity) *
	    pow(4.5 * (uDensity - 0.5), 4.0);

	vec3 accumulatedColor = vec3(0.0);
	float accumulatedAlpha = 0.0;

	for (int i = 0; i < 5; ++i)
	{
		if (i >= uColoursCount)
			break;

		float index = float(i);
		vec2 rotated = rotate2D(position, index + 1.0);

		float primaryRadius =
		    radius *
		    (1.0 + index * 0.4) -
		    time * 3.0;

		float secondaryRadius =
		    radius *
		    0.5 *
		    (1.0 + spots) -
		    time * 2.0;

		float frequency =
		    mix(
		        1.0,
		        3.0 + index * 0.5,
		        hash11(index * 15.0)
		    ) *
		    density;

		float ray = rayShape(
		                rotated,
		                primaryRadius,
		                frequency * 5.0,
		                intensity
		            );

		ray *= rayShape(
		           rotated,
		           secondaryRadius,
		           frequency * 4.0,
		           intensity
		       );

		ray += (1.0 + 4.0 * ray) * centerShape;
		ray = clamp(ray, 0.0, 1.0);

		float sourceAlpha = uColours[i].a * ray;
		vec3 sourceColor = uColours[i].rgb * sourceAlpha;

		vec3 alphaBlendColor =
		    accumulatedColor +
		    (1.0 - accumulatedAlpha) *
		    sourceColor;

		float alphaBlendAlpha =
		    accumulatedAlpha +
		    (1.0 - accumulatedAlpha) *
		    sourceAlpha;

		vec3 additiveColor = accumulatedColor + sourceColor;
		float additiveAlpha = accumulatedAlpha + sourceAlpha;

		accumulatedColor = mix(
		                       alphaBlendColor,
		                       additiveColor,
		                       uBloom
		                   );

		accumulatedAlpha = mix(
		                       alphaBlendAlpha,
		                       additiveAlpha,
		                       uBloom
		                   );
	}

	float overlayAlpha = uColorBloom.a;
	vec3 overlayColor = uColorBloom.rgb * overlayAlpha;

	vec3 colorWithOverlay =
	    accumulatedColor +
	    accumulatedAlpha *
	    overlayColor;

	accumulatedColor = mix(
	                       accumulatedColor,
	                       colorWithOverlay,
	                       uBloom
	                   );

	vec3 background = uColorBack.rgb * uColorBack.a;

	vec3 color =
	    accumulatedColor +
	    (1.0 - accumulatedAlpha) *
	    background;

	float opacity =
	    accumulatedAlpha +
	    (1.0 - accumulatedAlpha) *
	    uColorBack.a;

	color = clamp(color, 0.0, 1.0);
	opacity = clamp(opacity, 0.0, 1.0);

	vec3 straightColor =
	    opacity > 0.0001
	    ? color / opacity
	    : color;

	fragColor = vec4(straightColor, opacity);
}