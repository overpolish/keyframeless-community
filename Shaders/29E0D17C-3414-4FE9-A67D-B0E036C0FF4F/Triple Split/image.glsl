// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template layout

// #alpha
// #motionblur on

// #choice label="Panel" group={"Layout", "rectangle.split.3x1"} options="Panel A,Panel B,Panel C" default=0
uniform int uPanel;

// #choice label="Direction" group="Layout" options="Columns,Rows" default=0
uniform int uDirection;

// #percent label="First Divider" group="Layout" min=5 max=95 default=33
uniform float uFirstSplit;

// #percent label="Second Divider" group="Layout" min=5 max=95 default=67
uniform float uSecondSplit;

// #point label="Position" group={"Content", "crop"} default="0.5,0.5"
uniform vec2 uPosition;

// #multi label="Crop Size" group="Content" fields={W,H} percent min={0,0} max={400,400} default="100,100" lockaspect
uniform vec2 uCropSize;

// #multi label="Crop Center" group="Content" fields={X,Y} percent default="50,50"
uniform vec2 uCropCenter;

// #float label="Gap" group={"Dividers", "square.dashed"} units="px" min=0 max=200 slidermax=50 default=8
uniform float uGap;

// #color label="Gap Colour" default="#FFFFFF"
uniform vec4 uGapColor;

// #percent label="Corner Radius" group="Layout" min=0 max=100 default=0
uniform float uRadius;

// #float label="Feather" group="Layout" units="px" min=0 max=100 slidermax=30 default=0
uniform float uFeather;

// @osc Position
//   primitive = position
//   binds = uPosition
//   first = min(uFirstSplit, uSecondSplit)
//   second = max(uFirstSplit, uSecondSplit)
//   low = uPanel == 0 ? 0.0 : (uPanel == 1 ? first : second)
//   high = uPanel == 0 ? first : (uPanel == 1 ? second : 1.0)
//   middle = (low + high) * 0.5
//   area = uDirection == 0 ? vec2(middle, 0.5) : vec2(0.5, middle)
//   toPos = area + uPosition - vec2(0.5)
//   fromPos = pos - area + vec2(0.5)

// @osc Crop Size
//   primitive = box
//   binds = uCropSize
//   body = none
//   linked = true
//   first = min(uFirstSplit, uSecondSplit)
//   second = max(uFirstSplit, uSecondSplit)
//   low = uPanel == 0 ? 0.0 : (uPanel == 1 ? first : second)
//   high = uPanel == 0 ? first : (uPanel == 1 ? second : 1.0)
//   middle = (low + high) * 0.5
//   area = uDirection == 0 ? vec2(middle, 0.5) : vec2(0.5, middle)
//   boxCenter = area + uPosition - vec2(0.5)
//   center = boxCenter
//   extent = ringExtent(uCropSize / 4.0)
//   boxExtent = extent * vec2(min(1.0, 1.0 / aspect), min(1.0, aspect))
//   dragExtent = max(boxCenter - rect.min, rect.max - boxCenter) * vec2(max(1.0, aspect), max(1.0, 1.0 / aspect))
//   toRect = rect(boxCenter - boxExtent, boxCenter + boxExtent)
//   fromRect = ringNorm(dragExtent) * 4.0

