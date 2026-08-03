// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template transition

// #motionblur on

// #color label="Background" default="#08080C"
uniform vec4 uBackground;

// #choice label="Axis" group={"Card", "cube"} options="Left / Right,Up / Down" default=0
uniform int uAxis;

// #choice label="Direction" group="Card" options="Forward,Reverse" default=0
uniform int uDirection;

// #point label="Hinge" group="Card" osc=position default="0.5,0.5"
uniform vec2 uPivot;

// #angle label="Rotation" group="Card" default=90
uniform float uRotation;

// #percent label="Perspective" group="Card" min=0 max=100 default=60
uniform float uPerspective;

// #percent label="Card Scale" group="Card" min=50 max=150 default=100
uniform float uCardScale;

// #percent label="Corner Radius" group="Card" min=0 max=50 default=0
uniform float uCornerRadius;

// #percent label="Handoff Gap" group={"Timing", "clock"} min=0 max=40 default=0
uniform float uGap;

// #percent label="Edge Shadow" group={"Lighting", "sun.max"} min=0 max=100 default=45
uniform float uShadow;

// #percent label="Sheen" group="Lighting" min=0 max=100 default=15
uniform float uSheen;

// Each half of the flip eases in its own local span, so the plate settles as it
// reaches edge-on instead of snapping through the handoff. That is the card's
// look, not generic timing: the Progress lane shapes the whole sweep and cannot
// reach inside a per-half remap.
float shapeProgress(float progress)
{
	return progress * progress * (3.0 - 2.0 * progress);
}

float roundedBoxDistance(vec2 position, vec2 halfSize, float radius)
{
	radius = min(radius, min(halfSize.x, halfSize.y));
	vec2 distance = abs(position) - halfSize + radius;
	return length(max(distance, 0.0)) + min(max(distance.x, distance.y), 0.0) - radius;
}

vec2 inverseCardProjection(vec2 screenPosition, float angle, out float valid)
{
	float sine = sin(angle);
	float cosine = cos(angle);
	float perspective = uPerspective * 1.2;
	vec2 planePosition;

	if (uAxis == 0)
	{
		float denominator = cosine - screenPosition.x * perspective * sine;
		valid = step(0.0001, abs(denominator));
		planePosition.x = screenPosition.x / (abs(denominator) < 0.0001 ? 0.0001 : denominator);
		float depth = 1.0 + planePosition.x * perspective * sine;
		planePosition.y = screenPosition.y * depth;
	}
	else
	{
		float denominator = cosine - screenPosition.y * perspective * sine;
		valid = step(0.0001, abs(denominator));
		planePosition.y = screenPosition.y / (abs(denominator) < 0.0001 ? 0.0001 : denominator);
		float depth = 1.0 + planePosition.y * perspective * sine;
		planePosition.x = screenPosition.x * depth;
	}

	valid *= step(0.0, cosine);
	return planePosition;
}

vec4 cardFrame(vec2 uv, float angle, int channel, out float mask)
{
	float aspect = iResolution.x / iResolution.y;
	vec2 pivot = uPivot / iResolution.xy;
	vec2 screenPosition = (uv - pivot) * vec2(aspect, 1.0);
	screenPosition /= max(uCardScale, 0.01);

	float projectionValid;
	vec2 planePosition = inverseCardProjection(screenPosition, angle, projectionValid);
	vec2 sampleUV = pivot + planePosition / vec2(aspect, 1.0);

	vec2 inBounds = step(vec2(0.0), sampleUV) * step(sampleUV, vec2(1.0));
	mask = inBounds.x * inBounds.y * projectionValid;

	if (uCornerRadius > 0.0001)
	{
		vec2 cardPosition = (sampleUV - 0.5) * vec2(aspect, 1.0);
		vec2 halfSize = vec2(0.5 * aspect, 0.5);
		float radius = uCornerRadius * min(halfSize.x, halfSize.y);
		float distance = roundedBoxDistance(cardPosition, halfSize, radius);
		float antialiasing = max(fwidth(distance), 1.0 / iResolution.y);
		mask *= 1.0 - smoothstep(-antialiasing, antialiasing, distance);
	}

	vec4 color;

	if (channel == 0)
		color = texture(iChannel0, clamp(sampleUV, 0.0, 1.0));
	else
		color = texture(iChannel1, clamp(sampleUV, 0.0, 1.0));

	float edgeAmount = abs(sin(angle));
	float lighting = 1.0 - uShadow * edgeAmount;
	float sheenPosition = uAxis == 0 ? sampleUV.x : sampleUV.y;
	float sheen = uSheen * edgeAmount * smoothstep(0.0, 1.0, sheenPosition);

	color.rgb *= lighting;
	color.rgb += sheen;

	return color;
}

vec4 compositeCard(vec4 card, float mask)
{
	float cardAlpha = card.a * mask;
	float backgroundAlpha = iTransitionMode == 0 ? uBackground.a : 0.0;
	float outputAlpha = cardAlpha + backgroundAlpha * (1.0 - cardAlpha);
	vec3 premultiplied = card.rgb * cardAlpha + uBackground.rgb * backgroundAlpha * (1.0 - cardAlpha);
	vec3 outputColor = outputAlpha > 0.0001 ? premultiplied / outputAlpha : vec3(0.0);
	return vec4(outputColor, outputAlpha);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;
	float progress = clamp(iProgress, 0.0, 1.0);

	if (progress <= 0.0)
	{
		fragColor = texture(iChannel0, uv);
		return;
	}

	if (progress >= 1.0)
	{
		fragColor = texture(iChannel1, uv);
		return;
	}

	float halfGap = uGap * 0.5;
	float outgoingEnd = max(0.5 - halfGap, 0.001);
	float incomingStart = min(0.5 + halfGap, 0.999);
	float direction = uDirection == 0 ? 1.0 : -1.0;
	float rotation = abs(uRotation);

	float angle;
	int channel;

	if (progress < 0.5)
	{
		float localProgress = shapeProgress(clamp(progress / outgoingEnd, 0.0, 1.0));
		angle = direction * rotation * localProgress;
		channel = 0;
	}
	else
	{
		float localProgress = shapeProgress(clamp((progress - incomingStart) / max(1.0 - incomingStart, 0.001), 0.0, 1.0));
		angle = direction * rotation * (localProgress - 1.0);
		channel = 1;
	}

	float mask;
	vec4 card = cardFrame(uv, angle, channel, mask);
	fragColor = compositeCard(card, mask);
}