// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template generator

// #alpha
// #motionblur off

// #audio label="Audio" gate=-60 release=0.16 smooth=0.08 flow flowlo=0 flowhi=63 flowgate=-55
uniform vec4 uAudio[16];

// #choice label="Style" group={"Spectrum", "waveform"} options="Smooth Wave,Bars,Needles" default=0
uniform int uStyle;

// #choice label="Listen To" group={"Response", "ear"} options="Full Mix,Bass,Voice,Highs" default=0
uniform int uListen;

// #percent label="Sensitivity" group="Response" min=10 max=100 default=75
uniform float uSensitivity;

// #float label="Punch" group="Response" min=0.5 max=5 default=1.6
uniform float uPunch;

// #percent label="Smoothness" group="Response" min=0 max=100 default=65
uniform float uSmoothness;

// #percent label="High Boost" group="Response" min=0 max=200 default=45
uniform float uHighBoost;

// #percent label="Floor" group="Response" min=0 max=30 default=2
uniform float uFloor;

// #percent label="Height" group="Spectrum" min=0 max=100 default=70
uniform float uHeight;

// #percent label="Colour Layers" group="Spectrum" min=0 max=100 default=100 visibleby=uStyle visiblevalues={0}
uniform float uColourLayers;

// #percent label="Layer Spread" group="Spectrum" min=0 max=100 default=18 visibleby=uStyle visiblevalues={0}
uniform float uLayerSpread;

// #int label="Detail" group="Spectrum" min=16 max=128 default=64 visibleby=uStyle visiblevalues={1,2}
uniform int uDetail;

// #float label="Thickness" group="Spectrum" units="px" min=1 max=40 default=5 visibleby=uStyle visiblevalues={2}
uniform float uThickness;

// #percent label="Bar Width" group="Spectrum" min=10 max=100 default=70 visibleby=uStyle visiblevalues={1,2}
uniform float uBarWidth;

// #percent label="Bass Pulse" group="Spectrum" min=0 max=100 default=12
uniform float uBassPulse;

// #percent label="Glow" group={"Appearance", "sparkles"} min=0 max=100 default=35
uniform float uGlow;

// #choice label="Background" group="Appearance" options="Transparent,Colour,Source Clip" default=0
uniform int uBackground;

// #percent label="Background Dim" group="Appearance" min=0 max=100 default=20 visibleby=uBackground visiblevalues={2}
uniform float uBackgroundDim;

// #choice label="Center Fill" group="Appearance" options="Background,Colour,Source Clip,Transparent" default=0
uniform int uCenterFill;

// #bool label="Particles" group="Appearance" default=true
uniform bool uParticles;

// #int label="Count" group={"Particles", "sparkles"} min=8 max=160 default=96 visibleby=uParticles visiblevalues={1}
uniform int uParticleCount;

// #float label="Size" group="Particles" units="px" min=1 max=12 default=1 visibleby=uParticles visiblevalues={1}
uniform float uParticleSize;

// #percent label="Brightness" group="Particles" min=0 max=200 default=50 visibleby=uParticles visiblevalues={1}
uniform float uParticleBrightness;

// #percent label="Drift" group="Particles" min=0 max=100 default=18 visibleby=uParticles visiblevalues={1}
uniform float uParticleDrift;

// #percent label="Audio Push" group="Particles" min=0 max=200 default=70 visibleby=uParticles visiblevalues={1}
uniform float uParticlePush;

// #point label="Center" group={"Transform", "viewfinder"} osc=position default="0.5,0.5"
uniform vec2 uCenter;

// #percent label="Radius" group="Transform" min=5 max=48 default=28 osc=ring link=uCenter
uniform float uRadius;

// #angle label="Rotation" group="Transform" default=0 osc={z} link=uCenter
uniform float uRotation;

// Smooth Wave only. Bars and Needles take their colour from the Frequency
// Colours palette below and ignore this swatch.
// #color label="Main Wave" default="#FFFFFF"
uniform vec4 uMainColor;

// Read BOTH ways: as a ramp along the spectrum, and as discrete indexed
// swatches with per-stop alpha in the layer loop. A #gradient can only do the
// first.
// #color label="Frequency Colours" min=2 max=5 default="#FF3158,#FFD600,#34E26F,#20BFFF,#925CFF"
uniform vec4 uColours[5];

