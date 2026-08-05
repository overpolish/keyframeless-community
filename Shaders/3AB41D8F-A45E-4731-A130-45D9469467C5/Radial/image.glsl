// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template layout

// #alpha
// #motionblur on

// #choice label="Sectors" group={"Layout","circle.grid.cross"} options="2,3,4,5,6" default=1
uniform int uSectors;

// #int label="Sector" group="Layout" min=1 max=6 default=1 maxby=uSectors maxvalues={2,3,4,5,6}
uniform float uSector;

// #point label="Center" group="Layout" osc=position default="0.5,0.5"
uniform vec2 uCenter;

// #angle label="Rotation" group="Layout" osc={z} link=uCenter default=0
uniform float uRotation;

// #point label="Position" group={"Content","viewfinder"} default="0.5,0.5"
uniform vec2 uPosition;

// #multi label="Size" group="Content" fields={W,H} percent min={0,0} max={400,400} default="100,100" lockaspect
uniform vec2 uSize;

// #multi label="Crop Center" group="Content" fields={X,Y} percent default="50,50"
uniform vec2 uCropCenter;

// #float label="Divider" group={"Dividers","square.dashed"} units="px" min=0 max=200 slidermax=50 default=8
uniform float uDivider;

// #float label="Feather" group="Dividers" units="px" min=0 max=100 slidermax=30 default=0
uniform float uFeather;

// #color label="Divider Colour" default="#FFFFFF"
uniform vec4 uDividerColor;

// @osc Position
//   primitive = position
//   binds = uPosition
//   count = float(uSectors + 2)
//   index = clamp(uSector - 1.0, 0.0, count - 1.0)
//   angle = -uRotation * pi / 180.0 + index * 2.0 * pi / count
//   area = uCenter + vec2(cos(angle) / aspect, sin(angle)) * 0.24
//   toPos = area + uPosition - vec2(0.5)
//   fromPos = pos - area + vec2(0.5)

// @osc Size
//   primitive = box
//   binds = uSize
//   body = none
//   linked = true
//   count = float(uSectors + 2)
//   index = clamp(uSector - 1.0, 0.0, count - 1.0)
//   angle = -uRotation * pi / 180.0 + index * 2.0 * pi / count
//   area = uCenter + vec2(cos(angle) / aspect, sin(angle)) * 0.24
//   boxCenter = area + uPosition - vec2(0.5)
//   center = boxCenter
//   extent = ringExtent(uSize / 4.0)
//   boxExtent = extent * vec2(min(1.0, 1.0 / aspect), min(1.0, aspect))
//   dragExtent = max(boxCenter - rect.min, rect.max - boxCenter) * vec2(max(1.0, aspect), max(1.0, 1.0 / aspect))
//   toRect = rect(boxCenter - boxExtent, boxCenter + boxExtent)
//   fromRect = ringNorm(dragExtent) * 4.0

const float TAU = 6.28318530718;

float wrappedAngle(float angle)
{
	return mod(angle + 3.14159265359, TAU) - 3.14159265359;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 resolution = iResolution.xy;
	vec2 uv = fragCoord / resolution;
	float aspect = resolution.x / resolution.y;

	int sectorCount = uSectors + 2;
	int sectorIndex = clamp(
	                      int(floor(uSector + 0.5)) - 1,
	                      0,
	                      sectorCount - 1
	                  );

	vec2 center = uCenter / resolution;
	vec2 radialPosition = (uv - center) * vec2(aspect, 1.0);

	float radiusPixels =
	    length(radialPosition) *
	    resolution.y;

	float angle = atan(
	                  radialPosition.y,
	                  radialPosition.x
	              );

	float sectorAngle =
	    TAU /
	    float(sectorCount);

	float halfSectorAngle =
	    sectorAngle *
	    0.5;

	float selectedCenterAngle =
	    uRotation +
	    float(sectorIndex) *
	    sectorAngle;

	float selectedAngle = wrappedAngle(
	                          angle -
	                          selectedCenterAngle
	                      );

	float selectedEdgeDistance =
	    (halfSectorAngle - abs(selectedAngle)) *
	    radiusPixels;

	float selectedAntialiasing = max(
	                                 fwidth(selectedEdgeDistance),
	                                 0.75
	                             );

	float divider = uDivider * resolution.y / 1080.0;
	float feather = uFeather * resolution.y / 1080.0;
	float halfDivider = divider * 0.5;

	float sectorMask = smoothstep(
	                       halfDivider - feather - selectedAntialiasing,
	                       halfDivider,
	                       selectedEdgeDistance
	                   );

	float nearestSectorAngle = wrappedAngle(
	                               angle -
	                               uRotation
	                           );

	nearestSectorAngle = mod(
	                         nearestSectorAngle + halfSectorAngle,
	                         sectorAngle
	                     ) - halfSectorAngle;

	float nearestEdgeDistance =
	    (halfSectorAngle - abs(nearestSectorAngle)) *
	    radiusPixels;

	float dividerAntialiasing = max(
	                                fwidth(nearestEdgeDistance),
	                                0.75
	                            );

	float dividerMask = 1.0 - smoothstep(
	                        halfDivider,
	                        halfDivider + dividerAntialiasing,
	                        nearestEdgeDistance
	                    );

	dividerMask *= step(
	                   0.5,
	                   divider
	               );

	vec2 presetCenter = center +
	                    vec2(
	                        cos(selectedCenterAngle) / aspect,
	                        sin(selectedCenterAngle)
	                    ) * 0.24;

	vec2 contentCenter =
	    presetCenter +
	    uPosition / resolution -
	    vec2(0.5);

	vec2 scale =
	    max(uSize, vec2(0.001));

	vec2 sourcePosition =
	    uCropCenter +
	    (uv - contentCenter) /
	    scale;

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
	    sectorMask *
	    insideSource;

	float dividerAlpha =
	    dividerMask *
	    uDividerColor.a;

	float outputAlpha =
	    dividerAlpha +
	    contentAlpha *
	    (1.0 - dividerAlpha);

	vec3 premultipliedColor =
	    uDividerColor.rgb *
	    dividerAlpha +
	    source.rgb *
	    contentAlpha *
	    (1.0 - dividerAlpha);

	vec3 outputColor =
	    outputAlpha > 0.0001
	    ? premultipliedColor / outputAlpha
	    : vec3(0.0);

	fragColor = vec4(
	                outputColor,
	                outputAlpha
	            );
}
