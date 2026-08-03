// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template generator

// #motionblur native on
// #speed group={"Motion", "wind"}

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

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;
	vec3 source = texture(iChannel0, uv).rgb;
	float trailEnergy = texture(iChannel1, uv).r;

	vec3 trailColor = uTint.rgb * (1.0 + uGlow * 2.0 * trailEnergy);
	vec3 color = source + trailColor * trailEnergy;

	fragColor = vec4(color, 1.0);
}