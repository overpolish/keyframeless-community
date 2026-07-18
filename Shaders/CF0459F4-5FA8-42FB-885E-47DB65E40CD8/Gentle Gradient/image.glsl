// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT
//
// Swirl - a glossy swirled tri-colour gradient. A spatially-varying rotation
// twists the field; a palette gradient with a glossy tone paints it. Original
// code (same clean-room swirl as Contour, without the contour lines).

// #color label="Colours" min=2 max=4 default="#8C00FF,#FF0080,#00FFFF"
uniform vec4 uColours[4];

// #percent label="Swirl" default=100
uniform float uSwirl;

// #point label="Center" osc default="0.5,0.5"
uniform vec2 uCenter;

// #percent label="Scale" default=100 osc=ring link=uCenter
uniform float uScale;

vec2 swSwirl(vec2 uv, float t, float k)
{
	float a = sin(uv.x * 2.0 + t) + cos(uv.y * 2.3 - 0.7 * t);
	a *= 0.6 * k;
	float c = cos(a), s = sin(a);
	return mat2(c, -s, s, c) * uv;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
	uv -= (uCenter - 0.5 * iResolution.xy) / iResolution.y; // #point pan
	uv /= max(uScale, 0.01); // zoom

	float t = iTime * 0.5; // Speed/Seed shape iTime

	vec2 sw = swSwirl(uv, t, uSwirl);
	vec2 g = sw * 0.5 + 0.5;

	vec3 col = mix(uColours[0].rgb, uColours[min(1, uColoursCount - 1)].rgb, clamp(g.x, 0.0, 1.0));
	col = mix(col, uColours[min(2, uColoursCount - 1)].rgb, clamp(g.y, 0.0, 1.0));

	col = col * (0.85 + 0.35 * col); // glossy tone
	fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}