// #color label="Background Colour" default="#080A12"
uniform vec4 uBackgroundColor;

// #color label="Center Colour" default="#080A12"
uniform vec4 uCenterColor;

const float TAU = 6.28318530718;
const int MAX_PARTICLES = 160;

float hash11(float value)
{
	return fract(sin(value * 127.1) * 43758.5453);
}

vec3 spectrumPalette(float position)
{
	int count = max(uColoursCount, 1);

	if (count == 1)
		return uColours[0].rgb;

	float paletteIndex = clamp(position, 0.0, 1.0) * float(count - 1);
	int lower = int(floor(paletteIndex));
	int upper = min(lower + 1, count - 1);

	return mix(uColours[lower].rgb, uColours[upper].rgb, fract(paletteIndex));
}

void listeningRange(out float rangeStart, out float rangeEnd)
{
	rangeStart = 0.0;
	rangeEnd = 1.0;

	if (uListen == 1)
	{
		rangeStart = 0.0;
		rangeEnd = 0.22;
	}
	else if (uListen == 2)
	{
		rangeStart = 0.16;
		rangeEnd = 0.68;
	}
	else if (uListen == 3)
	{
		rangeStart = 0.5;
		rangeEnd = 1.0;
	}
}

void frequencyRange(
    int layer,
    int count,
    out float rangeStart,
    out float rangeEnd,
    out float gain,
    out float layerPosition
)
{
	layerPosition = count > 1
	                ? float(layer) / float(count - 1)
	                : 0.5;

	float center = mix(0.06, 0.9, layerPosition);
	float halfWidth = mix(0.2, 0.12, layerPosition);

	rangeStart = max(center - halfWidth, 0.0);
	rangeEnd = min(center + halfWidth, 1.0);
	gain = mix(1.4, 0.8 + uHighBoost * 0.2, layerPosition);
}

float interpolatedBandRange(float position, float rangeStart, float rangeEnd)
{
	float bandPosition = mix(rangeStart, rangeEnd, clamp(position, 0.0, 1.0));
	float bandIndex = bandPosition * float(max(uAudioBands - 1, 0));
	int band = int(floor(bandIndex));
	float blend = fract(bandIndex);

	int i0 = clamp(band - 1, 0, uAudioBands - 1);
	int i1 = clamp(band, 0, uAudioBands - 1);
	int i2 = clamp(band + 1, 0, uAudioBands - 1);
	int i3 = clamp(band + 2, 0, uAudioBands - 1);

	float a = uAudioBand(i0);
	float b = uAudioBand(i1);
	float c = uAudioBand(i2);
	float d = uAudioBand(i3);

	float blend2 = blend * blend;
	float blend3 = blend2 * blend;

	float value = 0.5 * (
	                  2.0 * b +
	                  (-a + c) * blend +
	                  (2.0 * a - 5.0 * b + 4.0 * c - d) * blend2 +
	                  (-a + 3.0 * b - 3.0 * c + d) * blend3
	              );

	return max(value, 0.0);
}

float smoothedBandRange(float position, float rangeStart, float rangeEnd)
{
	float selectedBands = max(
	                          (rangeEnd - rangeStart) * float(max(uAudioBands - 1, 1)),
	                          1.0
	                      );

	float sampleStep = uSmoothness / selectedBands;
	float value = interpolatedBandRange(position, rangeStart, rangeEnd) * 4.0;

	value += interpolatedBandRange(clamp(position - sampleStep, 0.0, 1.0), rangeStart, rangeEnd) * 3.0;
	value += interpolatedBandRange(clamp(position + sampleStep, 0.0, 1.0), rangeStart, rangeEnd) * 3.0;
	value += interpolatedBandRange(clamp(position - sampleStep * 2.0, 0.0, 1.0), rangeStart, rangeEnd) * 2.0;
	value += interpolatedBandRange(clamp(position + sampleStep * 2.0, 0.0, 1.0), rangeStart, rangeEnd) * 2.0;
	value += interpolatedBandRange(clamp(position - sampleStep * 3.0, 0.0, 1.0), rangeStart, rangeEnd);
	value += interpolatedBandRange(clamp(position + sampleStep * 3.0, 0.0, 1.0), rangeStart, rangeEnd);

	return value / 16.0;
}

