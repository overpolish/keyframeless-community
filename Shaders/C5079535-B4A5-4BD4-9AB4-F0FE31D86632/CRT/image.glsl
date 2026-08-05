// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template filter

// #alpha
// #grain label="Noise" group="Display" default=0 size=1

// #percent label="Curvature" group={"Geometry", "viewfinder"} min=0 max=100 default=30 osc=ring
uniform float uCurve;

// #percent label="Scanlines" group={"Display", "display"} min=0 max=100 default=60
uniform float uScan;

// #int label="Scanline Size" group="Display" units="px" min=1 max=8 default=1
uniform int uScanSize;

// #percent label="Mask" group="Display" min=0 max=100 default=40
uniform float uMask;

// #percent label="Vignette" group={"Lens", "camera.filters"} min=0 max=100 default=50
uniform float uVignette;

// #percent label="Chroma" group="Lens" min=0 max=100 default=30
uniform float uChroma;

const float PI = 3.14159265359;

void mirageFilterImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;
	vec2 centered = uv * 2.0 - 1.0;

	centered *= 1.0 + uCurve * 0.25 * dot(centered, centered);
	vec2 samplePosition = centered * 0.5 + 0.5;

	bool outside =
	    samplePosition.x < 0.0 ||
	    samplePosition.x > 1.0 ||
	    samplePosition.y < 0.0 ||
	    samplePosition.y > 1.0;

	if (outside)
	{
		fragColor = vec4(0.0);
		return;
	}

	vec2 chromaOffset = (samplePosition - 0.5) * uChroma * 0.02;

	vec4 source = texture(iChannel0, samplePosition);
	vec3 color;
	color.r = texture(iChannel0, clamp(samplePosition + chromaOffset, 0.0, 1.0)).r;
	color.g = texture(iChannel0, samplePosition).g;
	color.b = texture(iChannel0, clamp(samplePosition - chromaOffset, 0.0, 1.0)).b;

	float scanSize = max(float(uScanSize) * iResolution.y / 1080.0, 1.0);
	float scanPhase = fragCoord.y * PI / scanSize;
	float scanline = 0.5 + 0.5 * sin(scanPhase);
	color *= 1.0 - uScan * 0.6 * scanline;

	float stripe = mod(fragCoord.x, 3.0);
	vec3 apertureMask = vec3(0.85);

	if (stripe < 1.0)
		apertureMask.r = 1.2;
	else if (stripe < 2.0)
		apertureMask.g = 1.2;
	else
		apertureMask.b = 1.2;

	color *= mix(vec3(1.0), apertureMask, uMask);

	float vignette =
	    1.0 -
	    uVignette *
	    0.4 *
	    dot(centered, centered);

	color *= clamp(vignette, 0.0, 1.0);

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
