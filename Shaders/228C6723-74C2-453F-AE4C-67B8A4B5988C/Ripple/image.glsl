// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template filter

// #alpha
// #audio label="Audio" flow flowlo=0 flowhi=63 flowgate=-50
uniform vec4 uAudio[16];

// #int label="Ripple Points" group={"Ripples", "water.waves"} min=1 max=12 default=4
uniform int uCount;

// #random label="Scatter" group="Ripples"
uniform float uSeed;

// #float label="Rings" group="Ripples" min=1 max=48 slidermax=12 default=4
uniform float uRings;

// #float label="Spread" group="Ripples" min=2 max=100 slidermax=25 default=7
uniform float uSpread;

// #float label="Audio Boost" group={"Motion", "wind"} min=0.1 max=5 default=1.2
uniform float uSpeed;

// #percent label="Idle Speed" group="Motion" min=0 max=100 default=15
uniform float uDrift;

// #percent label="Strength" group={"Surface", "waveform"} min=0 max=100 default=35
uniform float uStrength;

// #percent label="Shading" group="Surface" min=0 max=100 default=45
uniform float uShade;

const float TAU = 6.28318530718;

float hash11(float value)
{
	return fract(sin(value * 127.1) * 43758.5453);
}

vec2 hash21(float value)
{
	return vec2(hash11(value), hash11(value + 37.7));
}

void mirageFilterImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 resolution = iResolution.xy;
	vec2 uv = fragCoord / resolution;

	float aspect = resolution.x / resolution.y;
	vec2 p = vec2(uv.x * aspect, uv.y);

	// Audio flow increases the outward speed without changing wave strength.
	float travel = iTime * uDrift * 0.5 + uAudioFlow * uSpeed * 0.75;
	float travelPhase = travel * TAU;
	float frequency = uRings * TAU;
	float decay = uSpread * 0.25;

	float surfaceHeight = 0.0;
	vec2 surfaceSlope = vec2(0.0);

	for (int i = 0; i < 12; ++i)
	{
		if (i >= uCount)
			break;

		float index = float(i);
		vec2 originUV = 0.08 + hash21(index * 13.7 + uSeed * 0.017) * 0.84;
		vec2 origin = vec2(originUV.x * aspect, originUV.y);

		vec2 delta = p - origin;
		float distance = sqrt(dot(delta, delta) + 0.0001);
		vec2 direction = delta / distance;

		float sourcePhase = hash11(index + 5.1) * TAU;
		float phase = distance * frequency - travelPhase + sourcePhase;
		float envelope = exp(-distance * decay);
		float sourceWeight = mix(0.7, 1.0, hash11(index + 19.3));

		float wave = sin(phase) * envelope * sourceWeight;

		float radialSlope =
		    envelope *
		    (frequency * cos(phase) - decay * sin(phase)) *
		    sourceWeight;

		surfaceHeight += wave;
		surfaceSlope += direction * radialSlope;
	}

	float normalization = inversesqrt(max(float(uCount), 1.0));

	surfaceHeight *= normalization;
	surfaceSlope *= normalization;

	vec2 sampleOffset = -vec2(surfaceSlope.x / aspect, surfaceSlope.y);
	sampleOffset *= uStrength * 0.0015;

	vec2 samplePosition = clamp(uv + sampleOffset, 0.0, 1.0);
	vec4 source = texture(iChannel0, samplePosition);
	vec3 color = source.rgb;

	vec3 normal = normalize(vec3(-surfaceSlope * 0.12, 1.0));
	vec3 lightDirection = normalize(vec3(-0.45, 0.55, 1.0));

	float flatLight = lightDirection.z;
	float directionalLight = clamp(
	                             dot(normal, lightDirection) / flatLight,
	                             0.55,
	                             1.45
	                         );

	float crestLight = clamp(1.0 + surfaceHeight * 0.12, 0.8, 1.2);
	float lighting = mix(1.0, directionalLight * crestLight, uShade);

	color *= lighting;

	fragColor = vec4(color, source.a);
}

// FxPlug supplies iChannel0 premultiplied. The filter body keeps doing its
// existing maths in that representation; #alpha then expects straight colour,
// so unwrap once here before Mirage premultiplies the final output.
void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	mirageFilterImage(fragColor, fragCoord);
	if (fragColor.a > 0.0001)
		fragColor.rgb /= fragColor.a;
	else
		fragColor.rgb = vec3(0.0);
}
