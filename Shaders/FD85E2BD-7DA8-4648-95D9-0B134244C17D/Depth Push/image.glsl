// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template transition

// #motionblur on

// #color label="Shadow Colour" default="#000000"
uniform vec4 uShadowColor;

// #choice label="Front Layer" group={"Depth", "cube"} options="Outgoing,Incoming" default=0
uniform int uFrontLayer;

// #angle label="Direction" group="Depth" osc={z} default=0
uniform float uDirection;

// #percent label="Travel" group="Depth" min=50 max=200 default=100
uniform float uTravel;

// #percent label="Parallax" group="Depth" min=0 max=100 default=28
uniform float uParallax;

// #percent label="Depth" group="Depth" min=0 max=200 default=65
uniform float uDepth;

// #angle label="Roll" group="Depth" default=3
uniform float uRoll;

// #percent label="Corner Radius" group="Depth" min=0 max=50 default=0
uniform float uCornerRadius;

// #choice label="Edges" group="Depth" options="Mirror,Clamp,Repeat" default=0
uniform int uEdges;

// #percent label="Shadow" group={"Shadow", "circle.lefthalf.filled"} min=0 max=100 default=55
uniform float uShadow;

// #int label="Shadow Distance" group="Shadow" units="px" min=0 slidermax=100 default=18
uniform float uShadowDistance;

// #int label="Shadow Blur" group="Shadow" units="px" min=0 slidermax=100 default=30
uniform float uShadowBlur;

// The push accelerates hard out of the cut and settles slowly into it. That
// asymmetry against a plain smoothstep is what makes the move read as a camera
// rather than a crossfade, so it stays baked in and the Progress lane rides on
// top of it.
float cinematicCurve(float progress)
{
	float forward = progress * progress * progress;
	float reverse = (1.0 - progress) * (1.0 - progress) * (1.0 - progress);
	return forward / max(forward + reverse, 0.0001);
}

vec2 rotate2(vec2 position, float angle)
{
	float sine = sin(angle);
	float cosine = cos(angle);
	return mat2(cosine, -sine, sine, cosine) * position;
}

vec2 resolveUV(vec2 uv)
{
	if (uEdges == 1)
		return clamp(uv, 0.0, 1.0);

	if (uEdges == 2)
		return fract(uv);

	return 1.0 - abs(mod(uv, 2.0) - 1.0);
}

vec2 transformedUV(vec2 uv, vec2 visualOffset, float rotation, float scale)
{
	float aspect = iResolution.x / iResolution.y;
	vec2 metric = vec2(aspect, 1.0);
	vec2 position = (uv - 0.5) * metric;

	position -= visualOffset;
	position = rotate2(position, -rotation);
	position /= max(scale, 0.001);

	return position / metric + 0.5;
}

float roundedBoxDistance(vec2 position, vec2 halfSize, float radius)
{
	radius = min(radius, min(halfSize.x, halfSize.y));
	vec2 distance = abs(position) - halfSize + radius;
	return length(max(distance, 0.0)) + min(max(distance.x, distance.y), 0.0) - radius;
}

float cardDistance(vec2 sampleUV)
{
	float aspect = iResolution.x / iResolution.y;
	vec2 position = (sampleUV - 0.5) * vec2(aspect, 1.0);
	vec2 halfSize = vec2(0.5 * aspect, 0.5);
	float radius = uCornerRadius * min(halfSize.x, halfSize.y);
	return roundedBoxDistance(position, halfSize, radius);
}

vec4 sampleChannel(vec2 uv, int channel)
{
	vec2 sampleUV = resolveUV(uv);

	if (channel == 0)
		return texture(iChannel0, sampleUV);

	return texture(iChannel1, sampleUV);
}

vec4 compositeForeground(vec4 background, vec4 foreground, float mask)
{
	float foregroundAlpha = foreground.a * mask;
	float outputAlpha = foregroundAlpha + background.a * (1.0 - foregroundAlpha);
	vec3 premultiplied = foreground.rgb * foregroundAlpha;
	premultiplied += background.rgb * background.a * (1.0 - foregroundAlpha);
	vec3 outputColor = outputAlpha > 0.0001 ? premultiplied / outputAlpha : vec3(0.0);
	return vec4(outputColor, outputAlpha);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;
	float rampProgress = clamp(iProgress, 0.0, 1.0);

	if (rampProgress <= 0.0)
	{
		fragColor = texture(iChannel0, uv);
		return;
	}

	if (rampProgress >= 1.0)
	{
		fragColor = texture(iChannel1, uv);
		return;
	}

	float progress = cinematicCurve(rampProgress);
	float aspect = iResolution.x / iResolution.y;
	vec2 axis = vec2(cos(uDirection), sin(uDirection));
	float frameSpan = aspect * abs(axis.x) + abs(axis.y);
	float energy = sin(rampProgress * 3.14159265);

	vec2 foregroundOffset;
	vec2 backgroundOffset;
	float foregroundScale;
	float backgroundScale;
	float foregroundRotation;
	int foregroundChannel;
	int backgroundChannel;

	if (uFrontLayer == 0)
	{
		foregroundOffset = axis * frameSpan * uTravel * progress;
		backgroundOffset = -axis * frameSpan * uParallax * (1.0 - progress);
		foregroundScale = 1.0 + uDepth * 0.14 * progress;
		backgroundScale = mix(1.0 - uDepth * 0.18, 1.0, progress);
		foregroundRotation = uRoll * energy;
		foregroundChannel = 0;
		backgroundChannel = 1;
	}
	else
	{
		foregroundOffset = -axis * frameSpan * uTravel * (1.0 - progress);
		backgroundOffset = axis * frameSpan * uParallax * progress;
		foregroundScale = mix(1.0 + uDepth * 0.14, 1.0, progress);
		backgroundScale = mix(1.0, 1.0 - uDepth * 0.18, progress);
		foregroundRotation = -uRoll * energy;
		foregroundChannel = 1;
		backgroundChannel = 0;
	}

	vec2 backgroundUV = transformedUV(uv, backgroundOffset, 0.0, backgroundScale);
	vec4 background = sampleChannel(backgroundUV, backgroundChannel);

	vec2 foregroundUV = transformedUV(uv, foregroundOffset, foregroundRotation, foregroundScale);
	vec4 foreground = sampleChannel(foregroundUV, foregroundChannel);

	float foregroundDistance = cardDistance(foregroundUV);
	float foregroundAA = max(fwidth(foregroundDistance), 1.0 / iResolution.y);
	float foregroundMask = 1.0 - smoothstep(-foregroundAA, foregroundAA, foregroundDistance);

	vec2 shadowOffset = -axis * uShadowDistance / 1080.0;
	vec2 shadowUV = transformedUV(uv, foregroundOffset + shadowOffset, foregroundRotation, foregroundScale * 1.01);
	float shadowDistance = cardDistance(shadowUV);
	float shadowBlur = max(uShadowBlur / 1080.0, 0.0001);
	float shadowMask = 1.0 - smoothstep(-shadowBlur, shadowBlur, shadowDistance);
	shadowMask *= 1.0 - foregroundMask;
	shadowMask *= uShadow * uShadowColor.a * energy;

	background = compositeForeground(background, uShadowColor, shadowMask);
	fragColor = compositeForeground(background, foreground, foregroundMask);
}
