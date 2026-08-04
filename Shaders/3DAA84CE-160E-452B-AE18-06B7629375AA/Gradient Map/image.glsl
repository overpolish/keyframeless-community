// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template filter

// #alpha
// #gradient label="Colours" default="#0B1026,#3A2E6B,#C0466B,#F2A65A,#FFF3C0"
uniform vec4 uColours[8];

// #percent label="Contrast" group={"Mapping", "circle.lefthalf.filled"} min=0 max=200 default=100
uniform float uContrast;

// #bool label="Reverse" group="Mapping" default=0
uniform bool uReverse;

// #percent label="Mix" group={"Output", "slider.horizontal.below.rectangle"} min=0 max=100 default=100
uniform float uMix;

void mirageFilterImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;
	vec4 source = texture(iChannel0, uv);

	float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	luminance = (luminance - 0.5) * uContrast + 0.5;
	luminance = clamp(luminance, 0.0, 1.0);

	if (uReverse)
		luminance = 1.0 - luminance;

	vec3 mapped = uColoursAt(luminance);
	vec3 color = mix(source.rgb, mapped, uMix);

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
