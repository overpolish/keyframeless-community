// SPDX-FileCopyrightText: 2025 Paul Bakaus
// SPDX-License-Identifier: MIT

// #template generator

// Derived from https://github.com/pbakaus/radiant

// #speed group={"Motion", "wind"}
// #seed group="Motion"
// #grain label="Grain" group={"Finish", "camera.filters"} default=0 size=2

// Feature tints, addressed by index below rather than by a position along a
// ramp. Not a #gradient.
// #color label="Colours" min=1 max=4 default="#0A0E2A,#1E4F9C,#3FC7E8,#E8FBFF"
uniform vec4 uColours[4];

// #percent label="Detail" group={"Pattern", "circle.hexagongrid"} min=0 max=100 default=50
uniform float uDetail;

// #percent label="Marble" group="Pattern" min=0 max=200 default=100
uniform float uMarble;

// #percent label="Vibrance" group={"Appearance", "sparkles"} min=0 max=200 default=100
uniform float uVibrance;

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
	vec3 blend = local * local * (3.0 - 2.0 * local);

	float n000 = hash31(cell + vec3(0.0, 0.0, 0.0));
	float n100 = hash31(cell + vec3(1.0, 0.0, 0.0));
	float n010 = hash31(cell + vec3(0.0, 1.0, 0.0));
	float n110 = hash31(cell + vec3(1.0, 1.0, 0.0));
	float n001 = hash31(cell + vec3(0.0, 0.0, 1.0));
	float n101 = hash31(cell + vec3(1.0, 0.0, 1.0));
	float n011 = hash31(cell + vec3(0.0, 1.0, 1.0));
	float n111 = hash31(cell + vec3(1.0, 1.0, 1.0));

	float lower = mix(
	                  mix(n000, n100, blend.x),
	                  mix(n010, n110, blend.x),
	                  blend.y
	              );

	float upper = mix(
	                  mix(n001, n101, blend.x),
	                  mix(n011, n111, blend.x),
	                  blend.y
	              );

	return mix(lower, upper, blend.z) * 2.0 - 1.0;
}

float fbm(vec3 position, float amplitudeDecay)
{
	float value = 0.0;
	float amplitude = 0.5;

	for (int i = 0; i < 5; ++i)
	{
		value += amplitude * valueNoise(position);

		vec2 rotated =
		    rotate2D(position.xy, 0.7) *
		    2.03 +
		    vec2(1.7, 9.2);

		position = vec3(rotated, position.z + 2.3);
		amplitude *= amplitudeDecay;
	}

	return value;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 position = (fragCoord - uCenter) / iResolution.y;
	position /= max(uScale, 0.01);

	float time = iTime * 0.3;
	float detail = clamp(uDetail, 0.0, 1.0);

	vec2 firstWarp = vec2(
	                     fbm(vec3(position, time), detail),
	                     fbm(vec3(position + vec2(5.2, 1.3), time), detail)
	                 );

	vec2 secondWarp = vec2(
	                      fbm(
	                          vec3(
	                              position +
	                              4.0 * uMarble * firstWarp +
	                              vec2(1.7, 9.2),
	                              time * 1.1
	                          ),
	                          detail
	                      ),
	                      fbm(
	                          vec3(
	                              position +
	                              4.0 * uMarble * firstWarp +
	                              vec2(8.3, 2.8),
	                              time * 1.1
	                          ),
	                          detail
	                      )
	                  );

	float field = fbm(
	                  vec3(
	                      position + 3.5 * uMarble * secondWarp,
	                      time * 0.9
	                  ),
	                  detail
	              );

	int colorCount = max(uColoursCount, 1);

	vec4 swatch0 = uColours[0];
	vec4 swatch1 = uColours[min(1, colorCount - 1)];
	vec4 swatch2 = uColours[min(2, colorCount - 1)];
	vec4 swatch3 = uColours[min(3, colorCount - 1)];

	vec3 color0 = swatch0.rgb * swatch0.a;
	vec3 color1 = swatch1.rgb * swatch1.a;
	vec3 color2 = swatch2.rgb * swatch2.a;
	vec3 color3 = swatch3.rgb * swatch3.a;

	vec3 color = mix(
	                 color0,
	                 color1,
	                 clamp(field * field * 2.0 * uVibrance, 0.0, 1.0)
	             );

	color = mix(
	            color,
	            color2,
	            clamp(length(firstWarp) * 0.5 * uVibrance, 0.0, 1.0)
	        );

	color = mix(
	            color,
	            color3,
	            clamp(abs(secondWarp.x) * 0.6 * uVibrance, 0.0, 1.0)
	        );

	float highlight = smoothstep(
	                      0.5,
	                      1.2,
	                      field * field * 3.0 + length(secondWarp) * 0.5
	                  );

	color += color3 * 0.35 * highlight;
	color = pow(max(color, 0.0), vec3(1.1));

	fragColor = vec4(color, 1.0);
}