// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template filter

// #choice label="Mode" group={"Blur", "drop.halffull"} options="Gaussian,Defocus,Directional,Zoom,Spin,Tilt Shift" default=0
uniform int uMode;

// #float label="Radius" group="Blur" units="px" osc=ring link=uCenter min=0 max=300 slidermax=100 default=20 visibleby=uMode visiblevalues={0,1,2,5}
uniform float uRadius;

// #percent label="Strength" group="Blur" min=0 max=100 default=20 visibleby=uMode visiblevalues={3,4}
uniform float uStrength;

// #choice label="Aperture" group="Blur" options="Circle,Hexagon,Octagon" default=0 visibleby=uMode visiblevalues={1}
uniform int uAperture;

// #choice label="Quality" group="Blur" options="Draft,Standard,High" default=1
uniform int uQuality;

// #choice label="Edges" group="Blur" options="Clamp,Mirror,Repeat" default=1
uniform int uEdges;

// #point label="Center" group={"Geometry", "viewfinder"} osc=position default="0.5,0.5"
uniform vec2 uCenter;

// #angle label="Direction" group="Geometry" osc={z} default=0 visibleby=uMode visiblevalues={2,5}
uniform float uDirection;

// #percent label="Focus Width" group="Geometry" min=0 max=100 default=25 visibleby=uMode visiblevalues={5}
uniform float uFocusWidth;

// #percent label="Feather" group="Geometry" min=0 max=100 default=15 visibleby=uMode visiblevalues={5}
uniform float uFeather;

// #percent label="Mix" group={"Finish", "slider.horizontal.3"} min=0 max=100 default=100
uniform float uMix;

const float BLUR_PI = 3.14159265359;
const float BLUR_TAU = 6.28318530718;
const float BLUR_GOLDEN_ANGLE = 2.39996322973;

vec2 mirrorUV(vec2 uv)
{
	return 1.0 - abs(mod(uv, 2.0) - 1.0);
}

vec2 resolveUV(vec2 uv)
{
	if (uEdges == 1)
		return mirrorUV(uv);
	if (uEdges == 2)
		return fract(uv);
	return clamp(uv, 0.0, 1.0);
}

vec4 sampleSource(vec2 pixelPosition)
{
	return texture(iChannel0, resolveUV(pixelPosition / iResolution.xy));
}

vec2 rotateVector(vec2 value, float angle)
{
	float sine = sin(angle);
	float cosine = cos(angle);
	return mat2(cosine, -sine, sine, cosine) * value;
}

float apertureBoundary(float angle, int aperture)
{
	if (aperture == 0)
		return 1.0;

	float sides = aperture == 1 ? 6.0 : 8.0;
	float sector = BLUR_TAU / sides;
	float localAngle = mod(angle + 0.5 * sector, sector) - 0.5 * sector;
	return cos(BLUR_PI / sides) / max(cos(localAngle), 0.001);
}

float tiltShiftAmount(vec2 pixelPosition)
{
	vec2 lineDirection = vec2(cos(uDirection), sin(uDirection));
	vec2 lineNormal = vec2(-lineDirection.y, lineDirection.x);
	float distanceFromLine = abs(dot(pixelPosition - uCenter, lineNormal));
	float halfWidth = 0.5 * uFocusWidth * iResolution.y;
	float feather = max(uFeather * iResolution.y, 1.0);
	return smoothstep(halfWidth, halfWidth + feather, distanceFromLine);
}

int blurTapCount()
{
	if (uQuality == 0)
		return 12;
	if (uQuality == 2)
		return 48;
	return 24;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec4 source = texture(iChannel0, fragCoord / iResolution.xy);

	float localRadius = uRadius;
	if (uMode == 5)
		localRadius *= tiltShiftAmount(fragCoord);

	bool radialMode = uMode == 3 || uMode == 4;
	if (uMix <= 0.0 || (!radialMode && localRadius <= 0.001) ||
	        (radialMode && uStrength <= 0.00001))
	{
		fragColor = source;
		return;
	}

	int tapCount = blurTapCount();
	vec4 accumulated = source;
	float totalWeight = 1.0;
	vec2 direction = vec2(cos(uDirection), sin(uDirection));

	for (int index = 0; index < 48; ++index)
	{
		if (index >= tapCount)
			break;

		float fraction = (float(index) + 0.5) / float(tapCount);
		vec2 samplePosition = fragCoord;
		float weight = 1.0;

		if (uMode == 0 || uMode == 1 || uMode == 5)
		{
			float radialFraction = sqrt(fraction);
			float angle = float(index) * BLUR_GOLDEN_ANGLE;
			float aperture = uMode == 1 ? apertureBoundary(angle, uAperture) : 1.0;
			vec2 offset = vec2(cos(angle), sin(angle)) *
			              radialFraction * aperture * localRadius;
			samplePosition += offset;

			if (uMode != 1)
				weight = exp(-2.5 * radialFraction * radialFraction);
		}
		else if (uMode == 2)
		{
			float linePosition = fraction * 2.0 - 1.0;
			samplePosition += direction * linePosition * localRadius;
			weight = exp(-2.5 * linePosition * linePosition);
		}
		else if (uMode == 3)
		{
			float zoom = fraction * uStrength * 0.85;
			samplePosition = mix(fragCoord, uCenter, zoom);
			weight = 1.0 - 0.45 * fraction;
		}
		else
		{
			float spinPosition = fraction * 2.0 - 1.0;
			float angle = spinPosition * uStrength * 0.45;
			samplePosition = uCenter + rotateVector(fragCoord - uCenter, angle);
			weight = exp(-1.5 * spinPosition * spinPosition);
		}

		accumulated += sampleSource(samplePosition) * weight;
		totalWeight += weight;
	}

	vec4 blurred = accumulated / max(totalWeight, 0.0001);
	fragColor = mix(source, blurred, uMix);
}