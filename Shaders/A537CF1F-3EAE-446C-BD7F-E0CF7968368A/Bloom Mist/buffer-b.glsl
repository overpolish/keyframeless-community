// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// Uniform-prefix parity with Image.
// #choice label="Quality" options="Draft,Standard,High" default=1
uniform int uQuality;
// #percent label="Threshold" min=0 max=100 default=58
uniform float uThreshold;
// #percent label="Softness" min=0 max=100 default=35
uniform float uSoftness;
// #int label="Radius" units="px" min=1 slidermax=120 default=36
uniform float uRadius;
// #percent label="Bloom" min=0 max=150 default=45
uniform float uBloom;
// #percent label="Diffusion" min=0 max=100 default=18
uniform float uDiffusion;
// #percent label="Mist" min=0 max=100 default=22
uniform float uMist;
// #percent label="Black Lift" min=0 max=100 default=6
uniform float uBlackLift;
// #percent label="Mix" min=0 max=100 default=100
uniform float uMix;
// #color label="Bloom Colour" default="#FFF2DE"
uniform vec4 uBloomColor;
// #float label="Warm / Cool" min=-100 max=100 default=0
uniform float uWarmCool;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;
	vec4 source = texture(iChannel0, uv);
	vec3 straight = source.a > 0.0001 ? source.rgb / source.a : vec3(0.0);
	float luminance = dot(straight, LUMA);
	float knee = max(uSoftness * 0.5, 0.0001);
	float highlight = smoothstep(uThreshold - knee, uThreshold + knee, luminance);
	fragColor = vec4(source.rgb * highlight, source.a * highlight);
}