float shapeResponse(float level, float gain)
{
	float threshold = 1.0 - uSensitivity;
	level = max(level * gain - threshold, 0.0) / max(uSensitivity, 0.001);

	return pow(level, 1.0 / max(uPunch, 0.001));
}

float spectrumLevel(float position)
{
	float rangeStart;
	float rangeEnd;
	listeningRange(rangeStart, rangeEnd);

	float level = smoothedBandRange(position, rangeStart, rangeEnd);
	level *= mix(1.0, 1.0 + position * 2.0, uHighBoost);

	return max(shapeResponse(level, 1.0), uFloor);
}

float frequencyLayer(float position, int layer, int count)
{
	float rangeStart;
	float rangeEnd;
	float gain;
	float layerPosition;

	frequencyRange(
	    layer,
	    count,
	    rangeStart,
	    rangeEnd,
	    gain,
	    layerPosition
	);

	float level = smoothedBandRange(position, rangeStart, rangeEnd);

	return max(shapeResponse(level, gain), 0.0);
}

float frequencyLayerPeak(int layer, int count)
{
	float rangeStart;
	float rangeEnd;
	float gain;
	float layerPosition;

	frequencyRange(
	    layer,
	    count,
	    rangeStart,
	    rangeEnd,
	    gain,
	    layerPosition
	);

	float peak = 0.0;
	peak = max(peak, interpolatedBandRange(0.0625, rangeStart, rangeEnd));
	peak = max(peak, interpolatedBandRange(0.1875, rangeStart, rangeEnd));
	peak = max(peak, interpolatedBandRange(0.3125, rangeStart, rangeEnd));
	peak = max(peak, interpolatedBandRange(0.4375, rangeStart, rangeEnd));
	peak = max(peak, interpolatedBandRange(0.5625, rangeStart, rangeEnd));
	peak = max(peak, interpolatedBandRange(0.6875, rangeStart, rangeEnd));
	peak = max(peak, interpolatedBandRange(0.8125, rangeStart, rangeEnd));
	peak = max(peak, interpolatedBandRange(0.9375, rangeStart, rangeEnd));

	return max(shapeResponse(peak, gain), 0.001);
}

float bassLevel()
{
	int count = min(uAudioBands, 8);
	float bass = 0.0;

	for (int i = 0; i < 8; ++i)
	{
		if (i >= count)
			break;

		bass = max(bass, uAudioBand(i));
	}

	return shapeResponse(bass, 1.0);
}

float overallAudioLevel()
{
	float level = 0.0;

	for (int i = 0; i < 8; ++i)
	{
		int band = int(float(i) * float(max(uAudioBands - 1, 0)) / 7.0);
		level += uAudioBand(band);
	}

	return level / 8.0;
}

float filledWave(float radius, float innerRadius, float outerRadius, float aa)
{
	float inner = smoothstep(innerRadius - aa, innerRadius + aa, radius);
	float outer = 1.0 - smoothstep(outerRadius - aa, outerRadius + aa, radius);

	return inner * outer;
}

vec4 over(vec4 foreground, vec4 background)
{
	float alpha = foreground.a + background.a * (1.0 - foreground.a);
	vec3 premultiplied = foreground.rgb * foreground.a;
	premultiplied += background.rgb * background.a * (1.0 - foreground.a);
	vec3 rgb = alpha > 0.0001 ? premultiplied / alpha : vec3(0.0);

	return vec4(rgb, alpha);
}

