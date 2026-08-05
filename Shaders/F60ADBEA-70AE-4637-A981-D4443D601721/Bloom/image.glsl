// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template filter

// #alpha
// #percent label="Threshold" group={"Bloom", "sparkles"} min=0 max=100 default=45
uniform float uThresh;

// #percent label="Intensity" group="Bloom" min=0 max=200 default=80
uniform float uIntensity;

// #int label="Radius" group="Bloom" units="px" min=1 max=600 slidermax=200 default=14
uniform float uSize;

// #int label="Quality" group="Bloom" min=8 max=48 default=24
uniform int uSamples;

void mirageFilterImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;
	vec4 source = texture(iChannel0, uv);
	vec4 bloom = texture(iChannel3, uv);

	// Buffer D is a smooth, thresholded highlight blur. Add it as light rather
	// than compositing another picture over the source.
	vec3 color = source.rgb + bloom.rgb * uIntensity * 2.0;
	fragColor = vec4(color, source.a);
}

// FxPlug supplies iChannel0 premultiplied. The filter body keeps doing its
// maths in that representation; #alpha expects straight colour and performs
// the final premultiply itself.
void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	mirageFilterImage(fragColor, fragCoord);
	if (fragColor.a > 0.0001)
		fragColor.rgb /= fragColor.a;
	else
		fragColor.rgb = vec3(0.0);
}
