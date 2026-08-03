// SPDX-FileCopyrightText: 2025 Paul Bakaus
// SPDX-License-Identifier: MIT

// #template generator
//
// Derived from https://github.com/pbakaus/radiant

// #speed group={"Motion", "wind"}
// #seed group="Motion"

// #grain label="Grain" group={"Finish", "camera.filters"} default=0 size=2

// One swatch per layer, chosen by hash rather than by position. A #gradient
// would interpolate between neighbours and the strata would stop being flat
// bands of colour.
// #color label="Colours" min=1 max=6 default="#3B2A1F,#6B4A2F,#A9744F,#D8B08C,#8C6B4A"
uniform vec4 uColours[6];

// #int label="Layers" group={"Strata", "square.3.layers.3d"} min=1 max=24 default=12
uniform float uLayers;

// #percent label="Tectonics" group="Strata" min=0 max=200 default=60
uniform float uTectonics;

// #percent label="Texture" group={"Appearance", "square.grid.3x3.fill"} min=0 max=200 default=70
uniform float uTexture;

// #percent label="Saturation" group="Appearance" min=0 max=200 default=82
uniform float uSaturation;

// #percent label="Vignette" group="Appearance" min=0 max=100 default=100
uniform float uVignette;

// #point label="Center" group={"Transform", "viewfinder"} osc=position default="0.5,0.5"
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

float hash21(vec2 position)
{
	vec3 value = fract(vec3(position.x, position.y, position.x) * 0.1031);
	value += dot(value, value.yzx + 33.33);
	return fract((value.x + value.y) * value.z);
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
	const vec2 shift = vec2(100.0);
	const mat2 rotation = mat2(
	                          0.877582562,
	                          0.479425539,
	                          -0.479425539,
	                          0.877582562
	                      );

	float value = 0.0;
	float amplitude = 0.5;

	for (int i = 0; i < 5; ++i)
	{
		value += amplitude * valueNoise(position);
		position = rotation * position * 2.0 + shift;
		amplitude *= 0.5;
	}

	return value;
}

vec2 tectonicWarp(vec2 position, float time)
{
	float movement = time * 0.15;

	float horizontalWarp =
	    fbm(
	        position * 1.5 +
	        vec2(movement * 0.7, movement * 0.3)
	    ) -
	    0.5;

	float verticalWarp =
	    fbm(
	        position * 1.5 +
	        vec2(
	            movement * 0.5 + 50.0,
	            movement * 0.8 + 30.0
	        )
	    ) -
	    0.5;

	float compression =
	    sin(
	        position.x * 2.0 +
	        movement * 0.4
	    ) *
	    0.08;

	float shear =
	    sin(
	        position.y * 3.0 +
	        movement * 0.6
	    ) *
	    0.06;

	return position +
	       vec2(
	           horizontalWarp * 0.25 + shear,
	           verticalWarp * 0.18 + compression
	       ) *
	       uTectonics;
}

float layerBoundary(
    float horizontalPosition,
    float baseHeight,
    float layerIndex,
    float time
)
{
	float firstRandom = hash11(layerIndex * 7.13);
	float secondRandom = hash11(layerIndex * 13.37);
	float thirdRandom = hash11(layerIndex * 23.71);

	float firstFrequency = 1.5 + firstRandom * 2.5;
	float secondFrequency = 3.0 + secondRandom * 3.0;
	float firstAmplitude = (0.04 + firstRandom * 0.06) * uTectonics;
	float secondAmplitude = (0.015 + secondRandom * 0.025) * uTectonics;

	float firstPhase = time * (0.1 + thirdRandom * 0.15);
	float secondPhase = time * (0.08 + firstRandom * 0.12);

	float fold =
	    firstAmplitude *
	    sin(
	        horizontalPosition * firstFrequency +
	        firstPhase +
	        secondRandom * TAU
	    );

	fold +=
	    secondAmplitude *
	    sin(
	        horizontalPosition * secondFrequency +
	        secondPhase +
	        thirdRandom * TAU
	    );

	fold +=
	    valueNoise(
	        vec2(
	            horizontalPosition * 4.0 +
	            firstRandom * 100.0,
	            time * 0.2 +
	            layerIndex
	        )
	    ) *
	    uTectonics *
	    0.02;

	return baseHeight + fold;
}

