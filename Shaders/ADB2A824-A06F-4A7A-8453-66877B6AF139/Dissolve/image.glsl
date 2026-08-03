// SPDX-FileCopyrightText: hjm1fb
// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template transition

// #color label="Spread Colour" default="#FF0000"
uniform vec4 uSpreadColor;

// #color label="Hot Colour" default="#E6E633"
uniform vec4 uHotColor;

// #choice label="Burn Map" group={"Burn", "flame"} options="Luminance,Reverse Luminance,Left to Right,Right to Left,Top to Bottom,Bottom to Top,Radial Out,Radial In,Organic" dropdown default=0
uniform int uBurnMap;

// #point label="Center" group="Burn" osc=position default="0.5,0.5"
uniform vec2 uCenter;

// #percent label="Edge Width" group="Burn" min=0 max=50 default=10
uniform float uLineWidth;

// #float label="Colour Power" group="Burn" min=0.1 max=10 default=5
uniform float uPower;

// #percent label="Intensity" group="Burn" min=0 max=400 default=100
uniform float uIntensity;

// #percent label="Texture" group={"Texture", "circle.hexagongrid"} min=0 max=100 default=0
uniform float uTexture;

// #float label="Texture Scale" group="Texture" min=1 max=30 default=8
uniform float uTextureScale;

// #percent label="Texture Drift" group="Texture" min=0 max=200 default=0
uniform float uTextureDrift;

// #random label="Texture Seed" group="Texture"
uniform float uSeed;

vec2 burnHash(vec2 position)
{
	position = vec2(dot(position, vec2(127.1, 311.7)), dot(position, vec2(269.5, 183.3)));
	return -1.0 + 2.0 * fract(sin(position) * 43758.5453123);
}

float burnNoise(vec2 position)
{
	const float skew = 0.366025404;
	const float unskew = 0.211324865;

	vec2 cell = floor(position + (position.x + position.y) * skew);
	vec2 cornerA = position - cell + (cell.x + cell.y) * unskew;
	float triangle = step(cornerA.y, cornerA.x);
	vec2 offset = vec2(triangle, 1.0 - triangle);
	vec2 cornerB = cornerA - offset + unskew;
	vec2 cornerC = cornerA - 1.0 + 2.0 * unskew;

	vec3 weight = max(0.5 - vec3(dot(cornerA, cornerA), dot(cornerB, cornerB), dot(cornerC, cornerC)), 0.0);
	vec3 contribution = weight * weight * weight * weight;
	contribution *= vec3(dot(cornerA, burnHash(cell)), dot(cornerB, burnHash(cell + offset)), dot(cornerC, burnHash(cell + 1.0)));

	return dot(contribution, vec3(70.0));
}

float burnField(vec2 uv, vec3 sourceColor, float progress)
{
	float luminance = dot(sourceColor, vec3(0.299, 0.587, 0.114));
	float aspect = iResolution.x / iResolution.y;
	vec2 center = uCenter / iResolution.xy;
	vec2 centered = (uv - center) * vec2(aspect, 1.0);
	float maximumRadius = length(vec2(max(center.x, 1.0 - center.x) * aspect, max(center.y, 1.0 - center.y)));
	float radial = clamp(length(centered) / max(maximumRadius, 0.001), 0.0, 1.0);

	vec2 noisePosition = uv * vec2(aspect, 1.0) * uTextureScale;
	noisePosition += vec2(uSeed * 0.017, uSeed * 0.031);
	// Drift walks with the transition's own sweep, not iTime. Driving it from wall
	// clock made the same frame of the same transition render differently depending
	// on where the clip sat in the project, so a scrub never matched the render.
	noisePosition += vec2(progress * uTextureDrift * 0.15, -progress * uTextureDrift * 0.11);
	float noiseValue = burnNoise(noisePosition);

	float field = luminance;

	if (uBurnMap == 1)
		field = 1.0 - luminance;
	else if (uBurnMap == 2)
		field = uv.x;
	else if (uBurnMap == 3)
		field = 1.0 - uv.x;
	else if (uBurnMap == 4)
		field = 1.0 - uv.y;
	else if (uBurnMap == 5)
		field = uv.y;
	else if (uBurnMap == 6)
		field = radial;
	else if (uBurnMap == 7)
		field = 1.0 - radial;
	else if (uBurnMap == 8)
		field = 0.5 + 0.5 * noiseValue;

	float burn = 0.5 + 0.5 * field;
	burn += noiseValue * uTexture * 0.18;

	return clamp(burn, 0.001, 1.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;
	float progress = clamp(iProgress, 0.0, 1.0);

	vec4 fromColor = texture(iChannel0, uv);
	vec4 toColor = texture(iChannel1, uv);

	if (progress <= 0.0)
	{
		fragColor = fromColor;
		return;
	}

	if (progress >= 1.0)
	{
		fragColor = toColor;
		return;
	}

	vec3 burnSource = iTransitionMode == 1 ? toColor.rgb : fromColor.rgb;
	float burn = burnField(uv, burnSource, progress);
	float remaining = burn - progress;
	float reveal = 1.0 - step(0.001, remaining);
	vec4 color = mixTransitionColors(fromColor, toColor, reveal);

	float edgeWidth = max(uLineWidth, 0.0001);
	float edge = 1.0 - smoothstep(0.0, edgeWidth, remaining);
	edge *= step(0.001, remaining);
	vec3 burnColor = mix(uSpreadColor.rgb, uHotColor.rgb, edge);
	burnColor = pow(max(burnColor, 0.0), vec3(uPower)) * uIntensity;

	float edgeAmount = edge * step(0.0001, progress) * max(fromColor.a, toColor.a);
	fragColor = compositeTransitionLayer(color, vec4(burnColor, edgeAmount));
}