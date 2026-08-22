// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template generator
// #alpha

// #motionblur off

// Flow spans all 64 bands rather than the default lowest four, so the clock
// advances on the whole mix: a bright hit pushes the particles as much as a
// kick does.
// #audio label="Audio" flow flowlo=0 flowhi=63 flowgate=-50
uniform vec4 uAudio[16];

// #int label="Particle Count" group={"Particles", "sparkles"} min=8 max=200 default=110
uniform int uCount;

// #random label="Pattern" group="Particles"
uniform float uSeed;

// #point label="Center" group="Particles" osc=position default="0.5,0.5"
uniform vec2 uCenter;

// #percent label="Reach" group="Particles" min=10 max=200 default=100
uniform float uReach;

// #percent label="Idle Speed" group={"Motion", "wind"} min=0 max=100 default=12
uniform float uDrift;

// #float label="Audio Push" group="Motion" min=0 max=50 slidermax=20 default=3
uniform float uPush;

// #percent label="Glow" group={"Appearance", "light.max"} min=10 max=300 default=60
uniform float uGlow;

// #color label="Particle Color" default="#FF5AA0FF"
uniform vec4 uColor;

// #choice label="Background" group={"Background", "photo"} options="Transparent,Colour,Source Clip" default=0
uniform int uBackground;

// #percent label="Background Dim" group="Background" min=0 max=100 default=20 visibleby=uBackground visiblevalues={2}
uniform float uBackgroundDim;

// #color label="Background Colour" default="#080A12"
uniform vec4 uBackgroundColor;

const float TAU = 6.28318530718;

float hash11(float value)
{
	return fract(sin(value * 127.1) * 43758.5453);
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
	vec2 p = (fragCoord - uCenter) / iResolution.y;
	float glowStrength = uGlow * 0.01;
	float brightness = 0.0;

	// Both terms are monotonic during forward playback. Audio can accelerate
	// the particles, but it cannot move their radial clock backward.
	float idleClock = iTime * uDrift;
	float audioClock = uAudioFlow * uPush;

	for (int i = 0; i < 200; ++i)
	{
		if (i >= uCount)
			break;

		float index = float(i) + uSeed * 0.017;
		float angle = hash11(index) * TAU;
		float phase = hash11(index + 7.3);
		float speedVariation = mix(0.6, 1.4, hash11(index + 3.1));

		float life = fract(phase + idleClock * speedVariation + audioClock);
		float radius = life * 1.15 * uReach;
		vec2 position = vec2(cos(angle), sin(angle)) * radius;

		float fade = smoothstep(0.0, 0.04, life) * (1.0 - life);
		float distanceToParticle = length(p - position);

		brightness += fade * glowStrength / (distanceToParticle + 0.0001);
	}

	vec3 color = uColor.rgb * brightness;
	float alpha = clamp(brightness * uColor.a, 0.0, 1.0);

	vec3 straightColor = alpha > 0.0001 ? color / alpha : color;
	fragColor = over(vec4(straightColor, alpha), backgroundLayer(fragCoord));
}
