// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template transition

// #motionblur on

// #angle label="Direction" group={"Motion", "wind"} osc={z} default=0
uniform float uDirection;

// #percent label="Travel" group="Motion" min=50 max=200 default=100
uniform float uTravel;

// #choice label="Edges" group="Motion" options="Mirror,Clamp,Repeat" default=0
uniform int uEdges;

// #percent label="Blend Width" group={"Transition", "arrow.triangle.2.circlepath"} min=0 max=100 default=35
uniform float uBlendWidth;

// #percent label="Peak Zoom" group={"Camera", "camera.filters"} min=100 max=150 default=106
uniform float uPeakZoom;

// #angle label="Roll" group="Camera" default=0
uniform float uRoll;

// #percent label="RGB Split" group={"Finish", "sparkles"} min=0 max=100 default=0
uniform float uRGBSplit;

// #percent label="Flash" group="Finish" min=0 max=100 default=0
uniform float uFlash;

// A whip is not a generic ease. The cubic ratio p^3/(p^3+(1-p)^3) leaves and
// arrives far slower than a smoothstep and crosses the middle far faster, which
// is the entire reason the pan reads as a whip rather than a slide. It stays
// baked in; the Progress lane rides on top of it.
float whipCurve(float progress)
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

vec4 sampleChannel(vec2 uv, int channel)
{
	vec2 sampleUV = resolveUV(uv);

	if (channel == 0)
		return texture(iChannel0, sampleUV);

	return texture(iChannel1, sampleUV);
}

vec4 chromaticSample(vec2 uv, vec2 offset, int channel)
{
	vec4 centerColor = sampleChannel(uv, channel);

	if (uRGBSplit <= 0.0001)
		return centerColor;

	float red = sampleChannel(uv + offset, channel).r;
	float blue = sampleChannel(uv - offset, channel).b;
	return vec4(red, centerColor.g, blue, centerColor.a);
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

	float progress = whipCurve(rampProgress);
	float aspect = iResolution.x / iResolution.y;
	vec2 metric = vec2(aspect, 1.0);
	vec2 axis = vec2(cos(uDirection), sin(uDirection));

	float frameSpan = aspect * abs(axis.x) + abs(axis.y);
	float travel = frameSpan * uTravel;
	float energy = sin(rampProgress * 3.14159265);

	vec2 fromOffset = axis * travel * progress;
	vec2 toOffset = axis * travel * (progress - 1.0);

	float scale = 1.0 + (uPeakZoom - 1.0) * energy;
	float fromRoll = uRoll * energy;
	float toRoll = -uRoll * energy;

	vec2 fromUV = transformedUV(uv, fromOffset, fromRoll, scale);
	vec2 toUV = transformedUV(uv, toOffset, toRoll, scale);

	vec2 chromaticOffset = axis / metric;
	chromaticOffset *= uRGBSplit * energy * 0.025;

	vec4 fromColor = chromaticSample(fromUV, chromaticOffset, 0);
	vec4 toColor = chromaticSample(toUV, -chromaticOffset, 1);

	float blend;

	if (uBlendWidth <= 0.0001)
		blend = step(0.5, progress);
	else
	{
		float halfWidth = 0.5 * uBlendWidth;
		blend = smoothstep(0.5 - halfWidth, 0.5 + halfWidth, progress);
	}

	vec4 color = mixTransitionColors(fromColor, toColor, blend);
	// Gated by coverage: an additive term on .rgb alone leaves rgb above alpha,
	// which is not a valid premultiplied pixel. In In/Out mode one endpoint is
	// transparent, so ungated this paints onto transparent black.
	color.rgb += uFlash * energy * max(fromColor.a, toColor.a);

	fragColor = color;
}