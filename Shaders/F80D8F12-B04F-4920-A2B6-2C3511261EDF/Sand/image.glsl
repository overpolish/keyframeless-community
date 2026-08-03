// SPDX-FileCopyrightText: The paper-design/shaders authors
// SPDX-License-Identifier: Apache-2.0

// #template generator
// SPDX-FileContributor: Modified by overpolish in 2026

// Derived from https://github.com/paper-design/shaders

// #speed group={"Motion", "wind"}
// #seed group="Motion"

// #color label="Colours" min=1 max=6 default="#12141C,#3A5BA0,#F4A259,#F7E1A0"
uniform vec4 uColours[6];

// #color label="Background" default="#0A0A12"
uniform vec4 uColorBack;

// #choice label="Shape" group={"Pattern", "circle.grid.3x3.fill"} options="Wave,Dots,Truchet,Corners,Ripple,Blob" default=0
uniform int uShape;

// #percent label="Intensity" group={"Texture", "aqi.medium"} min=0 max=200 default=50
uniform float uIntensity;

// #percent label="Grain" group="Texture" min=0 max=200 default=30
uniform float uGrain;

// #percent label="Softness" group={"Appearance", "circle.lefthalf.filled"} min=0 max=100 default=40
uniform float uSoftness;

// #point label="Center" group={"Transform", "viewfinder"} osc=position default="0.5,0.5"
uniform vec2 uCenter;

// #percent label="Scale" group="Transform" min=25 max=400 default=100 osc=ring link=uCenter
uniform float uScale;

const float TAU = 6.28318530718;
const float PATTERN_TILES = 16.0;
const float REFERENCE_HEIGHT = 1080.0;

const int SHAPE_WAVE = 0;
const int SHAPE_DOTS = 1;
const int SHAPE_TRUCHET = 2;
const int SHAPE_CORNERS = 3;
const int SHAPE_RIPPLE = 4;

vec2 rotate2D(vec2 value, float angle)
{
	float sine = sin(angle);
	float cosine = cos(angle);

	return vec2(
	           cosine * value.x + sine * value.y,
	           -sine * value.x + cosine * value.y
	       );
}

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

vec3 mod289(vec3 value)
{
	return value - floor(value / 289.0) * 289.0;
}

vec3 permute(vec3 value)
{
	return mod289((value * 34.0 + 1.0) * value);
}

