// SPDX-FileCopyrightText: The paper-design/shaders authors
// SPDX-FileContributor: Modified by overpolish in 2026
// SPDX-License-Identifier: Apache-2.0

// #template generator
//
// Derived from https://github.com/paper-design/shaders

// #speed group={"Motion", "wind"}
// #seed group="Motion"

// #grain label="Grain" group={"Finish", "camera.filters"} default=0 size=2

// #color label="Colours" min=1 max=6 default="#0B1026,#274690,#5FA8D3,#F6E27A"
uniform vec4 uColours[6];

// #int label="Steps per Colour" group={"Bands", "line.3.horizontal"} min=1 max=12 default=4
uniform float uSteps;

// #percent label="Softness" group="Bands" min=0 max=100 default=60
uniform float uSoftness;

// #point label="Center" group={"Transform", "viewfinder"} osc=position default="0.5,0.5"
uniform vec2 uCenter;

// #percent label="Scale" group="Transform" min=25 max=400 default=100 osc=ring link=uCenter
uniform float uScale;

vec3 mod289(vec3 value)
{
	return value - floor(value * (1.0 / 289.0)) * 289.0;
}

vec3 permute(vec3 value)
{
	return mod289(((value * 34.0) + 1.0) * value);
}

float simplexNoise(vec2 position)
{
	const vec4 constants = vec4(
	                           0.211324865405187,
	                           0.366025403784439,
	                           -0.577350269189626,
	                           0.024390243902439
	                       );

	vec2 cell = floor(position + dot(position, constants.yy));
	vec2 firstCorner = position - cell + dot(cell, constants.xx);

	vec2 cornerOffset =
	    firstCorner.x > firstCorner.y
	    ? vec2(1.0, 0.0)
	    : vec2(0.0, 1.0);

	vec4 remainingCorners = firstCorner.xyxy + constants.xxzz;
	remainingCorners.xy -= cornerOffset;

	cell -= floor(cell * (1.0 / 289.0)) * 289.0;

	vec3 permutation = permute(
	                       permute(
	                           cell.y +
	                           vec3(0.0, cornerOffset.y, 1.0)
	                       ) +
	                       cell.x +
	                       vec3(0.0, cornerOffset.x, 1.0)
	                   );

	vec3 weight = max(
	                  0.5 -
	                  vec3(
	                      dot(firstCorner, firstCorner),
	                      dot(remainingCorners.xy, remainingCorners.xy),
	                      dot(remainingCorners.zw, remainingCorners.zw)
	                  ),
	                  0.0
	              );

	weight *= weight;
	weight *= weight;

	vec3 gradientX =
	    2.0 *
	    fract(permutation * constants.www) -
	    1.0;

	vec3 gradientY = abs(gradientX) - 0.5;
	vec3 gradientOffset = floor(gradientX + 0.5);
	vec3 gradient = gradientX - gradientOffset;

	weight *=
	    1.79284291400159 -
	    0.85373472095314 *
	    (
	        gradient * gradient +
	        gradientY * gradientY
	    );

	vec3 contribution;
	contribution.x =
	    gradient.x * firstCorner.x +
	    gradientY.x * firstCorner.y;

	contribution.yz =
	    gradient.yz * remainingCorners.xz +
	    gradientY.yz * remainingCorners.yw;

	return 130.0 * dot(weight, contribution);
}

float layeredNoise(vec2 position, float time)
{
	float noise =
	    simplexNoise(
	        position -
	        vec2(0.0, time * 0.3)
	    ) *
	    0.5;

	noise +=
	    simplexNoise(
	        position * 2.0 +
	        vec2(0.0, time * 0.32)
	    ) *
	    0.5;

	return noise;
}

float steppedSmooth(float value, float steps)
{
	float scaledValue = value * steps;
	float lowerStep = floor(scaledValue) / steps;
	float fraction = fract(scaledValue);
	float antialiasing = steps * fwidth(value);
	float softness = uSoftness * 0.5;

	float blend = smoothstep(
	                  0.5 - softness,
	                  min(1.0, 0.5 + softness + antialiasing),
	                  fraction
	              );

	return lowerStep + blend / steps;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 position = (fragCoord - uCenter) / iResolution.y;
	position *= 8.0 / max(uScale, 0.001);

	float time = iTime * 0.2;
	float shape = 0.5 + 0.5 * layeredNoise(position * 0.1, time);

	int colourCount = max(uColoursCount, 1);
	float count = float(colourCount);
	float mixer = (shape - 0.5 / count) * count;
	float steps = max(uSteps, 1.0);

	vec4 gradient = uColours[0];
	gradient.rgb *= gradient.a;

	for (int i = 1; i < 6; ++i)
	{
		if (i >= colourCount)
			break;

		float localMixer = clamp(
		                       mixer - float(i - 1),
		                       0.0,
		                       1.0
		                   );

		localMixer = steppedSmooth(localMixer, steps);

		vec4 swatch = uColours[i];
		swatch.rgb *= swatch.a;
		gradient = mix(gradient, swatch, localMixer);
	}

	if (mixer < 0.0 || mixer > count - 1.0)
	{
		float localMixer =
		    mixer > count - 1.0
		    ? mixer - (count - 1.0)
		    : mixer + 1.0;

		localMixer = steppedSmooth(localMixer, steps);

		vec4 firstSwatch = uColours[0];
		vec4 lastSwatch = uColours[colourCount - 1];
		firstSwatch.rgb *= firstSwatch.a;
		lastSwatch.rgb *= lastSwatch.a;

		gradient = mix(lastSwatch, firstSwatch, localMixer);
	}

	float alpha = gradient.a;
	vec3 color =
	    alpha > 0.0001
	    ? gradient.rgb / alpha
	    : gradient.rgb;

	fragColor = vec4(color, alpha);
}