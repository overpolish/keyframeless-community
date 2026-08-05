// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// Uniform-prefix parity with Image.
// #percent label="Threshold" min=0 max=100 default=70
uniform float uThreshold;
// #percent label="Softness" min=0 max=100 default=25
uniform float uSoftness;
// #percent label="Highlight Protection" min=0 max=100 default=75
uniform float uProtection;
// #percent label="Intensity" min=0 max=200 default=45
uniform float uIntensity;
// #int label="Spread" units="px" min=1 slidermax=80 default=20
uniform float uSpread;
// #percent label="Warmth" min=0 max=100 default=80
uniform float uWarmth;
// #color label="Halation Colour" default="#FF5428"
uniform vec4 uHaloColor;
// #percent label="Mix" min=0 max=100 default=100
uniform float uMix;

const vec3 HALATION_LUMA = vec3(0.2126, 0.7152, 0.0722);

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec4 source = texture(iChannel0, fragCoord / iResolution.xy);
	vec3 straight = source.a > 0.0001 ? source.rgb / source.a : vec3(0.0);
	float luminance = dot(straight, HALATION_LUMA);
	float knee = max(uSoftness * 0.25, 0.001);
	float highlight = smoothstep(uThreshold - knee, uThreshold + knee, luminance);
	float energy = max(luminance, max(straight.r, max(straight.g, straight.b)));
	vec3 warm = mix(straight, uHaloColor.rgb * energy, uWarmth);
	fragColor = vec4(warm * source.a * highlight, source.a * highlight);
}
