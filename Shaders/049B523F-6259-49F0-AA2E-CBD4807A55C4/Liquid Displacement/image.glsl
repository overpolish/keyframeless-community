// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template transition

// #motionblur on

// #angle label="Direction" group={"Flow", "tornado"} default=0
uniform float uDirection;

// #percent label="Strength" group="Flow" min=0 max=100 default=45
uniform float uStrength;

// #percent label="Turbulence" group="Flow" min=0 max=100 default=65
uniform float uTurbulence;

// #float label="Scale" group={"Texture", "circle.hexagongrid"} min=0.5 max=12 default=4
uniform float uScale;

// #percent label="Softness" group={"Edge", "waveform.path"} min=0 max=100 default=18
uniform float uSoftness;

// #random label="Variation" group="Texture"
uniform float uSeed;

// #choice label="Edges" group={"Finish", "sparkles"} options="Clamp,Mirror,Repeat" default=1
uniform int uEdges;

const float TAU = 6.28318530718;

float liquidHash(vec2 p)
{
	p += uSeed * vec2(0.017, 0.031);
	p = fract(p * vec2(0.3183099, 0.3678794)) + 0.1;
	p += dot(p, p + 19.19);
	return fract(p.x * p.y);
}

float liquidNoise(vec2 p)
{
	vec2 cell = floor(p);
	vec2 local = fract(p);
	vec2 blend = local * local * (3.0 - 2.0 * local);

	float a = liquidHash(cell);
	float b = liquidHash(cell + vec2(1.0, 0.0));
	float c = liquidHash(cell + vec2(0.0, 1.0));
	float d = liquidHash(cell + vec2(1.0, 1.0));

	return mix(mix(a, b, blend.x), mix(c, d, blend.x), blend.y);
}

vec2 liquidFlow(vec2 p, float phase)
{
	vec2 q = p * uScale;
	float warpX = liquidNoise(q * 0.55 + vec2(phase, -phase * 0.37));
	float warpY = liquidNoise(q * 0.55 + vec2(17.3 - phase * 0.28, 9.1 + phase));

	q += (vec2(warpX, warpY) - 0.5) * 3.0 * uTurbulence;

	float angle = liquidNoise(q + vec2(phase * 0.6, -phase * 0.4)) * TAU;
	float variation = liquidNoise(q * 1.7 - vec2(phase * 0.3, phase * 0.5));

	return vec2(cos(angle), sin(angle)) * mix(0.45, 1.0, variation);
}

vec2 liquidEdge(vec2 uv)
{
	if (uEdges == 1)
		return 1.0 - abs(mod(uv, 2.0) - 1.0);

	if (uEdges == 2)
		return fract(uv);

	return clamp(uv, 0.0, 1.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;

	if (iProgress <= 0.0)
	{
		fragColor = texture(iChannel0, uv);
		return;
	}

	if (iProgress >= 1.0)
	{
		fragColor = texture(iChannel1, uv);
		return;
	}

	float progress = iProgress * iProgress * (3.0 - 2.0 * iProgress);
	float aspect = iResolution.x / iResolution.y;
	vec2 position = (uv - 0.5) * vec2(aspect, 1.0);

	vec2 direction = vec2(cos(uDirection), sin(uDirection));
	float extent = 0.5 * (abs(direction.x) * aspect + abs(direction.y));
	float coordinate = dot(position, direction) / max(2.0 * extent, 0.0001) + 0.5;

	vec2 flow = liquidFlow(position, progress * 2.0);
	float frontWarp = dot(flow, vec2(-direction.y, direction.x));
	coordinate += frontWarp * uTurbulence * 0.16;

	float width = mix(0.002, 0.22, uSoftness);
	float reveal = 1.0 - smoothstep(progress - width, progress + width, coordinate);

	float envelope = sin(progress * 3.14159265);
	vec2 directionUV = vec2(direction.x / aspect, direction.y);
	vec2 flowUV = vec2(flow.x / aspect, flow.y);

	vec2 push = directionUV * 0.45 + flowUV * uTurbulence;
	vec2 displacement = push * uStrength * 0.18 * envelope;

	vec2 fromUV = liquidEdge(uv - displacement * progress);
	vec2 toUV = liquidEdge(uv + displacement * (1.0 - progress));

	vec4 fromColor = texture(iChannel0, fromUV);
	vec4 toColor = texture(iChannel1, toUV);

	fragColor = mixTransitionColors(fromColor, toColor, reveal);
}