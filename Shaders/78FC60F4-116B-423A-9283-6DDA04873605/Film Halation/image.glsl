// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template filter

// #alpha
// The panel reads the frame's own luminance, which is exactly what a highlight
// threshold needs to be aimed against: the cloud shows where the speculars sit
// and the puck pulls the halation down onto them.
// #color-surface ring=light xaxis="Neutral,Tinted" yaxis="Clean,Halated"

// Threshold is compared against display-encoded Rec.709 luminance, which is the
// same quantity the eyedropper measures, so a picked highlight lands on it exactly.
// The smoothstep knee is Softness/4 - 6.25 points at the default - so a full pull
// toward Halated drops the gate by about two knee widths.
// #percent label="Threshold" group={"Highlights","sun.max"} min=0 max=100 default=70 surface="y:-13" pick=luma
uniform float uThreshold;

// #percent label="Softness" group="Highlights" min=0 max=100 default=25
uniform float uSoftness;

// #percent label="Highlight Protection" group="Highlights" min=0 max=100 default=75
uniform float uProtection;

// The halo is added as halo * Intensity * 1.5, so +45 points at full deflection is
// exactly a doubling of the glow from the default.
// #percent label="Intensity" group={"Halation","sparkles"} min=0 max=200 default=45 surface="y:+45"
uniform float uIntensity;

// #int label="Spread" group="Halation" units="px" min=1 slidermax=80 default=20
uniform float uSpread;

// Warmth is the mix toward Halation Colour, so the 20 points left above the default
// are the whole of the Tinted end.
// #percent label="Warmth" group="Halation" min=0 max=100 default=80 surface="x:+20"
uniform float uWarmth;

// #color label="Halation Colour" default="#FF5428" pick=color
uniform vec4 uHaloColor;

// #percent label="Mix" group={"Finish","slider.horizontal.3"} min=0 max=100 default=100
uniform float uMix;

float halationLuminance(vec3 color)
{
	return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

float halationHighlight(float luminance)
{
	float knee = max(uSoftness * 0.25, 0.001);
	return smoothstep(uThreshold - knee, uThreshold + knee, luminance);
}

vec3 halationColor(vec3 color, float luminance)
{
	float energy = max(luminance, max(color.r, max(color.g, color.b)));
	vec3 warm = uHaloColor.rgb * energy;
	return mix(color, warm, uWarmth);
}

void mirageFilterImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;
	vec4 source = texture(iChannel0, uv);

	vec3 halo = vec3(0.0);
	float totalWeight = 0.0;
	const float goldenAngle = 2.39996323;

	for (int i = 0; i < 32; ++i)
	{
		float index = float(i) + 0.5;
		float radiusFraction = sqrt(index / 32.0);
		float angle = index * goldenAngle;
		float radius = radiusFraction * uSpread;
		vec2 offset = vec2(cos(angle), sin(angle)) * radius / iResolution.xy;

		vec3 sampleColor = texture(iChannel0, clamp(uv + offset, 0.0, 1.0)).rgb;
		float luminance = halationLuminance(sampleColor);
		float highlight = halationHighlight(luminance);
		float weight = exp(-2.5 * radiusFraction * radiusFraction);

		halo += halationColor(sampleColor, luminance) * highlight * weight;
		totalWeight += weight;
	}

	halo /= max(totalWeight, 0.0001);

	float sourceLuminance = halationLuminance(source.rgb);
	float sourceHighlight = halationHighlight(sourceLuminance);
	vec3 protectedHighlight =
	    halationColor(source.rgb, sourceLuminance) * sourceHighlight * uProtection;

	halo = max(halo - protectedHighlight, vec3(0.0));
	halo *= uHaloColor.a;

	vec3 halated = source.rgb + halo * uIntensity * 1.5;
	vec3 color = mix(source.rgb, halated, uMix);

	fragColor = vec4(color, source.a);
}

// FxPlug supplies iChannel0 premultiplied. The filter body keeps doing its
// existing maths in that representation; #alpha then expects straight colour,
// so unwrap once here before Mirage premultiplies the final output.
void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	mirageFilterImage(fragColor, fragCoord);
	if (fragColor.a > 0.0001)
		fragColor.rgb /= fragColor.a;
	else
		fragColor.rgb = vec3(0.0);
}
