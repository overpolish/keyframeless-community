// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template transition

// #motionblur on

// #color label="Blade Colour" default="#151820"
uniform vec4 uBladeColor;

// #color label="Blade Highlight" default="#77808F"
uniform vec4 uHighlightColor;

// #choice label="Mode" group={"Iris", "camera.aperture"} options="Open,Close" default=0
uniform int uMode;

// #point label="Center" group="Iris" osc=position default="0.5,0.5"
uniform vec2 uCenter;

// #int label="Blades" group="Iris" min=3 max=16 default=6
uniform float uBlades;

// #multi label="Proportions" group="Iris" fields={W,H} percent min=20 max=300 default="100,100"
uniform vec2 uProportions;

// #percent label="Curvature" group="Iris" min=0 max=100 default=20
uniform float uCurvature;

// #angle label="Rotation" group="Iris" osc={z} link=uCenter default=0
uniform float uRotation;

// #choice label="Direction" group="Iris" options="Clockwise,Counterclockwise" default=0
uniform int uDirection;

// #angle label="Twist" group="Iris" default=45
uniform float uTwist;

// #percent label="Blade Depth" group={"Blades", "circle.hexagongrid"} min=0 max=50 default=16
uniform float uBladeDepth;

// #percent label="Blade Opacity" group="Blades" min=0 max=100 default=90
uniform float uBladeOpacity;

// #percent label="Seams" group="Blades" min=0 max=30 default=8
uniform float uSeams;

// #int label="Feather" group={"Edge", "sparkles"} units="px" min=0 slidermax=50 default=2
uniform float uFeather;

// #percent label="Edge Glow" group="Edge" min=0 max=400 slidermax=200 default=25
uniform float uEdgeGlow;

const float PI = 3.14159265359;
const float TAU = 6.28318530718;

vec2 rotate2(vec2 position, float angle)
{
	float sine = sin(angle);
	float cosine = cos(angle);
	return mat2(cosine, -sine, sine, cosine) * position;
}

float apertureMetric(vec2 position, float rotation)
{
	vec2 proportions = max(uProportions, vec2(0.01));
	vec2 point = rotate2(position, -rotation) / proportions;

	float radius = length(point);
	float angle = atan(point.y, point.x);
	float blades = max(float(uBlades), 3.0);
	float sector = TAU / blades;
	float localAngle = mod(angle + 0.5 * sector, sector) - 0.5 * sector;
	float polygon = radius * cos(localAngle) / max(cos(PI / blades), 0.001);

	return mix(polygon, radius, uCurvature);
}

float maximumMetric(float rotation)
{
	vec2 resolution = iResolution.xy;
	vec2 center = uCenter;
	float inverseHeight = 1.0 / resolution.y;

	vec2 bottomLeft = (vec2(0.0, 0.0) - center) * inverseHeight;
	vec2 bottomRight = (vec2(resolution.x, 0.0) - center) * inverseHeight;
	vec2 topLeft = (vec2(0.0, resolution.y) - center) * inverseHeight;
	vec2 topRight = (resolution - center) * inverseHeight;

	float maximum = apertureMetric(bottomLeft, rotation);
	maximum = max(maximum, apertureMetric(bottomRight, rotation));
	maximum = max(maximum, apertureMetric(topLeft, rotation));
	maximum = max(maximum, apertureMetric(topRight, rotation));

	return maximum;
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

	float direction = uDirection == 0 ? 1.0 : -1.0;
	float twistProgress = uMode == 0 ? progress : 1.0 - progress;
	float rotation = uRotation + direction * abs(uTwist) * twistProgress;

	vec2 position = (fragCoord - uCenter) / iResolution.y;
	float metric = apertureMetric(position, rotation);
	float maximum = maximumMetric(rotation);
	float threshold = uMode == 0 ? maximum * progress : maximum * (1.0 - progress);

	float proportionScale = max(min(uProportions.x, uProportions.y), 0.01);
	float feather = float(uFeather) / iResolution.y / proportionScale;
	float inside;

	if (feather <= 0.000001)
		inside = 1.0 - step(threshold, metric);
	else
		inside = 1.0 - smoothstep(threshold - feather, threshold + feather, metric);

	float reveal = uMode == 0 ? inside : 1.0 - inside;
	vec4 color = mixTransitionColors(fromColor, toColor, reveal);

	vec2 bladePoint = rotate2(position, -rotation) / max(uProportions, vec2(0.01));
	float bladeAngle = atan(bladePoint.y, bladePoint.x);
	float blades = max(float(uBlades), 3.0);
	float sectorPosition = fract(bladeAngle / TAU * blades + 0.5);
	float seamDistance = min(sectorPosition, 1.0 - sectorPosition);

	float bladeWidth = maximum * uBladeDepth;
	float distanceToEdge = abs(metric - threshold);
	float bladeBand = 1.0 - smoothstep(0.0, max(bladeWidth, 0.0001), distanceToEdge);

	float seamWidth = max(uSeams * 0.2, 0.0001);
	float seam = 1.0 - smoothstep(0.0, seamWidth, seamDistance);
	float bladeGradient = smoothstep(0.0, 1.0, sectorPosition);
	float edgeAntialiasing = max(fwidth(metric), 1.0 / iResolution.y);
	float edge = 1.0 - smoothstep(0.0, edgeAntialiasing * 3.0 + feather, distanceToEdge);

	vec3 bladeColor = mix(uBladeColor.rgb, uHighlightColor.rgb, bladeGradient * 0.35);
	bladeColor *= 1.0 - seam * 0.45;
	bladeColor = mix(bladeColor, uHighlightColor.rgb, edge * 0.55);

	float bladeEnvelope = pow(max(sin(progress * PI), 0.0), 0.45);
	// Gated by coverage for the same reason the glow below is: in In/Out mode one
	// endpoint is transparent, and blades drawn there are an iris floating over
	// nothing.
	float bladeAlpha =
	    bladeBand *
	    uBladeOpacity *
	    bladeEnvelope *
	    uBladeColor.a *
	    max(fromColor.a, toColor.a);

	color = compositeTransitionLayer(color, vec4(bladeColor, bladeAlpha));
	// Gated by coverage: an additive term on .rgb alone leaves rgb above alpha,
	// which is not a valid premultiplied pixel. In In/Out mode one endpoint is
	// transparent, so ungated this paints onto transparent black.
	color.rgb += uHighlightColor.rgb * edge * uEdgeGlow * bladeEnvelope * max(fromColor.a, toColor.a);

	fragColor = color;
}