vec4 particleLayer(vec2 p, float baseRadius)
{
	if (!uParticles)
		return vec4(0.0);

	float aspect = iResolution.x / iResolution.y;
	float frameRadius = 0.5 * length(vec2(aspect, 1.0));
	float audio = overallAudioLevel();
	float size = max(uParticleSize / iResolution.y, 0.0005);

	float opacity = 0.0;
	vec3 premultiplied = vec3(0.0);

	for (int i = 0; i < MAX_PARTICLES; ++i)
	{
		if (i >= uParticleCount)
			break;

		float index = float(i);
		float angle = hash11(index * 17.31 + 2.7) * TAU;
		float phase = hash11(index * 29.73 + 8.1);
		float variation = mix(0.65, 1.35, hash11(index * 41.17 + 3.9));

		float travel =
		    iTime * uParticleDrift * 0.11 * variation +
		    uAudioFlow * uParticlePush * 0.1 * variation;

		float life = fract(phase + travel);
		float radius = mix(baseRadius * 1.05, frameRadius * 1.15, life);
		float wander = sin(iTime * 0.35 + index * 1.7) * 0.08 * life;

		vec2 direction = vec2(cos(angle + wander), sin(angle + wander));
		vec2 delta = p - direction * radius;
		float distanceToParticle = length(delta);

		float core = exp(
		                 -distanceToParticle * distanceToParticle /
		                 max(size * size, 1e-7)
		             );

		float haloSize = size * mix(2.5, 5.0, hash11(index + 11.2));
		float halo = exp(
		                 -distanceToParticle * distanceToParticle /
		                 max(haloSize * haloSize, 1e-7)
		             ) * 0.28;

		float horizontalFlare =
		    exp(-abs(delta.y) / max(size * 0.35, 1e-5)) *
		    exp(-abs(delta.x) / max(size * 4.0, 1e-5)) *
		    0.18;

		float verticalFlare =
		    exp(-abs(delta.x) / max(size * 0.35, 1e-5)) *
		    exp(-abs(delta.y) / max(size * 4.0, 1e-5)) *
		    0.18;

		float fade = smoothstep(0.0, 0.035, life);
		fade *= 1.0 - smoothstep(0.88, 1.0, life);

		float twinkle = 0.75 +
		                0.25 * sin(iTime * variation * 4.0 + index * 3.7);

		float brightness = core + halo + horizontalFlare + verticalFlare;
		brightness *= fade * twinkle * uParticleBrightness;
		brightness *= mix(0.75, 2.0, audio);

		vec3 colour = mix(
		                  vec3(1.0),
		                  spectrumPalette(hash11(index + 61.3)),
		                  0.22
		              );

		premultiplied += colour * brightness;
		opacity += brightness;
	}

	float alpha = clamp(opacity, 0.0, 1.0);
	vec3 rgb = alpha > 0.0001 ? premultiplied / alpha : vec3(0.0);

	return vec4(rgb, alpha);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 resolution = iResolution.xy;
	vec2 uv = fragCoord / resolution;
	vec2 p = (fragCoord - uCenter) / resolution.y;

	float distanceFromCenter = length(p);
	// x before y on purpose: it measures the bearing from 12 o'clock, which is
	// where every preset expects band zero. Swapping the arguments rotates the
	// whole spectrum by 90 degrees.
	float angle = atan(p.x, p.y) + uRotation;
	float anglePosition = fract(angle / TAU);
	// Cosine rather than the raw angle, so the spectrum runs out to one side
	// and back rather than wrapping once and meeting itself at a seam.
	float mirroredPosition = 0.5 - 0.5 * cos(angle);

	float detail = float(max(uDetail, 1));

	if (uStyle != 0)
	{
		float segment = floor(anglePosition * detail);
		float segmentAngle = (segment + 0.5) * TAU / detail;
		mirroredPosition = 0.5 - 0.5 * cos(segmentAngle);
	}

	// Height is measured against the half-frame, so 100% reaches 0.2 of it and
	// the tallest band at the default radius stops just inside the top edge.
	float height = uHeight * 0.2;
	float level = spectrumLevel(mirroredPosition);
	float baseRadius = uRadius + bassLevel() * uBassPulse * 0.08;
	float spectrumHeight = level * height;
	float outerRadius = baseRadius + spectrumHeight;
	float thickness = max(uThickness / resolution.y, 0.0005);
	float edgeAA = max(fwidth(distanceFromCenter - outerRadius), 0.75 / resolution.y);
	float glowSize = max(5.0 / resolution.y, 0.0005);

	float shape = 0.0;
	float glowDistance = 0.0;

	if (uStyle == 0)
	{
		shape = filledWave(distanceFromCenter, baseRadius, outerRadius, edgeAA);
		glowDistance = abs(distanceFromCenter - outerRadius);
	}
	else
	{
		float segmentPosition = fract(anglePosition * detail) - 0.5;
		float angularWidth = TAU / detail;
		float middleRadius = 0.5 * (baseRadius + outerRadius);

		float tangentialDistance = abs(segmentPosition) *
		                           angularWidth *
		                           max(middleRadius, 0.001);

		float halfWidth = 0.5 *
		                  angularWidth *
		                  middleRadius *
		                  uBarWidth;

		float innerRadius = baseRadius;

		if (uStyle == 2)
		{
			innerRadius = max(baseRadius - thickness * 1.5, 0.0);
			halfWidth *= 0.32;
		}

		float radialDistance = max(
		                           innerRadius - distanceFromCenter,
		                           distanceFromCenter - outerRadius
		                       );

		float sideDistance = tangentialDistance - halfWidth;
		float barDistance = max(radialDistance, sideDistance);
		float aa = max(fwidth(barDistance), 0.5 / resolution.y);

		shape = 1.0 - smoothstep(0.0, aa, barDistance);
		glowDistance = max(barDistance, 0.0);
	}

	vec4 source = texture(iChannel0, uv);
	vec4 background = vec4(0.0);

	if (uBackground == 1)
		background = uBackgroundColor;
	else if (uBackground == 2)
		background = vec4(source.rgb * (1.0 - uBackgroundDim), source.a);

	vec4 result = over(particleLayer(p, baseRadius), background);

	float centerAA = max(fwidth(distanceFromCenter), 1.0 / resolution.y);
	float centerMask = 1.0 - smoothstep(
	                       baseRadius - centerAA,
	                       baseRadius + centerAA,
	                       distanceFromCenter
	                   );

	vec4 center = vec4(0.0);

	if (uCenterFill == 0)
		center = background;
	else if (uCenterFill == 1)
		center = uCenterColor;
	else if (uCenterFill == 2)
		center = source;

	center.a *= centerMask;
	result = over(center, result);

	if (uStyle == 0 && uColourLayers > 0.0)
	{
		int colourCount = max(uColoursCount, 1);
		float bassPeak = max(
		                     frequencyLayerPeak(0, colourCount),
		                     uFloor
		                 );

		vec4 colourLayers = vec4(0.0);

		for (int i = 0; i < 5; ++i)
		{
			if (i >= colourCount)
				break;

			float layerPosition = colourCount > 1
			                      ? float(i) / float(colourCount - 1)
			                      : 0.5;

			float layerLevel = frequencyLayer(
			                       mirroredPosition,
			                       i,
			                       colourCount
			                   );

			float layerPeak = frequencyLayerPeak(i, colourCount);
			float normalizedShape = min(
			                            layerLevel / max(layerPeak, 0.001),
			                            1.0
			                        );

			float relativeMaximum = i == 0
			                        ? 1.0
			                        : mix(0.65, 0.28, layerPosition);

			layerLevel =
			    normalizedShape *
			    bassPeak *
			    relativeMaximum;

			float separationScale = mix(0.012, 0.004, layerPosition);
			float separation = uLayerSpread * separationScale;

			float layerRadius =
			    baseRadius +
			    layerLevel * height +
			    separation;

			float layerAA = max(
			                    fwidth(distanceFromCenter - layerRadius),
			                    0.75 / resolution.y
			                );

			float layerShape = filledWave(
			                       distanceFromCenter,
			                       baseRadius,
			                       layerRadius,
			                       layerAA
			                   );

			float layerDistance = abs(distanceFromCenter - layerRadius);
			float layerGlow = uGlow * glowSize * 1.5 /
			                  (layerDistance + glowSize * 3.0);

			vec4 colour = uColours[i];
			float alpha = clamp(
			                  (layerShape + layerGlow * 0.2) *
			                  uColourLayers *
			                  colour.a,
			                  0.0,
			                  1.0
			              );

			vec4 layer = vec4(
			                 colour.rgb * (layerShape + layerGlow),
			                 alpha
			             );

			colourLayers = over(layer, colourLayers);
		}

		result = over(colourLayers, result);
	}

	vec3 spectrumColour = uStyle == 0
	                      ? uMainColor.rgb
	                      : spectrumPalette(mirroredPosition);

	float spectrumAlpha = uStyle == 0 ? uMainColor.a : 1.0;
	float glow = uGlow * glowSize * 2.5 /
	             (glowDistance + glowSize * 3.0);

	vec4 spectrum = vec4(
	                    spectrumColour * (shape + glow),
	                    clamp((shape + glow * 0.3) * spectrumAlpha, 0.0, 1.0)
	                );

	result = over(spectrum, result);
	fragColor = result;
}