// SPDX-FileCopyrightText: 2025 Paul Bakaus
// SPDX-License-Identifier: MIT

// #template generator
//
// Derived from https://github.com/pbakaus/radiant

// #speed group={"Motion", "wind"}
// #seed group="Motion"

// #grain label="Grain" group={"Finish", "camera.filters"} default=0 size=2

// #color label="Colours" min=1 max=3 default="#46266E,#C053A6,#FFD0A8"
uniform vec4 uColours[3];

// #color label="Background" default="#05040A"
uniform vec4 uBackground;

// #float label="Folds" group={"Fabric", "water.waves"} min=0.3 max=2.5 default=1
uniform float uFolds;

// #percent label="Drape" group="Fabric" min=0 max=200 default=100
uniform float uDrape;

// #percent label="Sheen" group={"Appearance", "sparkles"} min=0 max=200 default=100
uniform float uSheen;

// #percent label="Saturation" group="Appearance" min=0 max=200 default=135
uniform float uSaturation;

// #percent label="Vignette" group="Appearance" min=0 max=100 default=100
uniform float uVignette;

// #point label="Center" group={"Transform", "viewfinder"} osc=position default="0.5,0.5"
uniform vec2 uCenter;

// #percent label="Scale" group="Transform" min=25 max=400 default=100 osc=ring link=uCenter
uniform float uScale;

float hash12(vec2 position)
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

	float bottomLeft = hash12(cell);
	float bottomRight = hash12(cell + vec2(1.0, 0.0));
	float topLeft = hash12(cell + vec2(0.0, 1.0));
	float topRight = hash12(cell + vec2(1.0, 1.0));

	return mix(
	           mix(bottomLeft, bottomRight, local.x),
	           mix(topLeft, topRight, local.x),
	           local.y
	       );
}

float fbm3(vec2 position)
{
	const mat2 rotation = mat2(0.8, -0.6, 0.6, 0.8);

	float value = 0.0;
	float amplitude = 0.5;

	for (int i = 0; i < 3; ++i)
	{
		value += amplitude * valueNoise(position);
		position = rotation * position * 2.0;
		amplitude *= 0.5;
	}

	return value;
}

float fbm2(vec2 position)
{
	const mat2 rotation = mat2(0.8, -0.6, 0.6, 0.8);

	float value = 0.5 * valueNoise(position);
	position = rotation * position * 2.0;
	value += 0.25 * valueNoise(position);

	return value;
}

vec2 fabricWarp(vec2 position, float time, float scale, float seed, bool lightweight)
{
	vec2 firstPosition = position * scale + vec2(1.7 + seed, 9.2) + time * 0.15;
	vec2 secondPosition = position * scale + vec2(8.3, 2.8 + seed) - time * 0.12;

	if (lightweight)
		return vec2(fbm2(firstPosition), fbm2(secondPosition));

	return vec2(fbm3(firstPosition), fbm3(secondPosition));
}

