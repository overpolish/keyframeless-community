// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #int label="Segments" min=2 max=24 default=6
uniform float uSegments;
// #angle label="Rotation" default=0 osc={z} link=uCenter
uniform float uRotation;
// #point label="Center" osc default="0.5,0.5"
uniform vec2 uCenter;

vec2 kMirror(vec2 v)
{
	v = abs(v);
	v = mod(v, 2.0);
	return mix(v, 2.0 - v, step(1.0, v));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;
	float aspect = iResolution.x / iResolution.y;
	vec2 c = uCenter / iResolution.xy;
	vec2 d = (uv - c) * vec2(aspect, 1.0);
	float ang = atan(d.y, d.x) - uRotation;
	float rad = length(d);
	float seg = 6.28318530718 / max(uSegments, 1.0);
	ang = mod(ang, seg);
	ang = abs(ang - seg * 0.5);
	vec2 nd = vec2(cos(ang), sin(ang)) * rad;
	vec2 suv = c + vec2(nd.x / aspect, nd.y);
	fragColor = texture(iChannel0, kMirror(suv));
}