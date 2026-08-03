// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template generator

// #speed group={"Motion", "wind"}
// #seed group="Motion"
// #grain label="Grain" group={"Finish", "camera.filters"} default=0 size=2

// #color label="Base" default="#000D33"
uniform vec4 uBase;

// #color label="Grid" default="#FF3399"
uniform vec4 uGrid;

// #color label="Background" default="#000000"
uniform vec4 uBackground;

// #percent label="Hills" group={"Terrain", "mountain.2"} min=0 max=200 default=50
uniform float uHills;

// #percent label="Grid Density" group="Terrain" min=0 max=100 default=50
uniform float uGridSize;

// #percent label="Line Width" group="Terrain" min=25 max=300 default=100
uniform float uLineWidth;

// #percent label="Fog" group={"Atmosphere", "cloud.fog"} min=0 max=100 default=50
uniform float uFog;

// #int label="Quality" group={"Render", "gauge.with.dots.needle.67percent"} min=40 max=160 default=120
uniform int uQuality;

float heightField(vec2 position, float time)
{
	return (
	           sin(position.x * 0.6 + time * 0.5) +
	           sin(position.y * 0.5 - time * 0.3) -
	           0.5 * sin(position.x * 0.25 + position.y * 0.3 + time * 0.2)
	       ) * uHills * 1.2;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = (fragCoord - iResolution.xy * 0.5) / iResolution.y;
	float time = iTime * 0.4;

	vec3 rayOrigin = vec3(
	                     sin(time * 0.1) * 2.0,
	                     3.2,
	                     -time * 2.0
	                 );

	vec3 target = rayOrigin + vec3(
	                  sin(time * 0.1) * 0.3,
	                  -0.9,
	                  1.0
	              );

	vec3 forward = normalize(target - rayOrigin);
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), forward));
	vec3 up = cross(forward, right);
	vec3 rayDirection = normalize(uv.x * right + uv.y * up + forward * 1.3);

	float distance = 0.0;
	bool hit = false;
	vec3 position = rayOrigin;

	for (int i = 0; i < 160; ++i)
	{
		if (i >= uQuality)
			break;

		position = rayOrigin + rayDirection * distance;
		float heightDistance = position.y - heightField(position.xz, time);

		if (heightDistance < 0.001 * distance)
		{
			hit = true;
			break;
		}

		distance += heightDistance * 0.5;

		if (distance > 40.0)
			break;
	}

	vec3 color = uBackground.rgb;

	if (hit)
	{
		float cellSize = mix(1.2, 0.3, uGridSize);
		vec2 gridPosition = abs(fract(position.xz / cellSize) - 0.5) * cellSize;
		float lineDistance = min(gridPosition.x, gridPosition.y);

		float lineWidth =
		    (0.02 * cellSize + fwidth(lineDistance)) *
		    uLineWidth;

		float line = 1.0 - smoothstep(0.0, lineWidth, lineDistance);
		color = mix(uBase.rgb, uGrid.rgb, line);

		float fogEnd = mix(40.0, 12.0, uFog);
		float fogAmount = smoothstep(0.0, fogEnd, distance);
		color = mix(color, uBackground.rgb, fogAmount);
	}

	fragColor = vec4(color, 1.0);
}