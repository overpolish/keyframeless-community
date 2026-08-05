// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// Uniform-prefix parity with Image. Controls are authored by Image; these
// declarations keep every pass reading the same scalar-pool offsets.
// #percent label="Threshold" min=0 max=100 default=45
uniform float uThresh;
// #percent label="Intensity" min=0 max=200 default=80
uniform float uIntensity;
// #int label="Radius" units="px" min=1 max=600 slidermax=200 default=14
uniform float uSize;
// #int label="Quality" min=8 max=48 default=24
uniform int uSamples;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;
	vec4 source = texture(iChannel0, uv);
	vec3 straight = source.a > 0.0001 ? source.rgb / source.a : vec3(0.0);
	float luminance = dot(straight, vec3(0.2126, 0.7152, 0.0722));

	// A soft knee avoids a bright contour where pixels cross the threshold.
	float knee = 0.10;
	float highlight = smoothstep(uThresh - knee, uThresh + knee, luminance);
	fragColor = vec4(source.rgb * highlight, source.a * highlight);
}
