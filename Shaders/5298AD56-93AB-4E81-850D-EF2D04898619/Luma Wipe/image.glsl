// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template transition

// #color label="Edge Colour" default="#FFFFFF"
uniform vec4 uEdgeColor;

// #choice label="Luma Source" group={"Matte", "circle.lefthalf.filled"} options="Outgoing,Incoming,Mixed" default=0
uniform int uMapSource;

// #percent label="Source Mix" group="Matte" visibleby=uMapSource visiblevalues={2} min=0 max=100 default=50
uniform float uMapMix;

// #choice label="Channel" group="Matte" options="Luminance,Red,Green,Blue,Saturation" dropdown default=0
uniform int uChannel;

// #choice label="Order" group="Matte" options="Darks First,Brights First" default=0
uniform int uOrder;

// #float label="Contrast" group="Matte" min=0.25 max=4 default=1
uniform float uContrast;

// `pick=luma` works here because Pivot is the tone the map is MEASURED AGAINST,
// not a shift added to it: the eyedropper writes the clicked tone and the wipe
// centres its contrast rotation there, so clicking the tone you want the wipe
// to break on does exactly that. `luma` rather than `luma-linear` because the
// map is Rec.709-ish luma of the display-encoded source, the same space the
// picked probe reports.
// #percent label="Pivot" group="Matte" min=0 max=100 default=50 pick=luma
uniform float uPivot;

// #int label="Map Blur" group="Matte" units="px" min=0 slidermax=50 default=0
uniform float uMapBlur;

// #percent label="Softness" group={"Edge", "sparkles"} min=0 max=50 default=8
uniform float uSoftness;

// #percent label="Edge Width" group="Edge" min=0 max=25 default=0
uniform float uEdgeWidth;

// #percent label="Edge Glow" group="Edge" min=0 max=400 slidermax=200 default=0
uniform float uEdgeGlow;

vec3 mapColor(vec2 uv)
{
	vec3 outgoing = texture(iChannel0, clamp(uv, 0.0, 1.0)).rgb;

	if (uMapSource == 0)
		return outgoing;

	vec3 incoming = texture(iChannel1, clamp(uv, 0.0, 1.0)).rgb;

	if (uMapSource == 1)
		return incoming;

	return mix(outgoing, incoming, uMapMix);
}

float channelValue(vec3 color)
{
	if (uChannel == 1)
		return color.r;

	if (uChannel == 2)
		return color.g;

	if (uChannel == 3)
		return color.b;

	if (uChannel == 4)
	{
		float maximum = max(color.r, max(color.g, color.b));
		float minimum = min(color.r, min(color.g, color.b));
		return maximum - minimum;
	}

	return dot(color, vec3(0.299, 0.587, 0.114));
}

float mapValue(vec2 uv)
{
	if (uMapBlur <= 0)
		return channelValue(mapColor(uv));

	vec2 offset = vec2(uMapBlur * iResolution.y / 1080.0) / iResolution.xy;
	float value = channelValue(mapColor(uv)) * 4.0;

	value += channelValue(mapColor(uv + vec2(offset.x, 0.0))) * 2.0;
	value += channelValue(mapColor(uv + vec2(-offset.x, 0.0))) * 2.0;
	value += channelValue(mapColor(uv + vec2(0.0, offset.y))) * 2.0;
	value += channelValue(mapColor(uv + vec2(0.0, -offset.y))) * 2.0;

	value += channelValue(mapColor(uv + vec2(offset.x, offset.y)));
	value += channelValue(mapColor(uv + vec2(-offset.x, offset.y)));
	value += channelValue(mapColor(uv + vec2(offset.x, -offset.y)));
	value += channelValue(mapColor(uv + vec2(-offset.x, -offset.y)));

	return value / 16.0;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;
	float progress = clamp(iProgress, 0.0, 1.0);

	vec4 fromColor = texture(iChannel0, uv);
	vec4 toColor = texture(iChannel1, uv);

	if (progress <= 0.0)
	{
		fragColor = fromColor;
		return;
	}

	if (progress >= 1.0)
	{
		fragColor = toColor;
		return;
	}

	float value = mapValue(uv);
	value = clamp(0.5 + (value - uPivot) * uContrast, 0.0, 1.0);

	if (uOrder == 1)
		value = 1.0 - value;

	float softness = max(uSoftness, 0.0001);
	float threshold = mix(-softness, 1.0 + softness, progress);
	float reveal = 1.0 - smoothstep(threshold - softness, threshold + softness, value);

	vec4 color = mixTransitionColors(fromColor, toColor, reveal);

	if (uEdgeWidth > 0.0001)
	{
		float antialiasing = max(fwidth(value), 1.0 / iResolution.y);
		float edge = 1.0 - smoothstep(uEdgeWidth, uEdgeWidth + antialiasing, abs(value - threshold));
		// Gated by coverage for the same reason the glow below is: in In/Out mode
		// one endpoint is transparent, and an edge line drawn there is a wipe seam
		// floating over nothing.
		float edgeAlpha = edge * uEdgeColor.a * max(fromColor.a, toColor.a);

		color = compositeTransitionLayer(color, vec4(uEdgeColor.rgb, edgeAlpha));
		// Gated by coverage: an additive term on .rgb alone leaves rgb above alpha,
		// which is not a valid premultiplied pixel. In In/Out mode one endpoint is
		// transparent, so ungated this paints onto transparent black.
		color.rgb += uEdgeColor.rgb * edge * uEdgeGlow * max(fromColor.a, toColor.a);
	}

	fragColor = color;
}
