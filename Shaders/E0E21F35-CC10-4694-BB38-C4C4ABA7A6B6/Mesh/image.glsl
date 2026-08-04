// SPDX-FileCopyrightText: The paper-design/shaders authors
// SPDX-License-Identifier: Apache-2.0

// #template generator
// #alpha
// SPDX-FileContributor: Modified by overpolish in 2026

// Derived from https://github.com/paper-design/shaders

// #speed group={"Motion", "wind"}
// #seed group="Motion"
// #grain label="Grain" group={"Finish", "camera.filters"} default=0 size=2

// Weighted control points, each contributing premultiplied by its own alpha.
// Not a #gradient: nAt() returns one colour and no weights.
// #color label="Colours" min=1 max=5 default="#3B5BFF,#8B5CF6,#FF5C8A,#FFB86B,#58E1C1"
uniform vec4 uColours[5];

// #percent label="Distortion" group={"Pattern", "circle.hexagongrid"} min=0 max=200 default=40
uniform float uDistortion;

// #percent label="Swirl" group="Pattern" min=0 max=200 default=30
uniform float uSwirl;

// #point label="Center" group={"Transform", "viewfinder"} osc=position default="0.5,0.5"
uniform vec2 uCenter;

// #percent label="Scale" group="Transform" min=25 max=400 default=100 osc=ring link=uCenter
uniform float uScale;

vec2 rotate2D(vec2 value, float angle)
{
	float sine = sin(angle);
	float cosine = cos(angle);

	return vec2(
	           cosine * value.x + sine * value.y,
	           -sine * value.x + cosine * value.y
	       );
}

vec2 controlPointPosition(int index, float time)
{
	float phase = float(index) * 0.37;
	float horizontalSpeed = 0.6 + fract(float(index) / 3.0) * 0.9;
	float verticalSpeed = 0.8 + fract(float(index + 1) / 4.0);

	return 0.5 + 0.5 * vec2(
	           sin(time * horizontalSpeed + phase),
	           cos(time * verticalSpeed + phase * 1.5)
	       );
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	float aspect = iResolution.x / iResolution.y;
	vec2 aspectScale = vec2(aspect, 1.0);

	vec2 uv = (fragCoord - uCenter) / iResolution.xy;
	uv /= max(uScale, 0.01);
	uv += 0.5;

	// The constant is phase only: it picks where in the field the clip starts.
	float time = (iTime + 41.5) * 0.5;
	float radius = smoothstep(0.0, 1.0, length((uv - 0.5) * aspectScale));
	float centerWeight = 1.0 - radius;

	for (int iteration = 1; iteration <= 2; ++iteration)
	{
		float index = float(iteration);
		float verticalPosition = smoothstep(0.0, 1.0, uv.y);

		uv.x +=
		    uDistortion * centerWeight / index -
		    sin(time + index * 0.4 * verticalPosition) -
		    cos(time * 0.2 + index * 2.4 * verticalPosition);

		float horizontalPosition = smoothstep(0.0, 1.0, uv.x);

		uv.y +=
		    uDistortion * centerWeight / index -
		    cos(time + index * 2.0 * horizontalPosition);
	}

	vec2 swirled = rotate2D(
	                   uv - 0.5,
	                   -3.0 * uSwirl * radius
	               );

	swirled += 0.5;

	vec3 premultipliedColor = vec3(0.0);
	float weightedAlpha = 0.0;
	float totalWeight = 0.0;
	int colorCount = clamp(uColoursCount, 1, 5);

	for (int i = 0; i < 5; ++i)
	{
		if (i >= colorCount)
			break;

		vec2 point = controlPointPosition(i, time);

		float weight =
		    1.0 /
		    (
		        pow(
		            length((swirled - point) * aspectScale),
		            3.5
		        ) +
		        0.001
		    );

		premultipliedColor += uColours[i].rgb * uColours[i].a * weight;
		weightedAlpha += uColours[i].a * weight;
		totalWeight += weight;
	}

	premultipliedColor /= max(totalWeight, 0.0001);
	float opacity = clamp(weightedAlpha / max(totalWeight, 0.0001), 0.0, 1.0);

	vec3 straightColor =
	    opacity > 0.0001
	    ? premultipliedColor / opacity
	    : premultipliedColor;

	fragColor = vec4(straightColor, opacity);
}
