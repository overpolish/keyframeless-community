// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template generator
// #alpha

// #motionblur off

// #speed group={"Motion","wind"} default=0.1
// #seed group="Motion"

// #int label="Vertical Lines" group={"Grid","square.grid.3x3"} min=1 max=24 default=7
uniform float uVerticalLines;

// #int label="Horizontal Lines" group="Grid" min=1 max=24 default=7
uniform float uHorizontalLines;

// #float label="Line Width" group="Grid" units="px" min=0.25 max=20 slidermax=8 default=1
uniform float uLineWidth;

// #percent label="Line Opacity" group="Grid" min=0 max=100 default=55
uniform float uLineOpacity;

// #percent label="Irregularity" group="Grid" min=0 max=100 default=35
uniform float uIrregularity;

// #percent label="Detail Lines" group="Grid" min=0 max=100 default=28
uniform float uDetail;

// #int label="Echoes" group="Grid" min=1 max=4 default=2
uniform float uEchoes;

// #float label="Echo Spread" group="Grid" units="px" min=0 max=100 slidermax=40 default=14
uniform float uEchoSpread;

// #percent label="Movement" group="Motion" min=0 max=100 default=65
uniform float uMovement;

// #percent label="Variation" group="Motion" min=0 max=100 default=55
uniform float uVariation;

// #point label="Center" group={"Transform","move.3d"} osc=position default="0.5,0.5"
uniform vec2 uCenter;

// #percent label="Scale" group="Transform" osc=ring link=uCenter min=25 max=400 default=100
uniform float uScale;

// #angle label="Rotation" group="Transform" osc={z} link=uCenter default=0
uniform float uRotation;

// #percent label="Stains" group={"Texture","circle.hexagongrid"} min=0 max=100 default=37
uniform float uStains;

// #float label="Stain Scale" group="Texture" min=0.5 max=8 default=2
uniform float uStainScale;

// #percent label="Stain Drift" group="Texture" min=0 max=100 default=35
uniform float uStainDrift;

// #grain label="Grain" group="Texture" default=22 size=2

// #color label="Grid Colour" default="#565149"
uniform vec4 uGridColor;

// #color label="Background" default="#E8E2D4"
uniform vec4 uBackground;

// #color label="Stain Colour" default="#8A765C"
uniform vec4 uStainColor;

float hash11(float value)
{
	return fract(
	           sin(value * 127.1) *
	           43758.5453
	       );
}

float hash21(vec2 value)
{
	return fract(
	           sin(dot(value, vec2(127.1, 311.7))) *
	           43758.5453
	       );
}

float temporalNoise(float identity, float time)
{
	float frame = floor(time);
	float fraction = fract(time);
	fraction = fraction * fraction * (3.0 - 2.0 * fraction);

	float first = hash11(identity + frame * 17.17);
	float second = hash11(identity + (frame + 1.0) * 17.17);

	return mix(first, second, fraction);
}

float valueNoise(vec2 position)
{
	vec2 cell = floor(position);
	vec2 local = fract(position);
	local = local * local * (3.0 - 2.0 * local);

	float bottomLeft = hash21(cell);
	float bottomRight = hash21(cell + vec2(1.0, 0.0));
	float topLeft = hash21(cell + vec2(0.0, 1.0));
	float topRight = hash21(cell + vec2(1.0, 1.0));

	return mix(
	           mix(bottomLeft, bottomRight, local.x),
	           mix(topLeft, topRight, local.x),
	           local.y
	       );
}

float fbm(vec2 position)
{
	float value = 0.0;
	float amplitude = 0.55;

	for (int i = 0; i < 4; ++i)
	{
		value += valueNoise(position) * amplitude;
		position = mat2(1.6, -1.2, 1.2, 1.6) * position + 7.3;
		amplitude *= 0.5;
	}

	return value;
}

