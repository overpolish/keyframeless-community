// SPDX-FileCopyrightText: The paper-design/shaders authors
// SPDX-FileContributor: Modified by overpolish in 2026
// SPDX-License-Identifier: Apache-2.0

// #template generator
//
// Derived from https://github.com/paper-design/shaders

// #speed group={"Motion", "wind"}
// #seed group="Motion"

// #grain label="Grain" group={"Finish", "camera.filters"} default=0 size=2

// #color label="Colours" min=1 max=6 default="#1A1035,#5B2A8C,#E86BFF,#FFD27A"
uniform vec4 uColours[6];

// #choice label="Shape" group={"Pattern", "square.grid.3x3.fill"} options="Checks,Stripes,Edge" default=0
uniform int uShape;

// #percent label="Shape Scale" group="Pattern" min=0 max=100 default=30
uniform float uShapeScale;

// #percent label="Proportion" group="Pattern" min=0 max=100 default=50
uniform float uProportion;

// #percent label="Softness" group="Pattern" min=0 max=100 default=100
uniform float uSoftness;

// #percent label="Distortion" group={"Warp", "water.waves"} min=0 max=200 default=25
uniform float uDistortion;

// #percent label="Swirl" group="Warp" min=0 max=200 default=30
uniform float uSwirl;

// #int label="Swirl Detail" group="Warp" min=1 max=20 default=8
uniform float uSwirlIterations;

// #point label="Center" group={"Transform", "viewfinder"} osc=position default="0.5,0.5"
uniform vec2 uCenter;

// #percent label="Scale" group="Transform" min=25 max=400 default=100 osc=ring link=uCenter
uniform float uScale;

const float TAU = 6.28318530718;

float hash21(vec2 position)
{
	position = fract(position * vec2(0.3183099, 0.3678794)) + 0.1;
	position += dot(position, position + 19.19);
	return fract(position.x * position.y);
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

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 position = (fragCoord - uCenter) / iResolution.y;
	position *= 2.0 / max(uScale, 0.001);

	// The constant is phase only: it picks where in the noise field the clip
	// starts and changes nothing else.
	float time = (iTime + 118.0) * 0.0625;

	float broadNoise = valueNoise(position + time);
	float detailNoise = valueNoise(position * 2.0 - time);
	float noiseAngle = broadNoise * TAU;

	position +=
	    vec2(
	        cos(noiseAngle),
	        sin(noiseAngle)
	    ) *
	    detailNoise *
	    uDistortion *
	    4.0;

	int swirlDetail = int(uSwirlIterations);

	for (int i = 1; i <= 20; ++i)
	{
		if (i > swirlDetail)
			break;

		float frequency = float(i);

		position.x +=
		    uSwirl /
		    frequency *
		    cos(
		        time +
		        frequency *
		        1.5 *
		        position.y
		    );

		position.y +=
		    uSwirl /
		    frequency *
		    cos(
		        time +
		        frequency *
		        position.x
		    );
	}

	float proportion = clamp(uProportion, 0.0, 1.0);
	float shape;

	if (uShape == 0)
	{
		vec2 patternPosition =
		    position *
		    (0.5 + 3.5 * uShapeScale);

		shape =
		    0.5 +
		    0.5 *
		    sin(patternPosition.x) *
		    cos(patternPosition.y);

		shape +=
		    sign(proportion - 0.5) *
		    sqrt(abs(proportion - 0.5)) *
		    0.48;
	}
	else if (uShape == 1)
	{
		float stripe =
		    fract(
		        position.y *
		        uShapeScale *
		        2.0
		    );

		shape =
		    smoothstep(0.0, 0.55, stripe) *
		    (
		        1.0 -
		        smoothstep(0.45, 1.0, stripe)
		    );

		shape +=
		    sign(proportion - 0.5) *
		    sqrt(abs(proportion - 0.5)) *
		    0.48;
	}
	else
	{
		float edgeScale = 5.0 * (1.0 - uShapeScale);
		float lowerEdge = min(0.45 - edgeScale, 0.55 + edgeScale);
		float upperEdge = max(0.45 - edgeScale, 0.55 + edgeScale);

		shape = smoothstep(
		            lowerEdge,
		            upperEdge,
		            1.0 -
		            position.y +
		            0.3 *
		            (proportion - 0.5)
		        );
	}

	int colourCount = max(uColoursCount, 1);
	float mixer = shape * float(colourCount - 1);
	float shapeAntialiasing = fwidth(shape);

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

		float lowerStep = floor(localMixer);
		float softness = uSoftness * 0.5 + fwidth(localMixer);

		float stepped = lowerStep +
		                smoothstep(
		                    max(
		                        0.0,
		                        0.5 -
		                        softness -
		                        shapeAntialiasing
		                    ),
		                    min(
		                        1.0,
		                        0.5 +
		                        softness +
		                        shapeAntialiasing
		                    ),
		                    localMixer - lowerStep
		                );

		localMixer = mix(stepped, localMixer, uSoftness);

		vec4 swatch = uColours[i];
		swatch.rgb *= swatch.a;
		gradient = mix(gradient, swatch, localMixer);
	}

	float alpha = gradient.a;
	vec3 color =
	    alpha > 0.0001
	    ? gradient.rgb / alpha
	    : gradient.rgb;

	fragColor = vec4(color, alpha);
}