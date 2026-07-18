// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT
//
// Contour - a swirled multi-colour gradient etched with topographic contour
// lines. A spatially-varying rotation twists the field; constant-width iso-lines
// of the gradient trace over it. Original implementation.

// #color label="Colours" min=2 max=4 default="#AD1AE6,#99CCF0,#FFAD66,#FA6159"
uniform vec4 uColours[4];

// #percent label="Swirl" default=100
uniform float uSwirl;

// #int label="Lines" min=8 max=80 default=40
uniform float uLines;

// #percent label="Line Intensity" default=60
uniform float uLineIntensity;

// #point label="Center" osc default="0.5,0.5"
uniform vec2 uCenter;

// #percent label="Scale" default=100 osc=ring link=uCenter
uniform float uScale;

vec3 ctPalette(float f)
{
	int n = max(uColoursCount, 1);
	if (n == 1)
		return uColours[0].rgb;
	f = clamp(f, 0.0, 1.0) * float(n - 1);
	int i0 = int(floor(f));
	int i1 = min(i0 + 1, n - 1);
	return mix(uColours[i0].rgb, uColours[i1].rgb, fract(f));
}

vec2 ctSwirl(vec2 uv, float t, float k)
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

	// Swirl warp, then a diagonal gradient position across the twisted field.
	vec2 sw = ctSwirl(uv, t, uSwirl);
	float idx = clamp(0.5 + 0.5 * (0.6 * sw.x + 0.5 * sw.y), 0.0, 1.0);
	vec3 col = ctPalette(idx);
	col = clamp(col * (0.85 + 0.35 * col), 0.0, 1.0); // glossy tone

	// Constant-width topographic contour lines of the gradient field.
	float hv = idx * uLines;
	float dline = min(fract(hv), 1.0 - fract(hv));
	float aa = fwidth(hv) + 1e-4;
	float line = smoothstep(0.06 + aa, 0.06, dline);
	float fade = 0.5 + 0.5 * sin(sw.x * 0.6 + t * 0.5); // some regions carry fewer lines
	line *= mix(0.35, 1.0, fade) * uLineIntensity;

	// Etch the lines as a soft luminous trace.
	col = mix(col, mix(col, vec3(1.0), 0.6), line);

	fragColor = vec4(col, 1.0);
}