float axisLines(
    float coordinate,
    float axisIdentity,
    int count,
    float time
)
{
	float result = 0.0;
	float spacing = 1.0 / float(count);
	float pixelStep = max(fwidth(coordinate), 0.000001);
	float halfWidth = max(uLineWidth, 0.25) * 0.5;
	int echoCount = clamp(int(floor(uEchoes + 0.5)), 1, 4);

	for (int i = 0; i < 72; ++i)
	{
		if (i >= count * 3)
			break;

		int lineIndex = i - count;
		float index = float(lineIndex);
		float identity = index + axisIdentity * 97.0;

		float basePosition =
		    (index + 0.5) *
		    spacing;

		float staticOffset =
		    (hash11(identity + 4.7) - 0.5) *
		    spacing *
		    uIrregularity *
		    1.4;

		float movement =
		    (temporalNoise(identity * 3.1, time) - 0.5) *
		    spacing *
		    uMovement *
		    2.2;

		float linePosition =
		    basePosition +
		    staticOffset +
		    movement;

		float lineStrength = mix(
		                         1.0 - uVariation * 0.55,
		                         1.0,
		                         hash11(identity + 18.3)
		                     );

		for (int echo = 0; echo < 4; ++echo)
		{
			if (echo >= echoCount)
				break;

			float echoIndex = float(echo);

			float echoOffset = echo == 0
			                   ? 0.0
			                   : (hash11(identity * 5.3 + echoIndex * 11.7) * 2.0 - 1.0) *
			                   uEchoSpread *
			                   pixelStep;

			float echoMovement = echo == 0
			                     ? 0.0
			                     : (temporalNoise(
			                            identity * 7.9 + echoIndex * 13.1,
			                            time * 0.83
			                        ) - 0.5) *
			                     uEchoSpread *
			                     pixelStep *
			                     uMovement;

			float pixelDistance =
			    abs(
			        coordinate -
			        linePosition -
			        echoOffset -
			        echoMovement
			    ) /
			    pixelStep;

			float line = 1.0 - smoothstep(
			                 halfWidth,
			                 halfWidth + 1.0,
			                 pixelDistance
			             );

			float echoStrength = echo == 0
			                     ? 1.0
			                     : mix(0.55, 0.2, echoIndex / 3.0);

			result = max(
			             result,
			             line *
			             lineStrength *
			             echoStrength
			         );
		}

		float detailPosition =
		    basePosition +
		    spacing * 0.5 +
		    staticOffset * 0.35 +
		    movement * 0.2;

		float detailDistance =
		    abs(coordinate - detailPosition) /
		    pixelStep;

		float detailLine = 1.0 - smoothstep(
		                       max(halfWidth * 0.55, 0.25),
		                       max(halfWidth * 0.55, 0.25) + 1.0,
		                       detailDistance
		                   );

		result = max(
		             result,
		             detailLine *
		             uDetail *
		             0.55
		         );
	}

	return result;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 resolution = iResolution.xy;
	vec2 uv = fragCoord / resolution;
	float aspect = resolution.x / resolution.y;

	vec2 center = uCenter / resolution;
	vec2 position = (uv - center) * vec2(aspect, 1.0);

	float cosine = cos(uRotation);
	float sine = sin(uRotation);

	position = mat2(
	               cosine, -sine,
	               sine, cosine
	           ) * position;

	position /= max(uScale, 0.001);

	vec2 gridPosition =
	    vec2(position.x / aspect, position.y) +
	    0.5;

	float motionTime =
	    iTime *
	    0.55;

	int verticalCount = clamp(
	                        int(floor(uVerticalLines + 0.5)),
	                        1,
	                        24
	                    );

	int horizontalCount = clamp(
	                          int(floor(uHorizontalLines + 0.5)),
	                          1,
	                          24
	                      );

	float vertical = axisLines(
	                     gridPosition.x,
	                     1.0,
	                     verticalCount,
	                     motionTime
	                 );

	float horizontal = axisLines(
	                       gridPosition.y,
	                       2.0,
	                       horizontalCount,
	                       motionTime * 0.91 + 13.7
	                   );

	float grid = 1.0 -
	             (1.0 - vertical) *
	             (1.0 - horizontal);

	grid *= uLineOpacity;

	vec2 stainPosition =
	    uv *
	    uStainScale *
	    3.0;

	stainPosition += vec2(
	                     motionTime * 0.025,
	                     -motionTime * 0.018
	                 ) * uStainDrift;

	float broadStain = fbm(
	                       stainPosition
	                   );

	float fineStain = fbm(
	                      stainPosition * 2.7 + 19.4
	                  );

	float stain =
	    smoothstep(0.45, 0.92, broadStain) *
	    0.75 +
	    smoothstep(0.58, 0.9, fineStain) *
	    0.25;

	stain *= uStains;

	vec3 backgroundColor = mix(
	                           uBackground.rgb,
	                           uStainColor.rgb,
	                           stain *
	                           uStainColor.a *
	                           0.42
	                       );

	float backgroundAlpha =
	    uBackground.a;

	float gridAlpha =
	    grid *
	    uGridColor.a;

	float outputAlpha =
	    gridAlpha +
	    backgroundAlpha *
	    (1.0 - gridAlpha);

	vec3 premultipliedColor =
	    uGridColor.rgb *
	    gridAlpha +
	    backgroundColor *
	    backgroundAlpha *
	    (1.0 - gridAlpha);

	vec3 outputColor =
	    outputAlpha > 0.0001
	    ? premultipliedColor / outputAlpha
	    : vec3(0.0);

	fragColor = vec4(
	                outputColor,
	                outputAlpha
	            );
}
