// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template filter

// #audio label="Audio" gate=-60 release=0.18 smooth=0.05
uniform vec4 uAudio[16];

// #choice label="Listen To" group={"Response", "waveform"} options="Full Mix,Kick,Bass,Voice,Highs" default=0
uniform int uListen;

// #percent label="Sensitivity" group="Response" min=10 max=100 default=80
uniform float uSensitivity;

// #float label="Punch" group="Response" min=0.5 max=5 default=2
uniform float uPunch;

// #point label="Center" group={"Transform", "viewfinder"} osc=position default="0.5,0.5"
uniform vec2 uCenter;

// #percent label="Zoom Amount" group="Transform" min=0 max=200 slidermax=60 default=18 osc=ring link=uCenter
uniform float uZoom;

void listeningRange(out int first, out int last)
{
	first = 0;
	last = uAudioBands - 1;

	if (uListen == 1)
	{
		first = 0;
		last = 10;
	}
	else if (uListen == 2)
	{
		first = 8;
		last = 22;
	}
	else if (uListen == 3)
	{
		first = 12;
		last = 52;
	}
	else if (uListen == 4)
	{
		first = 40;
		last = 63;
	}

	last = min(last, uAudioBands - 1);
	first = min(first, last);
}

float audioLevel()
{
	int first;
	int last;
	listeningRange(first, last);

	float peak = 0.0;
	float sumSquares = 0.0;
	int count = 0;

	for (int i = 0; i < 64; ++i)
	{
		if (i < first)
			continue;

		if (i > last)
			break;

		float value = uAudioBand(i);
		peak = max(peak, value);
		sumSquares += value * value;
		count++;
	}

	float rms = sqrt(sumSquares / max(float(count), 1.0));
	float level = mix(rms, peak, 0.65);
	float threshold = 1.0 - uSensitivity;

	level = max(level - threshold, 0.0) / max(uSensitivity, 0.001);
	level = pow(clamp(level, 0.0, 1.0), 1.0 / max(uPunch, 0.001));

	return level;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;
	vec2 center = uCenter / iResolution.xy;

	float level = audioLevel();
	float scale = 1.0 + level * uZoom;
	vec2 samplePosition = (uv - center) / scale + center;

	fragColor = texture(iChannel0, samplePosition);
}
