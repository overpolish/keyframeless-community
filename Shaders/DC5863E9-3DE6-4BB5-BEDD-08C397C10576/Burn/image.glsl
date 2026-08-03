// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template transition

// #color label="Leak Colour" default="#FF5A1F"
uniform vec4 uLeakColor;

// #color label="Hot Colour" default="#FFF1C2"
uniform vec4 uHotColor;

// #choice label="Style" group={"Light Leak", "flame"} options="Light Leak,Flash Burn" default=0
uniform int uStyle;

// #point label="Origin" group="Light Leak" osc=position default="0.5,0.5"
uniform vec2 uCenter;

// #angle label="Direction" group="Light Leak" osc={z} link=uCenter default=0
uniform float uDirection;

// #percent label="Width" group="Light Leak" min=2 max=100 default=25
uniform float uWidth;

// #percent label="Softness" group="Light Leak" min=0 max=50 default=8
uniform float uSoftness;

// #percent label="Intensity" group={"Exposure", "sun.max"} min=0 max=300 default=100
uniform float uIntensity;

// #percent label="Bloom" group="Exposure" min=0 max=300 default=80
uniform float uBloom;

// #percent label="Texture" group={"Texture", "circle.hexagongrid"} min=0 max=100 default=45
uniform float uTexture;

// #float label="Texture Scale" group="Texture" min=1 max=30 default=7
uniform float uTextureScale;

// #percent label="Flicker" group="Texture" min=0 max=100 default=12
uniform float uFlicker;

// #random label="Seed" group="Texture" default=0
uniform float uSeed;

float leakHash(vec2 position)
{
	position = fract(position * vec2(0.3183099, 0.3678794)) + 0.1;
	position += dot(position, position + 19.19);
	return fract(position.x * position.y);
}

float leakNoise(vec2 position)
{
	vec2 cell = floor(position);
	vec2 local = fract(position);
	vec2 blend = local * local * (3.0 - 2.0 * local);

	float bottomLeft = leakHash(cell);
	float bottomRight = leakHash(cell + vec2(1.0, 0.0));
	float topLeft = leakHash(cell + vec2(0.0, 1.0));
	float topRight = leakHash(cell + vec2(1.0, 1.0));

	return mix(mix(bottomLeft, bottomRight, blend.x), mix(topLeft, topRight, blend.x), blend.y);
}

float fractalNoise(vec2 position)
{
	float value = 0.0;
	float amplitude = 0.5;
	float totalWeight = 0.0;

	for (int i = 0; i < 4; ++i)
	{
		value += leakNoise(position) * amplitude;
		totalWeight += amplitude;
		position = position * 2.03 + vec2(7.1, 13.7);
		amplitude *= 0.5;
	}

	return value / totalWeight;
}

float directionalCoordinate(vec2 uv)
{
	float aspect = iResolution.x / iResolution.y;
	vec2 center = uCenter / iResolution.xy;
	vec2 position = (uv - center) * vec2(aspect, 1.0);
	vec2 axis = vec2(cos(uDirection), sin(uDirection));
	float halfExtent = 0.5 * (aspect * abs(axis.x) + abs(axis.y));
	return 0.5 + dot(position, axis) / max(2.0 * halfExtent, 0.0001);
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

	float aspect = iResolution.x / iResolution.y;
	vec2 center = uCenter / iResolution.xy;
	vec2 texturePosition = (uv - center) * vec2(aspect, 1.0) * uTextureScale;
	texturePosition += vec2(uSeed * 0.017, uSeed * 0.031);
	texturePosition += vec2(progress * 0.7, -progress * 0.43);

	float textureValue = fractalNoise(texturePosition);
	float fineTexture = leakNoise(texturePosition * 3.7 + progress * 4.0);
	float flicker = 1.0 + (fineTexture - 0.5) * uFlicker;
	vec4 color;

	if (uStyle == 0)
	{
		float field = directionalCoordinate(uv);
		field += (textureValue - 0.5) * uTexture * 0.35;

		float travelPadding = uWidth + uSoftness + uTexture * 0.18;
		float front = mix(-travelPadding, 1.0 + travelPadding, progress);
		float softness = max(uSoftness, 0.0001);
		float reveal = 1.0 - smoothstep(front - softness, front + softness, field);

		color = mixTransitionColors(fromColor, toColor, reveal);

		float distanceToFront = abs(field - front);
		float outerLight = 1.0 - smoothstep(0.0, max(uWidth, 0.001), distanceToFront);
		float hotLight = 1.0 - smoothstep(0.0, max(uWidth * 0.2, 0.001), distanceToFront);
		float lightEnvelope = smoothstep(0.0, 0.06, progress) * (1.0 - smoothstep(0.86, 1.0, progress));
		vec3 lightColor = mix(uLeakColor.rgb, uHotColor.rgb, hotLight);

		float light = (outerLight * 0.55 + hotLight) * uIntensity * flicker * lightEnvelope;
		// Gated by coverage: an additive term on .rgb alone leaves rgb above alpha,
		// which is not a valid premultiplied pixel. In In/Out mode one endpoint is
		// transparent, so ungated this paints onto transparent black.
		float coverage = max(fromColor.a, toColor.a);
		color.rgb += lightColor * light * coverage;
		color.rgb += uLeakColor.rgb * outerLight * uBloom * 0.45 * lightEnvelope * coverage;
	}
	else
	{
		float texturedProgress = progress + (textureValue - 0.5) * uTexture * 0.12;
		float reveal = smoothstep(0.38, 0.62, texturedProgress);
		float flash = pow(max(sin(progress * 3.14159265), 0.0), 0.65);
		float hotCore = pow(flash, 3.0);

		color = mixTransitionColors(fromColor, toColor, reveal);

		vec3 flashColor = mix(uLeakColor.rgb, uHotColor.rgb, hotCore);
		float mottling = mix(0.65, 1.25, textureValue);
		float exposure = flash * uIntensity * mottling * flicker;

		float coverage = max(fromColor.a, toColor.a);
		color.rgb += flashColor * exposure * coverage;
		color.rgb += uHotColor.rgb * flash * uBloom * 0.55 * coverage;
	}

	fragColor = color;
}