vec3 fabricFold(
    vec2 position,
    float time,
    float seed,
    float frequency,
    float flow,
    bool lightweight
)
{
	float layerTime = time * flow;
	vec2 warp = fabricWarp(position + seed * 3.7, layerTime, 1.2, seed, lightweight);
	vec2 warpedPosition = position + warp * 0.55 * uDrape;

	float height = 0.0;
	vec2 gradient = vec2(0.0);

	vec2 firstFrequency = frequency * vec2(0.7, 0.4);
	float firstPhase =
	    dot(warpedPosition, firstFrequency) +
	    layerTime * 0.3 +
	    seed * 2.1;

	height += sin(firstPhase) * 0.35;
	gradient += cos(firstPhase) * firstFrequency * 0.35;

	vec2 secondFrequency = frequency * vec2(-0.3, 0.9);
	float secondPhase =
	    dot(warpedPosition, secondFrequency) +
	    layerTime * 0.25 +
	    seed * 1.3;

	height += sin(secondPhase) * 0.25;
	gradient += cos(secondPhase) * secondFrequency * 0.25;

	float diagonalFrequency = frequency * 0.6;
	float diagonalPhase =
	    (warpedPosition.x + warpedPosition.y) * diagonalFrequency +
	    layerTime * 0.2 +
	    seed * 4.5;

	height += sin(diagonalPhase) * 0.18;
	gradient += cos(diagonalPhase) * vec2(diagonalFrequency) * 0.18;

	vec2 detailFrequency = frequency * vec2(1.8, 1.2);
	float detailPhase =
	    dot(warpedPosition, detailFrequency) -
	    layerTime * 0.35 +
	    seed * 0.7;

	height += sin(detailPhase) * 0.08;
	gradient += cos(detailPhase) * detailFrequency * 0.08;

	if (!lightweight)
	{
		float surfaceNoise =
		    valueNoise(
		        warpedPosition * frequency * 0.9 +
		        seed * 10.0 +
		        layerTime * 0.04
		    ) *
		    0.12 -
		    0.06;

		height += surfaceNoise;
	}

	return vec3(height, gradient);
}

float anisotropicSpecular(
    vec2 gradient,
    vec3 lightDirection,
    vec3 viewDirection,
    float shine
)
{
	float gradientLengthSquared = dot(gradient, gradient);

	if (gradientLengthSquared < 0.0001)
		return 0.0;

	vec2 tangentGradient =
	    vec2(-gradient.y, gradient.x) /
	    sqrt(gradientLengthSquared);

	vec3 tangent = normalize(vec3(tangentGradient, 0.0));
	vec3 halfwayDirection = normalize(lightDirection + viewDirection);
	float tangentDotHalfway = dot(tangent, halfwayDirection);

	return pow(
	           sqrt(max(1.0 - tangentDotHalfway * tangentDotHalfway, 0.0)),
	           shine
	       );
}

