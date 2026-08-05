// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template filter

// #alpha
// #color-surface ring=light xaxis="Neutral,Tinted" yaxis="Clean,Halated"

// #percent label="Threshold" group={"Highlights","sun.max"} min=0 max=100 default=70 surface="y:-13" pick=luma
uniform float uThreshold;

// #percent label="Softness" group="Highlights" min=0 max=100 default=25
uniform float uSoftness;

// #percent label="Highlight Protection" group="Highlights" min=0 max=100 default=75
uniform float uProtection;

// #percent label="Intensity" group={"Halation","sparkles"} min=0 max=200 default=45 surface="y:+45"
uniform float uIntensity;

// #int label="Spread" group="Halation" units="px" min=1 slidermax=80 default=20
uniform float uSpread;

// #percent label="Warmth" group="Halation" min=0 max=100 default=80 surface="x:+20"
uniform float uWarmth;

// #color label="Halation Colour" default="#FF5428" pick=color
uniform vec4 uHaloColor;

// #percent label="Mix" group={"Finish","slider.horizontal.3"} min=0 max=100 default=100
uniform float uMix;

const vec3 HALATION_LUMA = vec3(0.2126, 0.7152, 0.0722);

float halationHighlight(float luminance)
{
	float knee = max(uSoftness * 0.25, 0.001);
	return smoothstep(uThreshold - knee, uThreshold + knee, luminance);
}

vec3 halationColor(vec3 color, float luminance)
{
	float energy = max(luminance, max(color.r, max(color.g, color.b)));
	return mix(color, uHaloColor.rgb * energy, uWarmth);
}

void mirageFilterImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;
	vec4 source = texture(iChannel0, uv);
	vec4 blurredHalo = texture(iChannel3, uv);

	vec3 straight = source.a > 0.0001 ? source.rgb / source.a : vec3(0.0);
	float sourceLuminance = dot(straight, HALATION_LUMA);
	float sourceHighlight = halationHighlight(sourceLuminance);
	vec3 protectedHighlight =
		halationColor(straight, sourceLuminance) * sourceHighlight *
		uProtection * source.a;

	vec3 halo = max(blurredHalo.rgb - protectedHighlight, vec3(0.0));
	halo *= uHaloColor.a;
	vec3 halated = source.rgb + halo * uIntensity * 1.5;
	fragColor = vec4(mix(source.rgb, halated, uMix), source.a);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	mirageFilterImage(fragColor, fragCoord);
	if (fragColor.a > 0.0001)
		fragColor.rgb /= fragColor.a;
	else
		fragColor.rgb = vec3(0.0);
}