float simplexNoise(vec2 position)
{
	const vec4 coefficients = vec4(
	                              0.211324865405187,
	                              0.366025403784439,
	                              -0.577350269189626,
	                              0.024390243902439
	                          );

	vec2 cell = floor(position + dot(position, coefficients.yy));
	vec2 local = position - cell + dot(cell, coefficients.xx);
	vec2 offset = local.x > local.y ? vec2(1.0, 0.0) : vec2(0.0, 1.0);

	vec4 corners = local.xyxy + coefficients.xxzz;
	corners.xy -= offset;

	cell = mod(cell, 289.0);

	vec3 permutation = permute(
	                       permute(cell.y + vec3(0.0, offset.y, 1.0)) +
	                       cell.x +
	                       vec3(0.0, offset.x, 1.0)
	                   );

	vec3 weight = max(
	                  0.5 - vec3(
	                      dot(local, local),
	                      dot(corners.xy, corners.xy),
	                      dot(corners.zw, corners.zw)
	                  ),
	                  0.0
	              );

	weight *= weight;
	weight *= weight;

	vec3 gradient = 2.0 * fract(permutation * coefficients.www) - 1.0;
	vec3 height = abs(gradient) - 0.5;
	vec3 rounded = floor(gradient + 0.5);
	vec3 remainder = gradient - rounded;

	weight *=
	    1.79284291400159 -
	    0.85373472095314 *
	    (remainder * remainder + height * height);

	vec3 contribution;
	contribution.x = remainder.x * local.x + height.x * local.y;
	contribution.yz = remainder.yz * corners.xz + height.yz * corners.yw;

	return 130.0 * dot(weight, contribution);
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

vec4 fbm4(vec2 p0, vec2 p1, vec2 p2, vec2 p3)
{
	float amplitude = 0.2;
	vec4 total = vec4(0.0);

	for (int i = 0; i < 3; ++i)
	{
		p0 = rotate2D(p0, 0.3);
		p1 = rotate2D(p1, 0.3);
		p2 = rotate2D(p2, 0.3);
		p3 = rotate2D(p3, 0.3);

		total.x += valueNoise(p0) * amplitude;
		total.y += valueNoise(p1) * amplitude;
		total.z += valueNoise(p2) * amplitude;
		total.w += valueNoise(p3) * amplitude;

		p0 *= 1.99;
		p1 *= 1.99;
		p2 *= 1.99;
		p3 *= 1.99;

		amplitude *= 0.6;
	}

	return total;
}

vec2 truchetTile(vec2 position, float index)
{
	index = fract((index - 0.5) * 2.0);

	if (index > 0.75)
		position = vec2(1.0) - position;
	else if (index > 0.5)
		position = vec2(1.0 - position.x, position.y);
	else if (index > 0.25)
		position = vec2(position.x, 1.0 - position.y);

	return position;
}

float shapeField(vec2 position, float time)
{
	if (uShape == SHAPE_WAVE)
	{
		float wave =
		    cos(position.x * 0.5 - time * 4.0) *
		    sin(position.x * 1.5 + time * 2.0) *
		    (0.75 + 0.25 * cos(time * 6.0));

		return 1.0 - smoothstep(-1.0, 1.0, position.y + wave);
	}

	if (uShape == SHAPE_DOTS)
	{
		float stripe = floor(2.0 * position.x / TAU);
		float randomValue = hash11(stripe * 100.0);
		randomValue = sign(randomValue - 0.5) * pow(4.0 * abs(randomValue), 0.3);

		float shape =
		    sin(position.x) *
		    cos(position.y - 5.0 * randomValue * time);

		return pow(abs(shape), 4.0);
	}

	if (uShape == SHAPE_TRUCHET)
	{
		float noise = valueNoise(position * 0.4 - time * 3.75);

		position.x += 10.0;
		position *= 0.6;

		vec2 tile = truchetTile(fract(position), hash21(floor(position)));
		float firstDistance = length(tile);
		float secondDistance = length(tile - vec2(1.0));

		noise = (noise - 0.5) * 0.1;

		float shape =
		    smoothstep(0.2, 0.55, firstDistance + noise) *
		    (
		        1.0 -
		        smoothstep(0.45, 0.8, firstDistance - noise)
		    );

		shape +=
		    smoothstep(0.2, 0.55, secondDistance + noise) *
		    (
		        1.0 -
		        smoothstep(0.45, 0.8, secondDistance - noise)
		    );

		return pow(shape, 1.5);
	}

	if (uShape == SHAPE_CORNERS)
	{
		position *= 0.6;

		vec2 outer = vec2(0.5);
		vec2 lower = smoothstep(
		                 vec2(0.0),
		                 outer,
		                 position +
		                 vec2(
		                     0.1 + 0.1 * sin(time * 3.0),
		                     0.2 - 0.1 * sin(time * 5.25)
		                 )
		             );

		vec2 upper = smoothstep(vec2(0.0), outer, 1.0 - position);
		float shape = 1.0 - lower.x * lower.y * upper.x * upper.y;

		position = -position;

		lower = smoothstep(
		            vec2(0.0),
		            outer,
		            position +
		            vec2(
		                0.1 + 0.1 * sin(time * 3.0),
		                0.2 - 0.1 * cos(time * 5.25)
		            )
		        );

		upper = smoothstep(vec2(0.0), outer, 1.0 - position);
		shape -= lower.x * lower.y * upper.x * upper.y;

		return 1.0 - smoothstep(0.0, 1.0, shape);
	}

	if (uShape == SHAPE_RIPPLE)
	{
		position *= 2.0;

		float distance = length(position * 0.4);
		return sin(pow(distance, 1.2) * 5.0 - time * 3.0) * 0.5 + 0.5;
	}

	float blobTime = time * 2.0;

	vec2 offset0 = 0.25 * vec2(
	                   1.3 * sin(blobTime),
	                   0.2 + 1.3 * cos(blobTime * 0.6 + 4.0)
	               );

	vec2 offset1 = 0.2 * vec2(
	                   1.2 * sin(-blobTime),
	                   1.3 * sin(blobTime * 1.6)
	               );

	vec2 offset2 = 0.25 * vec2(
	                   1.7 * cos(blobTime * -0.6),
	                   cos(blobTime * -1.6)
	               );

	vec2 offset3 = 0.3 * vec2(
	                   1.4 * cos(blobTime * 0.8),
	                   1.2 * sin(blobTime * -0.6 - 3.0)
	               );

	float shape =
	    0.5 *
	    pow(
	        1.0 - clamp(length(position + offset0), 0.0, 1.0),
	        5.0
	    );

	shape +=
	    0.5 *
	    pow(
	        1.0 - clamp(length(position + offset1), 0.0, 1.0),
	        5.0
	    );

	shape +=
	    0.5 *
	    pow(
	        1.0 - clamp(length(position + offset2), 0.0, 1.0),
	        5.0
	    );

	shape +=
	    0.5 *
	    pow(
	        1.0 - clamp(length(position + offset3), 0.0, 1.0),
	        5.0
	    );

	shape = smoothstep(0.0, 0.9, shape);
	float edge = smoothstep(0.25, 0.3, shape);

	return mix(0.0, shape, edge);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	float aspect = iResolution.x / iResolution.y;
	// The constant is phase only: it picks where in the field the clip starts.
	float time = (iTime + 7.0) * 0.1;

	vec2 objectPosition = (fragCoord - uCenter) / iResolution.y;
	objectPosition /= max(uScale, 0.01);

	vec2 patternPosition = objectPosition * PATTERN_TILES;
	vec2 shapePosition;
	vec2 grainPosition;

	if (uShape > SHAPE_TRUCHET)
	{
		shapePosition = objectPosition;

		grainPosition =
		    objectPosition *
		    vec2(aspect * REFERENCE_HEIGHT, REFERENCE_HEIGHT) *
		    0.7;
	}
	else
	{
		shapePosition = patternPosition * 0.5;
		grainPosition = patternPosition * 160.0;
	}

	float colorCount = max(float(uColoursCount), 1.0);
	float shape = shapeField(shapePosition, time);

	float baseNoise = simplexNoise(grainPosition * 0.5);

	vec4 fbmValues = fbm4(
	                     grainPosition * 0.002 + 10.0,
	                     grainPosition * 0.003,
	                     grainPosition * 0.001,
	                     rotate2D(grainPosition * 0.4, 2.0)
	                 );

	float grainDistance =
	    baseNoise *
	    simplexNoise(grainPosition * 0.2) -
	    fbmValues.x -
	    fbmValues.y;

	float rawNoise =
	    baseNoise * 0.75 -
	    fbmValues.w -
	    fbmValues.z;

	float noise = clamp(rawNoise, 0.0, 1.0);

	shape +=
	    uIntensity *
	    2.0 /
	    colorCount *
	    (grainDistance + 0.5);

	shape +=
	    uGrain *
	    10.0 /
	    colorCount *
	    noise;

	float antialias = fwidth(shape);
	shape = clamp(shape - 0.5 / colorCount, 0.0, 1.0);

	float totalShape = smoothstep(
	                       0.0,
	                       uSoftness + 2.0 * antialias,
	                       clamp(shape * colorCount, 0.0, 1.0)
	                   );

	float palettePosition = shape * (colorCount - 1.0);
	int lastColor = int(colorCount) - 1;

	vec4 gradient = uColours[0];
	gradient.rgb *= gradient.a;

	for (int i = 1; i < 6; ++i)
	{
		if (i > lastColor)
			break;

		float localPosition = clamp(
		                          palettePosition - float(i - 1),
		                          0.0,
		                          1.0
		                      );

		localPosition = smoothstep(
		                    0.5 - 0.5 * uSoftness - antialias,
		                    0.5 + 0.5 * uSoftness + antialias,
		                    localPosition
		                );

		vec4 nextColor = uColours[i];
		nextColor.rgb *= nextColor.a;

		gradient = mix(gradient, nextColor, localPosition);
	}

	vec3 color = gradient.rgb * totalShape;
	float opacity = gradient.a * totalShape;

	vec3 background = uColorBack.rgb * uColorBack.a;
	color += background * (1.0 - opacity);
	opacity += uColorBack.a * (1.0 - opacity);

	vec3 straightColor =
	    opacity > 0.0001
	    ? color / opacity
	    : color;

	fragColor = vec4(straightColor, opacity);
}