// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template filter
// #frames offsets="+3,+6,+12"
// #motionblur off

// #choice label="How Far Ahead" options="Close,Mid,Far" default=1 group={"Premonition", "sparkles"}
uniform int uDistance;

// #percent label="Ghost Strength" min=0 max=100 default=80 group="Premonition"
uniform float uStrength;

// #percent label="Tint" min=0 max=100 default=50 group="Premonition"
uniform float uTintAmount;

// #color label="Ghost Color" default="#8FA8FF"
uniform vec4 uTint;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;

	vec3 now = texture(iChannel0, uv).rgb;
	vec3 future = iNeighborAt(uDistance, uv).rgb;

	// The gate is fully open at a summed channel difference of 1/6, so it
	// rejects noise rather than scaling the ghost with the size of the move.
	float motion = clamp(dot(abs(future - now), vec3(1.0)) * 6.0, 0.0, 1.0);

	float glow = dot(future, vec3(0.299, 0.587, 0.114));
	vec3 ghost = mix(future, uTint.rgb * (glow * 1.6), uTintAmount);

	vec3 outColor = 1.0 - (1.0 - now) * (1.0 - ghost * (uStrength * motion));

	fragColor = vec4(clamp(outColor, 0.0, 1.0), 1.0);
}
