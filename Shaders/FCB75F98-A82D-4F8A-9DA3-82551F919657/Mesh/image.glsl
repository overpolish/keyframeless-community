// SPDX-FileCopyrightText: The paper-design/shaders authors
// SPDX-License-Identifier: Apache-2.0
//
// Mesh Gradient - derived from the mesh-gradient shader in paper-design/shaders
// (https://github.com/paper-design/shaders). Translated to GLSL for Mirage and
// adapted for its directive controls; the original algorithm/parameters are
// preserved.

// #color label="Colours" min=1 max=5 default=4
uniform vec4 uColours[5];

// #percent label="Distortion" default=40
uniform float uDistortion;

// #percent label="Swirl" default=30
uniform float uSwirl;

// #point label="Center" osc default="0.5,0.5"
uniform vec2 uCenter;

// #percent label="Scale" default=100 osc=ring link=uCenter
uniform float uScale;

vec2 mgRotate(vec2 v, float a)
{
	float s = sin(a), c = cos(a);
	return vec2(c * v.x + s * v.y, -s * v.x + c * v.y);
}

vec2 mgPosition(int i, float t)
{
	float a = float(i) * 0.37;
	float b = 0.6 + fract(float(i) / 3.0) * 0.9;
	float c = 0.8 + fract(float(i + 1) / 4.0);
	return 0.5 + 0.5 * vec2(sin(t * b + a), cos(t * c + a * 1.5));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	float aspect = iResolution.x / iResolution.y;
	vec2 asp = vec2(aspect, 1.0); // x measured in y-units

	vec2 origin = uCenter / iResolution.xy; // #point delivers pixels
	vec2 uv = fragCoord / iResolution.xy - (origin - 0.5);

	// Scale (zoom) about the centre.
	uv = (uv - 0.5) / max(uScale, 0.01) + 0.5;

	float t = 0.5 * (iTime + 41.5); // Speed/Seed shape iTime

	float radius = smoothstep(0.0, 1.0, length((uv - 0.5) * asp));
	float centre = 1.0 - radius;
	for (float i = 1.0; i <= 2.0; i++)
	{
		uv.x += uDistortion * centre / i
		        * sin(t + i * 0.4 * smoothstep(0.0, 1.0, uv.y))
		        * cos(0.2 * t + i * 2.4 * smoothstep(0.0, 1.0, uv.y));
		uv.y += uDistortion * centre / i
		        * cos(t + i * 2.0 * smoothstep(0.0, 1.0, uv.x));
	}

	vec2 uvR = uv - 0.5;
	uvR = mgRotate(uvR, -3.0 * uSwirl * radius);
	uvR += 0.5;

	vec3 colour = vec3(0.0);
	float opacity = 0.0;
	float total = 0.0;
	int n = clamp(uColoursCount, 1, 5);
	for (int i = 0; i < n; i++)
	{
		vec2 pos = mgPosition(i, t);
		float w = 1.0 / (pow(length((uvR - pos) * asp), 3.5) + 1e-3);
		colour += uColours[i].rgb * uColours[i].a * w;
		opacity += uColours[i].a * w;
		total += w;
	}
	colour /= max(1e-4, total);
	opacity = clamp(opacity / max(1e-4, total), 0.0, 1.0);

	fragColor = vec4(colour, opacity);
}