// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template generator

// #alpha

// #grain label="Grain" group={"Finish", "camera.filters"} default=0 size=2

// #audio label="Audio" waveform=128 wavewindow=0.04
uniform vec4 uAudio[16];

// #choice label="Style" group={"Waveform","waveform"} options="Line,Filled,Mirrored" default=0
uniform int uStyle;

// #percent label="Gain" group="Waveform" min=0 max=400 default=140
uniform float uGain;

// #percent label="Smoothing" group="Waveform" min=0 max=100 default=25
uniform float uSmoothing;

// #bool label="Trigger" group="Waveform" default=true
uniform bool uTrigger;

// #point label="Position" group={"Layout","rectangle"} osc=position default="0.5,0.5"
uniform vec2 uCenter;

// #multi label="Size" group="Layout" fields={W,H} percent min=5 max=150 default="100,45" osc=box link=uCenter
uniform vec2 uSize;

// #angle label="Rotation" group="Layout" default=0 osc={z} link=uCenter
uniform float uRotation;

// #int label="Thickness" group={"Appearance","paintbrush"} units="px" min=1 slidermax=12 default=3
uniform float uThickness;

// #percent label="Fill" group="Appearance" min=0 max=100 default=70 visibleby=uStyle visiblevalues={1,2}
uniform float uFill;

// #percent label="Baseline" group="Appearance" min=0 max=100 default=20
uniform float uBaseline;

// #percent label="Glow" group="Appearance" min=0 max=100 default=35
uniform float uGlow;

// #int label="Glow Size" group="Appearance" units="px" min=1 slidermax=60 default=18
uniform float uGlowSize;

// #color label="Wave" default="#70E7FFFF"
uniform vec4 uWave;

// #color label="Background" default="#05060AFF"
uniform vec4 uBackground;

float scopeSample(int index)
{
	return uAudioWave(clamp(index, 0, uAudioWaveSamples - 1));
}

float scopeWave(float index)
{
	int base = int(floor(index));
	float fraction = fract(index);
	float raw = mix(scopeSample(base), scopeSample(base + 1), fraction);
	float smoothA = scopeSample(base - 2) + 2.0 * scopeSample(base - 1);
	float smoothB = 2.0 * scopeSample(base + 1) + scopeSample(base + 2);
	float filtered = (smoothA + 3.0 * scopeSample(base) + smoothB) / 9.0;
	return mix(raw, filtered, uSmoothing);
}

int scopeTrigger()
{
	if (!uTrigger) return 0;

	// The search window is 16 samples wide, so the trace can start up to 15
	// samples in. The span below subtracts that window plus one, which keeps
	// the top of the sweep inside the buffer - the two numbers move together.
	float previous = scopeSample(0);
	for (int i = 1; i < 16; ++i)
	{
		float current = scopeSample(i);
		if (previous <= 0.0 && current > 0.0) return i;
		previous = current;
	}
	return 0;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 halfSize = max(0.5 * uSize * iResolution.xy, vec2(1.0));
	vec2 p = fragCoord - uCenter;

	float c = cos(uRotation);
	float s = sin(uRotation);
	p = mat2(c, -s, s, c) * p;

	vec2 q = p / halfSize;
	float x = q.x * 0.5 + 0.5;
	float insideX = smoothstep(-1.0, 1.0, (1.0 - abs(q.x)) * halfSize.x);

	int trigger = scopeTrigger();
	float sourceIndex = float(trigger) + clamp(x, 0.0, 1.0) * float(uAudioWaveSamples - 17);
	float wave = scopeWave(sourceIndex) * uGain;

	float delta = p.y - wave * halfSize.y;
	vec2 gradient = vec2(dFdx(delta), dFdy(delta));
	float distancePx = abs(delta) / max(length(gradient), 0.0001);
	float aa = max(fwidth(distancePx), 0.75);
	float line = 1.0 - smoothstep(uThickness - aa, uThickness + aa, distancePx);
	line *= insideX;

	float aaY = 1.5 / halfSize.y;
	float fill = 0.0;

	if (uStyle == 1)
	{
		float low = min(0.0, wave);
		float high = max(0.0, wave);
		fill = smoothstep(low - aaY, low + aaY, q.y) *
		       (1.0 - smoothstep(high - aaY, high + aaY, q.y));
	}
	else if (uStyle == 2)
	{
		float amplitude = abs(wave);
		fill = 1.0 - smoothstep(amplitude - aaY, amplitude + aaY, abs(q.y));
	}
	fill *= insideX;

	float baseline = 1.0 - smoothstep(0.5, 1.5, abs(p.y));
	baseline *= insideX;

	float glow = exp(-distancePx / max(uGlowSize, 1.0)) * uGlow * insideX;
	float coreAlpha = max(line, fill * uFill) * uWave.a;
	float baselineAlpha = baseline * uBaseline * uWave.a * (1.0 - coreAlpha);
	float glowAlpha = glow * uWave.a * (1.0 - coreAlpha) * (1.0 - baselineAlpha);
	float waveAlpha = coreAlpha + baselineAlpha + glowAlpha;

	vec3 wavePremultiplied = uWave.rgb * (coreAlpha + baselineAlpha);
	wavePremultiplied += mix(uWave.rgb, vec3(1.0), 0.25) * glowAlpha;

	float outputAlpha = waveAlpha + uBackground.a * (1.0 - waveAlpha);
	vec3 outputPremultiplied =
	    wavePremultiplied + uBackground.rgb * uBackground.a * (1.0 - waveAlpha);
	vec3 color = outputAlpha > 0.0001 ? outputPremultiplied / outputAlpha : vec3(0.0);

	fragColor = vec4(color, outputAlpha);
}