float grainTexture(vec2 position, float layerIndex)
{
	float randomValue = hash11(layerIndex * 41.93);
	float fiberAngle = randomValue * 0.3 * 3.141592654;
	float cosine = cos(fiberAngle);
	float sine = sin(fiberAngle);

	vec2 rotatedPosition = vec2(
	                           position.x * cosine - position.y * sine,
	                           position.x * sine + position.y * cosine
	                       );

	float firstFiber =
	    valueNoise(
	        vec2(
	            rotatedPosition.x * 120.0,
	            rotatedPosition.y * 18.0
	        ) +
	        layerIndex * 30.0
	    );

	float secondFiber =
	    valueNoise(
	        vec2(
	            rotatedPosition.x * 80.0,
	            rotatedPosition.y * 12.0
	        ) +
	        layerIndex * 50.0 +
	        100.0
	    );

	float crossFiber =
	    valueNoise(
	        vec2(
	            rotatedPosition.x * 15.0,
	            rotatedPosition.y * 70.0
	        ) +
	        layerIndex * 40.0
	    );

	float textureValue =
	    firstFiber * 0.08 +
	    secondFiber * 0.05 +
	    crossFiber * 0.03;

	textureValue +=
	    valueNoise(
	        position * 50.0 +
	        layerIndex * 25.0
	    ) *
	    0.025;

	return textureValue - 0.04;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 normalizedPosition = fragCoord / iResolution.xy;
	vec2 center = uCenter / iResolution.xy;

	vec2 uv =
	    (normalizedPosition - center) /
	    max(uScale, 0.001) +
	    0.5;

	float aspect = iResolution.x / iResolution.y;
	vec2 aspectPosition = vec2(uv.x * aspect, uv.y);
	float time = iTime * 0.5;

	int layerCount = max(int(uLayers), 1);
	vec2 warpedPosition = tectonicWarp(aspectPosition, time);

	float layerSpacing = 1.0 / float(layerCount + 1);
	float currentLayer = -1.0;
	float layerPosition = 0.0;
	float previousBoundary = -0.2;

	for (int i = 0; i < 24; ++i)
	{
		if (i >= layerCount)
			break;

		float index = float(i);
		float baseHeight = float(i + 1) * layerSpacing;

		float boundary = layerBoundary(
		                     warpedPosition.x,
		                     baseHeight,
		                     index,
		                     time
		                 );

		if (
		    warpedPosition.y >= previousBoundary &&
		    warpedPosition.y < boundary
		)
		{
			currentLayer = index;

			float thickness =
			    boundary -
			    previousBoundary;

			layerPosition =
			    (warpedPosition.y - previousBoundary) /
			    max(thickness, 0.001);

			break;
		}

		previousBoundary = boundary;
	}

	if (currentLayer < 0.0)
	{
		currentLayer = float(layerCount);
		layerPosition = 0.5;
	}

	int colourCount = max(uColoursCount, 1);
	float paletteRandom = hash11(currentLayer * 17.31 + 3.7);
	int colourIndex = int(floor(paletteRandom * float(colourCount)));
	colourIndex = clamp(colourIndex, 0, colourCount - 1);

	vec4 swatch = uColours[colourIndex];
	vec3 color = swatch.rgb * swatch.a;

	float layerVariation = hash11(currentLayer * 31.17);
	color += (layerVariation - 0.5) * 0.06;
	color += grainTexture(warpedPosition, currentLayer) * uTexture;

	float lowerEdge =
	    smoothstep(
	        0.0,
	        0.15,
	        layerPosition
	    );

	float upperEdge =
	    1.0 -
	    smoothstep(
	        0.85,
	        1.0,
	        layerPosition
	    );

	float edgeShading = lowerEdge * upperEdge;
	color *= 0.85 + 0.15 * edgeShading;

	float lowerShadow =
	    smoothstep(
	        0.0,
	        0.08,
	        layerPosition
	    );

	color *= 0.82 + 0.18 * lowerShadow;

	float topHighlight =
	    smoothstep(
	        0.92,
	        1.0,
	        layerPosition
	    );

	color += vec3(0.04, 0.035, 0.025) * topHighlight;

	float vignette = clamp(
	                     1.0 -
	                     0.3 *
	                     length(
	                         (uv - 0.5) *
	                         1.5
	                     ),
	                     0.0,
	                     1.0
	                 );

	color *= mix(1.0, vignette, uVignette);

	float paperTexture =
	    valueNoise(fragCoord * 0.15) *
	    0.03 *
	    uTexture;

	paperTexture +=
	    (
	        hash21(
	            fragCoord +
	            fract(time * 0.1) *
	            1000.0
	        ) -
	        0.5
	    ) *
	    0.015 *
	    uTexture;

	color += paperTexture;

	float luminance = dot(
	                      color,
	                      vec3(0.299, 0.587, 0.114)
	                  );

	color = mix(
	            vec3(luminance),
	            color,
	            uSaturation
	        );

	fragColor = vec4(color, 1.0);
}