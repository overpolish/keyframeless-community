// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template generator

// #speed group={"Motion", "wind"}
// #seed group="Motion"
// #grain label="Grain" group={"Finish", "camera.filters"} default=0 size=2

// #color label="Colours" min=2 max=4 default="#0A2A5E,#1E7FA8,#6FD0C8,#B8A0E8"
uniform vec4 uColours[4];

// #int label="Detail" group={"Pattern", "circle.hexagongrid"} min=2 max=8 default=5
uniform float uDetail;

// #percent label="Warp" group="Pattern" min=0 max=200 default=100
uniform float uWarp;

// #percent label="Turbulence" group="Pattern" min=0 max=200 default=100
uniform float uTurbulence;

// #point label="Center" group={"Transform", "viewfinder"} osc=position default="0.5,0.5"
uniform vec2 uCenter;

// #percent label="Scale" group="Transform" min=25 max=400 default=100 osc=ring link=uCenter
uniform float uScale;

float hash31(vec3 value)
{
	value = fract(value * 0.1031);
	value += dot(value, value.zyx + 31.32);

	return fract((value.x + value.y) * value.z);
}

float valueNoise(vec3 position)
{
	vec3 cell = floor(position);
	vec3 local = fract(position);
	local = local * local * (3.0 - 2.0 * local);

	float n000 = hash31(cell + vec3(0.0, 0.0, 0.0));
	float n100 = hash31(cell + vec3(1.0, 0.0, 0.0));
	float n010 = hash31(cell + vec3(0.0, 1.0, 0.0));
	float n110 = hash31(cell + vec3(1.0, 1.0, 0.0));
	float n001 = hash31(cell + vec3(0.0, 0.0, 1.0));
	float n101 = hash31(cell + vec3(1.0, 0.0, 1.0));
	float n011 = hash31(cell + vec3(0.0, 1.0, 1.0));
	float n111 = hash31(cell + vec3(1.0, 1.0, 1.0));

	return mix(
	           mix(mix(n000, n100, local.x), mix(n010, n110, local.x), local.y),
	           mix(mix(n001, n101, local.x), mix(n011, n111, local.x), local.y),
	           local.z
	       );
}

vec3 samplePalette(float position)
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
	position /= max(uScale, 0.01);

	float time = iTime * 0.4;
	int detail = uDetail;

	float turbulence =
	    (valueNoise(vec3(position * 2.0, time)) * 2.0 - 1.0) *
	    uTurbulence;

	vec2 warped = position * 1.2;
	float amplitude = 0.7;

	for (int i = 0; i < 8; ++i)
	{
		if (i >= detail)
			break;

		float frequency = float(i) + 1.0;

		vec2 offset = vec2(
		                  sin(frequency * warped.y + time + turbulence * frequency),
		                  cos(frequency * warped.x - time + turbulence)
		              );

		warped -= uWarp * amplitude * offset;
		amplitude *= 0.6;
	}

	float primaryField =
	    0.5 +
	    0.5 * sin(0.8 * (warped.x + warped.y) + turbulence);

	float secondaryField =
	    0.5 +
	    0.5 * cos(warped.x - warped.y);

	vec3 color = samplePalette(primaryField);
	color = mix(color, samplePalette(secondaryField), 0.35);
	color *= 0.75 + 0.25 * sin(warped.y + turbulence);

	fragColor = vec4(color, 1.0);
}