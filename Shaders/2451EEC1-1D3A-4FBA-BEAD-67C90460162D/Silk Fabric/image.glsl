// SPDX-FileCopyrightText: 2024 Giorgi Azmaipharashvili
// SPDX-License-Identifier: MIT
//
// Satin - derived from a silk-fabric shader by Giorgi Azmaipharashvili.
// Translated to GLSL for Mirage and adapted for its directive controls: the
// monochrome original is recoloured through a two-tone palette, and the weave,
// sheen and surface ripple are exposed as controls. The mouse interaction is
// dropped (no pointer in the FxPlug render).

// #color label="Colours" min=2 max=2 default="#1B1533,#E8DEFF"
uniform vec4 uColours[2];

// #bool label="Invert" default=1
uniform bool uInvert;

// #percent label="Sheen" default=70
uniform float uSheen;

// #percent label="Weave" default=100
uniform float uWeave;

// #percent label="Ripple" default=100
uniform float uRipple;

// #point label="Center" osc default="0.5,0.5"
uniform vec2 uCenter;

// #percent label="Scale" default=100 osc=ring link=uCenter
uniform float uScale;

float slkNoise(vec2 p)
{
	return smoothstep(-0.5, 0.9, sin((p.x - p.y) * 555.0) * sin(p.y * 1444.0)) - 0.4;
}

float slkFabric(vec2 p)
{
	const mat2 m = mat2(1.6, 1.2, -1.2, 1.6);
	float f = 0.4 * slkNoise(p);
	f += 0.3 * slkNoise(p = m * p);
	f += 0.2 * slkNoise(p = m * p);
	return f + 0.1 * slkNoise(m * p);
}

float slkSilk(vec2 uv, float t)
{
	float s = sin(5.0 * (uv.x + uv.y + cos(2.0 * uv.x + 5.0 * uv.y)) + sin(12.0 * (uv.x + uv.y)) - t);
	s = 0.7 + 0.3 * (s * s * 0.5 + s);
	s *= 0.9 + 0.6 * uWeave * slkFabric(uv * min(iResolution.x, iResolution.y) * 0.0006);
	return s * 0.9 + 0.1;
}

float slkSilkD(vec2 uv, float t)
{
	float xy = uv.x + uv.y;
	float d = (5.0 * (1.0 - 2.0 * sin(2.0 * uv.x + 5.0 * uv.y)) + 12.0 * cos(12.0 * xy)) *
	          cos(5.0 * (cos(2.0 * uv.x + 5.0 * uv.y) + xy) + sin(12.0 * xy) - t);
	return 0.005 * d * (sign(d) + 3.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	float mr = min(iResolution.x, iResolution.y);
	float t = iTime; // Speed/Seed shape iTime

	vec2 uv = fragCoord / mr;
	vec2 pan = (uCenter - 0.5 * iResolution.xy) / mr; // #point delivers pixels
	uv -= pan;
	vec2 frameC = 0.5 * iResolution.xy / mr;
	uv = (uv - frameC) / max(uScale, 0.01) + frameC; // zoom about frame centre

	uv.y += 0.03 * uRipple * sin(8.0 * uv.x - t);

	float s = sqrt(slkSilk(uv, t));
	float d = slkSilkD(uv, t);

	vec3 c = vec3(s);
	c += 0.7 * uSheen * vec3(1.0, 0.83, 0.6) * d;
	c *= 1.0 - max(0.0, 0.8 * d);
	if (uInvert)
	{
		c = pow(max(c, 0.0), 0.3 / vec3(0.52, 0.5, 0.4));
		c = 1.0 - c;
	}
	else
	{
		c = pow(max(c, 0.0), vec3(0.52, 0.5, 0.4));
	}

	// Recolour the silk: map its luminance across the two-tone palette.
	float L = clamp(dot(c, vec3(0.299, 0.587, 0.114)), 0.0, 1.0);
	vec3 col = mix(uColours[0].rgb, uColours[1].rgb, L);

	fragColor = vec4(col, 1.0);
}