float sdRoundedRectangle(vec2 position, vec2 halfExtents, float radius)
{
	radius = min(radius, min(halfExtents.x, halfExtents.y));
	vec2 distanceToEdge = abs(position) - halfExtents + radius;

	return length(max(distanceToEdge, 0.0)) +
	       min(max(distanceToEdge.x, distanceToEdge.y), 0.0) -
	       radius;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 resolution = iResolution.xy;
	vec2 framePosition = fragCoord / resolution;

	float firstSplit = min(uFirstSplit, uSecondSplit);
	float secondSplit = max(uFirstSplit, uSecondSplit);

	float panelMinimum =
	    uPanel == 0
	    ? 0.0
	    : (uPanel == 1 ? firstSplit : secondSplit);

	float panelMaximum =
	    uPanel == 0
	    ? firstSplit
	    : (uPanel == 1 ? secondSplit : 1.0);

	float axisResolution =
	    uDirection == 0
	    ? resolution.x
	    : resolution.y;

	float gap = uGap * resolution.y / 1080.0;
	float halfGap = gap * 0.5 / axisResolution;

	if (uPanel > 0)
		panelMinimum += halfGap;

	if (uPanel < 2)
		panelMaximum -= halfGap;

	panelMaximum = max(panelMaximum, panelMinimum);

	float panelMiddle = (panelMinimum + panelMaximum) * 0.5;
	float panelExtent = (panelMaximum - panelMinimum) * 0.5;

	vec2 panelCenter;
	vec2 panelHalfSize;

	if (uDirection == 0)
	{
		panelCenter = vec2(panelMiddle, 0.5);
		panelHalfSize = vec2(panelExtent, 0.5);
	}
	else
	{
		panelCenter = vec2(0.5, panelMiddle);
		panelHalfSize = vec2(0.5, panelExtent);
	}

	vec2 panelCenterPixels = panelCenter * resolution;
	vec2 panelHalfSizePixels = panelHalfSize * resolution;
	float cornerRadius =
	    uRadius *
	    min(panelHalfSizePixels.x, panelHalfSizePixels.y);

	float panelDistance = sdRoundedRectangle(
	                          fragCoord - panelCenterPixels,
	                          panelHalfSizePixels,
	                          cornerRadius
	                      );

	float panelAntialiasing = max(fwidth(panelDistance), 0.75);
	float panelSoftness = max(uFeather * resolution.y / 1080.0, panelAntialiasing);

	float panelMask = 1.0 - smoothstep(
	                      -panelSoftness,
	                      panelSoftness,
	                      panelDistance
	                  );

	vec2 userOffset =
	    (uPosition - resolution * 0.5) /
	    resolution;

	vec2 contentCenter =
	    panelCenter +
	    userOffset;

	vec2 cropScale =
	    max(uCropSize, vec2(0.001));

	vec2 sourcePosition =
	    uCropCenter +
	    (framePosition - contentCenter) /
	    cropScale;

	vec2 sourceBounds =
	    step(vec2(0.0), sourcePosition) *
	    step(sourcePosition, vec2(1.0));

	float insideSource =
	    sourceBounds.x *
	    sourceBounds.y;

	vec4 source = texture(
	                  iChannel0,
	                  clamp(sourcePosition, 0.0, 1.0)
	              );

	float contentAlpha =
	    source.a *
	    panelMask *
	    insideSource;

	float axisPosition =
	    uDirection == 0
	    ? framePosition.x
	    : framePosition.y;

	float firstDividerDistance =
	    abs(axisPosition - firstSplit) *
	    axisResolution;

	float secondDividerDistance =
	    abs(axisPosition - secondSplit) *
	    axisResolution;

	float dividerDistance = min(
	                            firstDividerDistance,
	                            secondDividerDistance
	                        );

	float dividerAntialiasing = max(
	                                fwidth(dividerDistance),
	                                0.75
	                            );

	float dividerMask = 1.0 - smoothstep(
	                        gap * 0.5,
	                        gap * 0.5 + dividerAntialiasing,
	                        dividerDistance
	                    );

	dividerMask *= step(0.5, gap);

	float dividerAlpha =
	    dividerMask *
	    uGapColor.a;

	float outputAlpha =
	    dividerAlpha +
	    contentAlpha * (1.0 - dividerAlpha);

	vec3 premultipliedColor =
	    uGapColor.rgb * dividerAlpha +
	    source.rgb * contentAlpha * (1.0 - dividerAlpha);

	vec3 outputColor =
	    outputAlpha > 0.0001
	    ? premultipliedColor / outputAlpha
	    : vec3(0.0);

	fragColor = vec4(
	                outputColor,
	                outputAlpha
	            );
}
