// SPDX-FileCopyrightText: 2025 Paul Bakaus
// SPDX-License-Identifier: MIT
//
// Neon - derived from "Neon Drip" in radiant-shaders (github.com/pbakaus/radiant),
// reduced to just the glowing tendril wisps (the source's metaball blobs are
// dropped) and retuned so the strands read as tangled neon filaments rather than
// rising flames. Translated to GLSL for Mirage and adapted for its directive
// controls. The wisp field is layered through a 4-stop HDR ramp from the palette
// and ACES tone-mapped over a dark backdrop.

// #color label="Colours" min=1 max=4 default="#001518,#00E5FF,#7CFBFF,#FFFFFF"
uniform vec4 uColours[4];

// #color label="Background" default="#04060A"
uniform vec4 uColorBack;

// #percent label="Wisps" default=70
uniform float uWisps;

// #percent label="Strands" default=100
uniform float uStrands;

// #percent label="Radiance" default=100
uniform float uRadiance;

// #point label="Center" osc default="0.5,0.5"
uniform vec2 uCenter;

// #percent label="Scale" default=100 osc=ring link=uCenter
uniform float uScale;

float ndHash21(vec2 p)
{
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.164);
	return fract(p.x * p.y);
}

float ndValueNoise(vec2 st)
{
	vec2 i = floor(st);
	vec2 f = fract(st);
	float a = ndHash21(i);
	float b = ndHash21(i + vec2(1.0, 0.0));
	float c = ndHash21(i + vec2(0.0, 1.0));
	float d = ndHash21(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float ndTendrilField(vec2 p, float t, float speed, float strands)
{
	vec2 s = p * strands;
	// Near-isotropic frequencies -> tangled filaments, not vertical streaks.
	float n1 = ndValueNoise(vec2(s.x * 6.0 - t * speed * 0.25, s.y * 6.0 + t * speed * 0.20) + 10.0);
	float n2 = ndValueNoise(vec2(s.x * 12.0 + 3.7 + t * speed * 0.30, s.y * 11.0 - t * speed * 0.28) + 20.0);
	float n3 = ndValueNoise(vec2(s.x * 3.0 + 7.1, s.y * 3.5 - t * speed * 0.15));
	float tendrils = n1 * 0.5 + n2 * 0.3 + n3 * 0.2;
	tendrils = smoothstep(0.40, 0.62, tendrils);
	// Radial confine (no gravity), so wisps float rather than rise.
	tendrils *= smoothstep(1.25, 0.15, length(p * vec2(0.95, 1.0)));
	return tendrils;
}

float ndVignette(vec2 uv)
{
	float d = length(uv * vec2(0.9, 1.0));
	return smoothstep(1.3, 0.4, d);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	float aspect = iResolution.x / iResolution.y;
	float t = iTime; // time+seed at Speed 1
	float speed = 0.5; // source dripSpeed

	vec2 uv = fragCoord / iResolution.xy; // y-up (Shadertoy)
	vec2 origin = uCenter / iResolution.xy; // #point delivers pixels
	uv -= (origin - 0.5);
	uv -= 0.5;
	uv.x *= aspect;
	uv /= max(uScale, 0.01);

	float bgDist = length(uv * vec2(0.8, 1.0));
	vec3 col = uColorBack.rgb * uColorBack.a * (1.0 - bgDist * 0.3);
	col = max(col, vec3(0.0));

	float tendrils = ndTendrilField(uv, t, speed, uStrands);
	float w = clamp(tendrils * uWisps * 1.4, 0.0, 2.0);

	float outerGlow = smoothstep(0.04, 0.30, w);
	float surface = smoothstep(0.20, 0.52, w);
	float inner = smoothstep(0.45, 0.85, w);
	float core = smoothstep(0.85, 1.30, w);

	int cc = max(uColoursCount, 1);
	vec4 sc0 = uColours[0];
	vec4 sc1 = uColours[min(1, cc - 1)];
	vec4 sc2 = uColours[min(2, cc - 1)];
	vec4 sc3 = uColours[min(3, cc - 1)];
	float rad = uRadiance;
	vec3 glowColor = sc0.rgb * sc0.a * 1.2 * rad;
	vec3 surfaceColor = sc1.rgb * sc1.a * 2.5 * rad;
	vec3 innerColor = sc2.rgb * sc2.a * 3.5 * rad;
	vec3 coreColor = sc3.rgb * sc3.a * 5.0 * rad;

	vec3 wispCol = glowColor * outerGlow;
	wispCol = mix(wispCol, surfaceColor, surface * 0.95);
	wispCol = mix(wispCol, innerColor, inner * 0.95);
	wispCol = mix(wispCol, coreColor, core);
	float edgeBand = surface * (1.0 - inner);
	wispCol += surfaceColor * 0.4 * edgeBand;
	col += wispCol;

	float ambientFlow = ndValueNoise(vec2(uv.x * 3.0 + t * speed * 0.2, uv.y * 3.0) + 50.0);
	ambientFlow = smoothstep(0.4, 0.6, ambientFlow) * 0.06;
	col += glowColor * 0.15 * ambientFlow;

	float grain = (ndHash21(fragCoord + fract(t * 43.758) * 1000.0) - 0.5) * 0.025;
	col += grain;

	col *= ndVignette(uv);

	col = max(col, vec3(0.0));
	col = col * (2.51 * col + 0.03) / (col * (2.43 * col + 0.59) + 0.14);
	col = pow(max(col, 0.0), vec3(0.90));

	fragColor = vec4(col, 1.0);
}
