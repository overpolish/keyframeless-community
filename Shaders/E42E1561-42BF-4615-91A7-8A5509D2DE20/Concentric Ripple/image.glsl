// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template generator
// #alpha

// #audio label="Audio" flow flowlo=0 flowhi=63 flowgate=-50 release=0.18 smooth=0.10
uniform vec4 uAudio[16];

// #choice label="Listens To" group={"Reaction", "waveform"} options="Full Mix,Bass,Voice,Highs" default=0
uniform int uListen;

// #float label="Audio Speed" group="Reaction" min=0 max=5 default=1.2
uniform float uAudioSpeed;

// #percent label="Wave Amount" group="Reaction" min=0 max=100 default=25
uniform float uWaveAmount;

// #percent label="Brightness Response" group="Reaction" min=0 max=100 default=55
uniform float uBrightnessResponse;

// #int label="Rings" group={"Rings", "water.waves"} min=2 max=24 default=10
uniform int uRings;

// #percent label="Inner Radius" group="Rings" min=0 max=100 default=10 osc=ring link=uCenter
uniform float uInnerRadius;

// #int label="Thickness" group="Rings" units="px" min=1 slidermax=20 default=3
uniform float uThickness;

// #percent label="Glow" group="Rings" min=0 max=100 default=45
uniform float uGlow;

// #percent label="Idle Speed" group={"Motion", "wind"} min=0 max=100 default=12
uniform float uIdleSpeed;

// #point label="Center" group="Motion" osc=position default="0.5,0.5"
uniform vec2 uCenter;

// #color label="Ring Colours" min=2 max=5 default="#57E0FF,#8B7CFF,#E36DFF,#FF6D9A"
uniform vec4 uColours[5];

// #choice label="Background" group={"Background", "photo"} options="Transparent,Colour,Source Clip" default=0
uniform int uBackground;

// #percent label="Background Dim" group="Background" min=0 max=100 default=20 visibleby=uBackground visiblevalues={2}
uniform float uBackgroundDim;

// #color label="Background Colour" default="#05060C"
uniform vec4 uBackgroundColor;

const float TAU = 6.28318530718;

vec4 ringPalette(float position)
{
	int count = max(uColoursCount, 1);
	if (count == 1) return uColours[0];

	float palettePosition = clamp(position, 0.0, 1.0) * float(count - 1);
	int lower = int(floor(palettePosition));
	int upper = min(lower + 1, count - 1);
	return mix(uColours[lower], uColours[upper], fract(palettePosition));
}

void ringBandRange(out int firstBand, out int lastBand)
{
	if (uListen == 1)
	{
		firstBand = 0;
		lastBand = min(15, uAudioBands - 1);
	}
	else if (uListen == 2)
	{
		firstBand = min(14, uAudioBands - 1);
		lastBand = min(44, uAudioBands - 1);
	}
	else if (uListen == 3)
	{
		firstBand = min(36, uAudioBands - 1);
		lastBand = uAudioBands - 1;
	}
	else
	{
		firstBand = 0;
		lastBand = uAudioBands - 1;
	}
}

float ringEnergy(int ringIndex)
{
	int firstBand;
	int lastBand;
	ringBandRange(firstBand, lastBand);

	int span = max(lastBand - firstBand, 0);
	float ringPosition = (float(ringIndex) + 0.5) / max(float(uRings), 1.0);
	int centerBand = firstBand + int(round(ringPosition * float(span)));

	float energy = 0.0;
	float weight = 0.0;
	for (int offset = -2; offset <= 2; ++offset)
	{
		int band = clamp(centerBand + offset, firstBand, lastBand);
		float bandWeight = 1.0 - 0.18 * abs(float(offset));
		energy += uAudioBand(band) * bandWeight;
		weight += bandWeight;
	}

	return clamp(energy / max(weight, 0.001), 0.0, 1.0);
}

vec4 over(vec4 foreground, vec4 background)
{
	float alpha = foreground.a + background.a * (1.0 - foreground.a);
	vec3 premultiplied = foreground.rgb * foreground.a;
	premultiplied += background.rgb * background.a * (1.0 - foreground.a);
	vec3 rgb = alpha > 0.0001 ? premultiplied / alpha : vec3(0.0);

	return vec4(rgb, alpha);
}

vec4 backgroundLayer(vec2 fragCoord)
{
	if (uBackground == 1)
		return uBackgroundColor;

	if (uBackground == 2)
	{
		vec4 source = texture(iChannel0, fragCoord / iResolution.xy);
		return vec4(source.rgb * (1.0 - uBackgroundDim), source.a);
	}

	return vec4(0.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 position = fragCoord - uCenter;
	float distanceFromCenter = length(position);
	float angle = atan(position.y, position.x);
	float minSide = min(iResolution.x, iResolution.y);

	vec2 farCorner = max(uCenter, iResolution.xy - uCenter);
	float outerRadius = length(farCorner) + uThickness * 4.0;
	float innerRadius = uInnerRadius * minSide * 0.5;
	float clock = iTime * uIdleSpeed * 0.18 + uAudioFlow * uAudioSpeed * 0.45;

	vec3 ringColor = vec3(0.0);
	float ringAlpha = 0.0;

	for (int i = 0; i < 24; ++i)
	{
		if (i >= uRings) break;

		float index = float(i);
		float ringFraction = (index + 0.5) / max(float(uRings), 1.0);
		float life = fract(ringFraction + clock);
		float radius = mix(innerRadius, outerRadius, life);
		float energy = ringEnergy(i);

		float lobes = 3.0 + mod(index, 5.0);
		float phase = index * 1.73 + clock * TAU * 0.12;
		float wave = sin(angle * lobes + phase);
		wave += 0.45 * sin(angle * (lobes + 3.0) - phase * 1.4);
		wave *= energy * uWaveAmount * minSide * 0.035;

		float distanceToRing = abs(distanceFromCenter - radius - wave);
		float aa = max(fwidth(distanceFromCenter), 0.75);
		float thickness = uThickness * (1.0 + energy * 0.65);
		float core = 1.0 - smoothstep(thickness - aa, thickness + aa, distanceToRing);

		float glowWidth = thickness + uGlow * 18.0;
		float glow = exp(-distanceToRing * distanceToRing / max(glowWidth * glowWidth, 1.0));
		glow *= uGlow;

		float fadeIn = smoothstep(0.0, 0.08, life);
		float fadeOut = 1.0 - smoothstep(0.72, 1.0, life);
		float fade = fadeIn * fadeOut;

		vec4 color = ringPalette(ringFraction);
		float brightness = 0.55 + energy * uBrightnessResponse * 1.8;
		float contribution = (core * brightness + glow * 0.65) * fade;
		float alpha = clamp((core + glow * 0.45) * fade * color.a, 0.0, 1.0);

		ringColor += color.rgb * contribution * color.a;
		ringAlpha = clamp(ringAlpha + alpha * (1.0 - ringAlpha), 0.0, 1.0);
	}

	vec3 ringStraight = ringAlpha > 0.0001 ? ringColor / ringAlpha : vec3(0.0);
	fragColor = over(vec4(ringStraight, ringAlpha), backgroundLayer(fragCoord));
}
