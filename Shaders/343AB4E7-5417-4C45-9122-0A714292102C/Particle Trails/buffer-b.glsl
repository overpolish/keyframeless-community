// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// This prefix must match the Image tab declaration for declaration. Pool
// offsets are assigned per source in declaration order, so a tab that declares
// the same uniforms in a different order reads a different value for each.

// #color label="Trail" default="#57E0FF"
uniform vec4 uTint;

// #percent label="Glow" group={"Appearance", "sparkles"} min=0 max=100 default=45
uniform float uGlow;

// #percent label="Travel Area" group="Motion" min=0 max=100 default=92
uniform float uOrbit;

// #percent label="Head Size" group="Motion" min=10 max=300 default=100
uniform float uHeadSize;

// #int label="Particles" group="Motion" min=1 max=16 default=4
uniform int uParticles;

// #random label="Paths" group="Motion"
uniform float uPathSeed;

const float TAU = 6.28318530718;

float hash11(float value)
{
	return fract(sin(value * 127.1) * 43758.5453);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 resolution = iResolution.xy;
	vec2 uv = fragCoord / resolution;
	float minSide = min(resolution.x, resolution.y);

	float decay = mix(0.86, 0.985, clamp(iMotionBlur, 0.0, 1.0));
	vec4 history = texture(iChannel1, uv);

	// First-frame guard. The feedback buffer starts as whatever was in memory,
	// so every write below stamps a known signature into gba and the history is
	// only trusted when that signature comes back intact.
	float signatureError =
	    abs(history.g - 0.25) +
	    abs(history.b - 0.75) +
	    abs(history.a - 1.0);

	float previousEnergy = 0.0;

	if (signatureError < 0.001)
		previousEnergy = history.r * decay;

	float radius = minSide * 0.012 * uHeadSize;
	float feather = min(2.0, radius * 0.5);

	// Keep complete particles inside the frame at maximum travel.
	vec2 margin = vec2(radius + feather) / resolution + vec2(0.01);
	vec2 travelExtent = max(vec2(0.0), vec2(0.5) - margin) * uOrbit;

	float headEnergy = 0.0;

	for (int i = 0; i < 16; ++i)
	{
		if (i >= uParticles)
			break;

		float index = float(i);
		float seed = index * 31.73 + uPathSeed * 0.017;

		float particleSpeed = mix(0.65, 1.45, hash11(seed + 1.3));
		float horizontalRate = mix(0.65, 1.75, hash11(seed + 7.1));
		float verticalRate = mix(0.75, 2.15, hash11(seed + 13.7));

		float horizontalPhase = hash11(seed + 21.4) * TAU;
		float verticalPhase = hash11(seed + 29.8) * TAU;
		float time = iTime * 1.25 * particleSpeed;

		float horizontalWarp = sin(time * 0.31 + verticalPhase) * 0.38;
		float verticalWarp = cos(time * 0.27 + horizontalPhase) * 0.34;

		vec2 path = vec2(
		                sin(time * horizontalRate + horizontalPhase + horizontalWarp),
		                sin(time * verticalRate + verticalPhase + verticalWarp)
		            );

		vec2 headUV = vec2(0.5) + path * travelExtent;
		float distanceToHead = length(fragCoord - headUV * resolution);

		float particleEnergy =
		    1.0 - smoothstep(radius - feather, radius, distanceToHead);

		headEnergy = max(headEnergy, particleEnergy);
	}

	float energy = max(previousEnergy, headEnergy);

	fragColor = vec4(energy, 0.25, 0.75, 1.0);
}