// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template transition

// #color label="Edge Colour" default="#FFFFFF"
uniform vec4 uEdgeColor;

// #choice label="Shape" group={"Shape", "circle.hexagongrid"} options="Ellipse,Rectangle,Rounded Rectangle,Diamond,Hexagon,Starburst" dropdown default=0
uniform int uShape;

// #choice label="Mode" group="Shape" options="Open,Close" default=0
uniform int uMode;

// #point label="Center" group="Shape" osc=position default="0.5,0.5"
uniform vec2 uCenter;

// #angle label="Rotation" group="Shape" osc={z} link=uCenter default=0
uniform float uRotation;

// #multi label="Proportions" group="Shape" fields={W,H} percent min=10 max=300 default="100,100"
uniform vec2 uProportions;

// #percent label="Roundness" group="Shape" visibleby=uShape visiblevalues={2} min=0 max=100 default=50
uniform float uRoundness;

// #int label="Star Points" group="Shape" visibleby=uShape visiblevalues={5} min=3 max=16 default=5
uniform float uStarPoints;

// #percent label="Star Inset" group="Shape" visibleby=uShape visiblevalues={5} min=10 max=90 default=45
uniform float uStarInset;

// #int label="Feather" group={"Edge", "sparkles"} units="px" min=0 slidermax=100 default=4
uniform float uFeather;

// #int label="Edge Width" group="Edge" units="px" min=0 slidermax=100 default=0
uniform float uEdgeWidth;

// #percent label="Edge Glow" group="Edge" min=0 max=400 slidermax=200 default=0
uniform float uEdgeGlow;

const float TAU = 6.28318530718;

vec2 rotate2(vec2 position, float angle)
{
	float sine = sin(angle);
	float cosine = cos(angle);
	return mat2(cosine, -sine, sine, cosine) * position;
}

float shapeMetric(vec2 position)
{
	vec2 proportions = max(uProportions, vec2(0.01));
	vec2 point = rotate2(position, -uRotation) / proportions;
	vec2 absolutePoint = abs(point);

	if (uShape == 1)
		return max(absolutePoint.x, absolutePoint.y);

	if (uShape == 2)
	{
		float exponent = mix(12.0, 2.0, uRoundness);
		return pow(pow(absolutePoint.x, exponent) + pow(absolutePoint.y, exponent), 1.0 / exponent);
	}

	if (uShape == 3)
		return absolutePoint.x + absolutePoint.y;

	if (uShape == 4)
		return max(absolutePoint.y, absolutePoint.x * 0.8660254 + absolutePoint.y * 0.5);

	if (uShape == 5)
	{
		float radius = length(point);
		float angle = atan(point.y, point.x) - 1.57079633;
		float points = max(float(uStarPoints), 3.0);
		float wave = 0.5 + 0.5 * cos(angle * points);
		float boundary = mix(uStarInset, 1.0, wave);
		return radius / max(boundary, 0.01);
	}

	return length(point);
}

float maximumMetric()
{
	vec2 resolution = iResolution.xy;
	vec2 center = uCenter;
	float inverseHeight = 1.0 / resolution.y;

	vec2 bottomLeft = (vec2(0.0, 0.0) - center) * inverseHeight;
	vec2 bottomRight = (vec2(resolution.x, 0.0) - center) * inverseHeight;
	vec2 topLeft = (vec2(0.0, resolution.y) - center) * inverseHeight;
	vec2 topRight = (resolution - center) * inverseHeight;

	float maximum = shapeMetric(bottomLeft);
	maximum = max(maximum, shapeMetric(bottomRight));
	maximum = max(maximum, shapeMetric(topLeft));
	maximum = max(maximum, shapeMetric(topRight));

	return maximum;
}

float insideShape(float metric, float threshold, float feather)
{
	if (feather <= 0.000001)
		return 1.0 - step(threshold, metric);

	return 1.0 - smoothstep(threshold - feather, threshold + feather, metric);
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

	vec2 position = (fragCoord - uCenter) / iResolution.y;
	float metric = shapeMetric(position);
	float maximum = maximumMetric();

	float threshold = uMode == 0 ? maximum * progress : maximum * (1.0 - progress);
	float proportionScale = max(min(uProportions.x, uProportions.y), 0.01);
	float feather = uFeather / 1080.0 / proportionScale;
	float inside = insideShape(metric, threshold, feather);
	float reveal = uMode == 0 ? inside : 1.0 - inside;

	vec4 color = mixTransitionColors(fromColor, toColor, reveal);

	float edgeWidth = uEdgeWidth / 1080.0 / proportionScale;

	if (edgeWidth > 0.0)
	{
		float antialiasing = fwidth(metric);
		float edge = 1.0 - smoothstep(edgeWidth, edgeWidth + antialiasing, abs(metric - threshold));
		// Gated by coverage for the same reason the glow below is: in In/Out mode
		// one endpoint is transparent, and an edge line drawn there is a shape
		// outline floating over nothing.
		float edgeAlpha = edge * uEdgeColor.a * max(fromColor.a, toColor.a);

		color = compositeTransitionLayer(color, vec4(uEdgeColor.rgb, edgeAlpha));
		// Gated by coverage: an additive term on .rgb alone leaves rgb above alpha,
		// which is not a valid premultiplied pixel. In In/Out mode one endpoint is
		// transparent, so ungated this paints onto transparent black.
		color.rgb += uEdgeColor.rgb * edge * uEdgeGlow * max(fromColor.a, toColor.a);
	}

	fragColor = color;
}
