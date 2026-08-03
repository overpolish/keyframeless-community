// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template filter

// #int label="Segments" group={"Kaleidoscope", "camera.aperture"} min=2 max=24 default=6
uniform float uSegments;

// #choice label="Edges" group="Kaleidoscope" options="Mirror,Clamp,Repeat" default=0
uniform int uEdges;

// #point label="Center" group={"Transform", "viewfinder"} osc=position default="0.5,0.5"
uniform vec2 uCenter;

// #angle label="Rotation" group="Transform" default=0 osc={z} link=uCenter
uniform float uRotation;

// #percent label="Scale" group="Transform" min=25 max=1600 slidermax=400 default=100 osc=ring link=uCenter
uniform float uScale;

const float TAU = 6.28318530718;

const int EDGES_MIRROR = 0;
const int EDGES_CLAMP = 1;
const int EDGES_REPEAT = 2;

vec2 mirrorRepeat(vec2 value)
{
	value = mod(abs(value), 2.0);
	return mix(value, 2.0 - value, step(1.0, value));
}

vec2 applyEdges(vec2 position)
{
	if (uEdges == EDGES_CLAMP)
		return clamp(position, 0.0, 1.0);

	if (uEdges == EDGES_REPEAT)
		return fract(position);

	return mirrorRepeat(position);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;
	vec2 center = uCenter / iResolution.xy;

	float aspect = iResolution.x / iResolution.y;
	vec2 delta = (uv - center) * vec2(aspect, 1.0);
	delta /= max(uScale, 0.01);

	float angle = atan(delta.y, delta.x) - uRotation;
	float radius = length(delta);
	float segmentSize = TAU / max(float(uSegments), 1.0);

	angle = mod(angle, segmentSize);
	angle = abs(angle - segmentSize * 0.5);

	vec2 mirrored = vec2(cos(angle), sin(angle)) * radius;

	vec2 samplePosition =
	    center +
	    vec2(
	        mirrored.x / aspect,
	        mirrored.y
	    );

	fragColor = texture(iChannel0, applyEdges(samplePosition));
}
