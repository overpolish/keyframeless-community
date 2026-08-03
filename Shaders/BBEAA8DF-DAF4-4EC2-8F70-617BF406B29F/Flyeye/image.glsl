// SPDX-FileCopyrightText: gre
// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template transition

// #percent label="Distortion" group={"Fly Eye", "camera.filters"} min=0 max=20 default=4
uniform float uSize;

// #float label="Frequency" group="Fly Eye" min=1 max=400 slidermax=200 default=50
uniform float uFrequency;

// #percent label="Colour Separation" group="Fly Eye" min=0 max=200 default=30
uniform float uColorSeparation;

// #choice label="Separate" group="Fly Eye" options="Outgoing,Incoming,Both" default=0
uniform int uSeparationTarget;

// #angle label="Rotation" group="Fly Eye" osc={z} default=0
uniform float uRotation;

// #multi label="Pattern Offset" group="Fly Eye" fields={X,Y} percent min=-100 max=100 default="0,0"
uniform vec2 uOffset;

// #bool label="Square Pattern" group="Fly Eye" default=0
uniform bool uSquarePattern;

// #choice label="Edges" group="Fly Eye" options="Clamp,Mirror,Repeat" default=0
uniform int uEdges;

vec2 rotate2(vec2 position, float angle)
{
	float sine = sin(angle);
	float cosine = cos(angle);
	return mat2(cosine, -sine, sine, cosine) * position;
}

vec2 resolveUV(vec2 uv)
{
	if (uEdges == 1)
		return 1.0 - abs(mod(uv, 2.0) - 1.0);

	if (uEdges == 2)
		return fract(uv);

	return clamp(uv, 0.0, 1.0);
}

vec2 flyDisplacement(vec2 uv)
{
	float aspect = iResolution.x / iResolution.y;
	vec2 metric = uSquarePattern ? vec2(aspect, 1.0) : vec2(1.0);
	vec2 position = (uv - 0.5) * metric;

	position = rotate2(position, uRotation);

	vec2 patternPosition = position + 0.5 * metric + uOffset * metric;
	vec2 localDisplacement = uSize * vec2(cos(uFrequency * patternPosition.x), sin(uFrequency * patternPosition.y));

	localDisplacement = rotate2(localDisplacement, -uRotation);
	return localDisplacement / metric;
}

vec4 sampleChannel(vec2 uv, int channel)
{
	vec2 sampleUV = resolveUV(uv);

	if (channel == 0)
		return texture(iChannel0, sampleUV);

	return texture(iChannel1, sampleUV);
}

vec4 separatedSample(vec2 uv, vec2 displacement, int channel, float separation)
{
	vec4 centerColor = sampleChannel(uv + displacement, channel);

	if (separation <= 0.0001)
		return centerColor;

	float red = sampleChannel(uv + displacement * (1.0 - separation), channel).r;
	float blue = sampleChannel(uv + displacement * (1.0 + separation), channel).b;

	return vec4(red, centerColor.g, blue, centerColor.a);
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

	float inverseProgress = 1.0 - progress;
	vec2 displacement = flyDisplacement(uv);

	float fromSeparation = uSeparationTarget == 0 || uSeparationTarget == 2 ? uColorSeparation : 0.0;
	float toSeparation = uSeparationTarget == 1 || uSeparationTarget == 2 ? uColorSeparation : 0.0;

	vec4 fromColor = separatedSample(uv, progress * displacement, 0, fromSeparation);
	vec4 toColor = separatedSample(uv, inverseProgress * displacement, 1, toSeparation);

	fragColor = mixTransitionColors(fromColor, toColor, progress);
}