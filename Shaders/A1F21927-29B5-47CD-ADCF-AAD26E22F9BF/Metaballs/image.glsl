// SPDX-FileCopyrightText: The paper-design/shaders authors
// SPDX-License-Identifier: Apache-2.0

// #template generator
// SPDX-FileContributor: Modified by overpolish in 2026

// Derived from https://github.com/paper-design/shaders

// #speed group={"Motion", "wind"}
// #seed group="Motion"
// #grain label="Grain" group={"Finish", "camera.filters"} default=0 size=2

// #color label="Colours" min=1 max=6 default="#FF5FA2,#7A5CFF,#33C4FF,#4DE3B0"
uniform vec4 uColours[6];

// #color label="Background" default="#0A0A14"
uniform vec4 uBackground;

// #int label="Balls" group={"Metaballs", "circle.grid.2x2.fill"} min=1 max=20 default=8
uniform float uBalls;

// #percent label="Ball Size" group="Metaballs" min=0 max=150 default=75
uniform float uBallSize;

// #percent label="Merge" group="Metaballs" min=0 max=100 default=60
uniform float uMerge;

// #percent label="Edge Softness" group="Metaballs" min=25 max=300 default=100
uniform float uEdgeSoftness;

// #point label="Center" group={"Transform", "viewfinder"} osc=position default="0.5,0.5"
uniform vec2 uCenter;

// #percent label="Scale" group="Transform" min=25 max=400 default=100 osc=ring link=uCenter
uniform float uScale;

const float TAU = 6.28318530718;
const int MAX_BALLS = 20;

float hash21(vec2 value)
{
	value = fract(value * vec2(0.3183099, 0.3678794)) + 0.1;
	value += dot(value, value + 19.19);

	return fract(value.x * value.y);
}

float smoothNoise(float position)
{
	float cell = floor(position);
	float local = fract(position);

	float previous = hash21(vec2(cell - 1.0, 0.0));
	float current = hash21(vec2(cell, 0.0));
	float next = hash21(vec2(cell + 1.0, 0.0));
	float following = hash21(vec2(cell + 2.0, 0.0));

	return 0.5 * (
	           2.0 * current +
	           (-previous + next) * local +
	           (
	               2.0 * previous -
	               5.0 * current +
	               4.0 * next -
	               following
	           ) * local * local +
	           (
	               -previous +
	               3.0 * current -
	               3.0 * next +
	               following
	           ) * local * local * local
	       );
}

float ballField(vec2 position, vec2 center, float power)
{
	float distance = length(position - center) * 0.5;
	distance = 1.0 - clamp(distance, 0.0, 1.0);

	return pow(distance, power);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 position = (fragCoord - uCenter) / iResolution.y;
	position /= max(uScale, 0.01);
	position += 0.5;

	// Wrapping prevents precision loss on very long timelines or large seeds.
	float time = mod(iTime, 2048.0) * 0.2;

	int ballCount = clamp(int(uBalls), 1, MAX_BALLS);
	int colorCount = max(uColoursCount, 1);

	vec3 accumulatedColor = vec3(0.0);
	float accumulatedShape = 0.0;
	float accumulatedOpacity = 0.0;

	for (int i = 0; i < MAX_BALLS; ++i)
	{
		if (i >= ballCount)
			break;

		float index = float(i);
		float indexPosition = index / float(MAX_BALLS);
		float angle = TAU * indexPosition;
		float speed = 1.0 - indexPosition * 0.2;

		float horizontalNoise = smoothNoise(
		                            angle * 10.0 +
		                            index +
		                            time * speed
		                        );

		float verticalNoise = smoothNoise(
		                          angle * 20.0 +
		                          index -
		                          time * speed
		                      );

		vec2 center =
		    vec2(0.5) +
		    vec2(0.0001) +
		    0.9 *
		    (
		        vec2(horizontalNoise, verticalNoise) -
		        0.5
		    );

		vec4 ballColor = uColours[i % colorCount];
		ballColor.rgb *= ballColor.a;

		float power = 45.0 - 30.0 * uBallSize;
		float shape = ballField(position, center, power);
		shape *= pow(uBallSize, 0.2);
		shape = smoothstep(0.0, 1.0, shape);

		accumulatedColor += ballColor.rgb * shape;
		accumulatedShape += shape;
		accumulatedOpacity += ballColor.a * shape;
	}

	accumulatedColor /= max(accumulatedShape, 0.0001);
	accumulatedOpacity /= max(accumulatedShape, 0.0001);

	float edgeWidth = fwidth(accumulatedShape) * uEdgeSoftness;
	float threshold = 1.0 - uMerge;

	float finalShape = smoothstep(
	                       threshold,
	                       threshold + edgeWidth,
	                       accumulatedShape
	                   );

	vec3 color = accumulatedColor * finalShape;
	float opacity = accumulatedOpacity * finalShape;

	vec3 background = uBackground.rgb * uBackground.a;
	color += background * (1.0 - opacity);
	opacity += uBackground.a * (1.0 - opacity);

	vec3 straightColor =
	    opacity > 0.0001
	    ? color / opacity
	    : color;

	fragColor = vec4(straightColor, opacity);
}