vec4 shadeLayer(
    vec2 position,
    float time,
    float seed,
    float frequency,
    float flow,
    vec3 darkColor,
    vec3 middleColor,
    vec3 brightColor,
    vec3 specularColor,
    float opacity,
    float shine,
    vec3 primaryLight,
    vec3 secondaryLight,
    vec3 viewDirection,
    float sheen
)
{
	bool lightweight = opacity < 0.35;
	vec3 fold = fabricFold(
	                position,
	                time,
	                seed,
	                frequency,
	                flow,
	                lightweight
	            );

	float height = fold.x;
	vec2 gradient = fold.yz;
	vec3 normal = normalize(vec3(-gradient * 1.8, 1.0));

	float primaryDiffuse = max(dot(normal, primaryLight), 0.0);
	float secondaryDiffuse = max(dot(normal, secondaryLight), 0.0);
	float lighting = primaryDiffuse * 0.75 + secondaryDiffuse * 0.12;
	float depth = smoothstep(-0.8, 0.4, height);
	float shade = lighting * depth;

	float middleBlend = smoothstep(0.0, 0.35, shade);
	float brightBlend = smoothstep(0.25, 0.7, shade);

	vec3 fabric = mix(darkColor, middleColor, middleBlend);
	fabric = mix(fabric, brightColor, brightBlend * 0.5);

	float specular =
	    anisotropicSpecular(
	        gradient,
	        primaryLight,
	        viewDirection,
	        shine
	    ) *
	    0.9;

	specular +=
	    anisotropicSpecular(
	        gradient,
	        secondaryLight,
	        viewDirection,
	        shine * 0.6
	    ) *
	    0.15;

	specular *= sheen;
	fabric += specularColor * specular * specular * specular * 0.9;

	float translucency = smoothstep(0.3, 0.9, depth) * lighting * 0.08;
	fabric += vec3(0.45, 0.28, 0.15) * translucency;

	float alpha = opacity * (0.65 + depth * 0.35);
	return vec4(fabric, alpha);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 position = (fragCoord - uCenter) / iResolution.y;
	position /= max(uScale, 0.001);

	float time = iTime * 0.4;

	vec3 primaryLight = normalize(
	                        vec3(
	                            0.4 + sin(time * 0.07) * 0.3,
	                            0.9 + cos(time * 0.09) * 0.15,
	                            0.8
	                        )
	                    );

	vec3 secondaryLight = normalize(
	                          vec3(
	                              -0.7 + cos(time * 0.06) * 0.2,
	                              -0.3 + sin(time * 0.08) * 0.15,
	                              0.6
	                          )
	                      );

	vec3 viewDirection = vec3(0.0, 0.0, 1.0);

	float backgroundDistance = length(position);
	vec3 color = uBackground.rgb * uBackground.a;
	color += uBackground.rgb * uBackground.a * 0.5 *
	         exp(-backgroundDistance * backgroundDistance * 2.0);

	int colourCount = max(uColoursCount, 1);
	vec4 firstSwatch = uColours[0];
	vec4 secondSwatch = uColours[min(1, colourCount - 1)];
	vec4 thirdSwatch = uColours[min(2, colourCount - 1)];

	vec3 firstColor = firstSwatch.rgb * firstSwatch.a;
	vec3 secondColor = secondSwatch.rgb * secondSwatch.a;
	vec3 thirdColor = thirdSwatch.rgb * thirdSwatch.a;

	vec4 backLayer = shadeLayer(
	                     position * 0.8 + vec2(0.15, time * 0.015),
	                     time,
	                     0.0,
	                     2.0 * uFolds,
	                     0.5,
	                     firstColor * 0.14,
	                     firstColor * 0.55,
	                     firstColor * 0.95,
	                     mix(firstColor, vec3(1.0), 0.72),
	                     0.30,
	                     26.0,
	                     primaryLight,
	                     secondaryLight,
	                     viewDirection,
	                     uSheen * 0.7
	                 );

	vec4 middleLayer = shadeLayer(
	                       position + vec2(time * 0.012, -0.1),
	                       time,
	                       1.0,
	                       3.2 * uFolds,
	                       0.75,
	                       secondColor * 0.14,
	                       secondColor * 0.55,
	                       secondColor * 0.95,
	                       mix(secondColor, vec3(1.0), 0.72),
	                       0.38,
	                       40.0,
	                       primaryLight,
	                       secondaryLight,
	                       viewDirection,
	                       uSheen * 0.9
	                   );

	vec4 frontLayer = shadeLayer(
	                      position * 1.2 + vec2(-time * 0.008, time * 0.02),
	                      time,
	                      2.0,
	                      4.5 * uFolds,
	                      1.0,
	                      thirdColor * 0.14,
	                      thirdColor * 0.55,
	                      thirdColor * 0.95,
	                      mix(thirdColor, vec3(1.0), 0.72),
	                      0.50,
	                      55.0,
	                      primaryLight,
	                      secondaryLight,
	                      viewDirection,
	                      uSheen
	                  );

	color = mix(color, backLayer.rgb, backLayer.a);
	color += firstColor * 0.10 * backLayer.a * middleLayer.a;
	color = mix(color, middleLayer.rgb, middleLayer.a);
	color += secondColor * 0.08 * middleLayer.a * frontLayer.a;
	color = mix(color, frontLayer.rgb, frontLayer.a);

	float coverage =
	    (backLayer.a + middleLayer.a + frontLayer.a) /
	    3.0;

	color += thirdColor * 0.05 * coverage;

	float vignette =
	    1.0 -
	    smoothstep(
	        0.25,
	        1.15,
	        length(position * vec2(0.85, 1.0))
	    );

	color *= mix(
	             1.0,
	             0.6 + 0.4 * vignette,
	             uVignette
	         );

	float luminance = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(vec3(luminance), color, uSaturation);

	color = max(color, vec3(0.0));
	color = color * (2.51 * color + 0.03) /
	        (color * (2.43 * color + 0.59) + 0.14);

	fragColor = vec4(color, 1.0);
}