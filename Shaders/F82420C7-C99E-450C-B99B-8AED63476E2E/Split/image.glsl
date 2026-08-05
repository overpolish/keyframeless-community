// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template layout

// #alpha
// #motionblur on

// #choice label="Layout" group={"Layout", "rectangle.split.2x1"} options="Area A,Area B" default=0
uniform int uLayout;

// #angle label="Rotation" group="Layout" osc={z} default=0
uniform float uRotation;

// #percent label="Split" group="Layout" min=0 max=100 default=50
uniform float uSplit;

// #point label="Position" group={"Content", "viewfinder"} default="0.5,0.5"
uniform vec2 uPosition;

// #multi label="Crop Size" group="Content" fields={W,H} percent min={0,0} max={400,400} default="100,100" lockaspect
uniform vec2 uCropSize;

// #multi label="Crop Center" group="Content" fields={X,Y} percent default="50,50"
uniform vec2 uCropCenter;

// #percent label="Feather" group="Layout" min=0 max=100 default=0
uniform float uFeather;

// #int label="Border" group={"Border", "square.dashed"} units="px" min=0 max=100 slidermax=40 default=0
uniform float uBorder;

// #color label="Border Colour" default="#FFFFFF"
uniform vec4 uBorderColor;

// #percent label="Border Reveal" group="Border" min=0 max=100 default=100
uniform float uReveal;

// @osc Position
//   primitive = position
//   binds = uPosition
//   angle = -uRotation * pi / 180.0
//   normal = vec2(cos(angle), sin(angle))
//   side = mix(-1.0, 1.0, float(uLayout))
//   span = aspect * abs(normal.x) + abs(normal.y)
//   split = (uSplit - 0.5) * span
//   edge = side * span * 0.5
//   areaP = normal * (split + edge) * 0.5
//   areaUV = vec2(0.5) + vec2(areaP.x / aspect, areaP.y)
//   toPos = areaUV + uPosition - vec2(0.5)
//   fromPos = pos - areaUV + vec2(0.5)

// @osc Crop Size
//   primitive = box
//   binds = uCropSize
//   body = none
//   linked = true
//   angle = -uRotation * pi / 180.0
//   normal = vec2(cos(angle), sin(angle))
//   side = mix(-1.0, 1.0, float(uLayout))
//   span = aspect * abs(normal.x) + abs(normal.y)
//   split = (uSplit - 0.5) * span
//   edge = side * span * 0.5
//   areaP = normal * (split + edge) * 0.5
//   areaUV = vec2(0.5) + vec2(areaP.x / aspect, areaP.y)
//   boxCenter = areaUV + uPosition - vec2(0.5)
//   center = boxCenter
//   extent = ringExtent(uCropSize / 4.0)
//   boxExtent = extent * vec2(min(1.0, 1.0 / aspect), min(1.0, aspect))
//   dragExtent = max(boxCenter - rect.min, rect.max - boxCenter) * vec2(max(1.0, aspect), max(1.0, 1.0 / aspect))
//   toRect = rect(boxCenter - boxExtent, boxCenter + boxExtent)
//   fromRect = ringNorm(dragExtent) * 4.0

vec2 lineChord(vec2 linePoint, vec2 direction, vec2 halfExtents)
{
	float minimum = -1e9;
	float maximum = 1e9;

	if (abs(direction.x) > 0.000001)
	{
		float first = (-halfExtents.x - linePoint.x) / direction.x;
		float second = (halfExtents.x - linePoint.x) / direction.x;
		minimum = max(minimum, min(first, second));
		maximum = min(maximum, max(first, second));
	}

	if (abs(direction.y) > 0.000001)
	{
		float first = (-halfExtents.y - linePoint.y) / direction.y;
		float second = (halfExtents.y - linePoint.y) / direction.y;
		minimum = max(minimum, min(first, second));
		maximum = min(maximum, max(first, second));
	}

	return vec2(minimum, maximum);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 resolution = iResolution.xy;
	float inverseHeight = 1.0 / resolution.y;
	float aspect = resolution.x * inverseHeight;
	vec2 position = (fragCoord - resolution * 0.5) * inverseHeight;

	vec2 normal = vec2(cos(uRotation), sin(uRotation));
	vec2 tangent = vec2(-normal.y, normal.x);
	float side = uLayout == 0 ? -1.0 : 1.0;

	float normalSpan = aspect * abs(normal.x) + abs(normal.y);
	float halfSpan = normalSpan * 0.5;
	float splitOffset = (uSplit - 0.5) * normalSpan;
	float signedDistance = dot(position, normal) - splitOffset;

	float feather = max(uFeather * 0.25, inverseHeight);
	float areaMask = smoothstep(-feather, feather, signedDistance * side);

	float outerProjection = side * halfSpan;
	float areaProjection = (splitOffset + outerProjection) * 0.5;
	vec2 areaCenter = resolution * 0.5 +
	                  normal * areaProjection * resolution.y;

	vec2 userOffset = uPosition - resolution * 0.5;
	vec2 contentCenter = areaCenter + userOffset;

	vec2 cropScale = max(uCropSize, vec2(0.001));
	vec2 sourcePosition = uCropCenter +
	                      ((fragCoord - contentCenter) / resolution) /
	                      cropScale;

	vec2 sourceBounds =
	    step(vec2(0.0), sourcePosition) *
	    step(sourcePosition, vec2(1.0));

	float insideSource = sourceBounds.x * sourceBounds.y;

	vec4 source = texture(
	                  iChannel0,
	                  clamp(sourcePosition, 0.0, 1.0)
	              );

	float contentAlpha = source.a * areaMask * insideSource;

	float halfBorderWidth = uBorder * inverseHeight * 0.5;
	vec2 frameHalfExtents = vec2(aspect, 1.0) * 0.5;

	vec2 firstChord = lineChord(
	                      (splitOffset + halfBorderWidth) * normal,
	                      tangent,
	                      frameHalfExtents
	                  );

	vec2 secondChord = lineChord(
	                       (splitOffset - halfBorderWidth) * normal,
	                       tangent,
	                       frameHalfExtents
	                   );

	float chordMinimum = min(firstChord.x, secondChord.x);
	float chordMaximum = max(firstChord.y, secondChord.y);

	float revealPosition =
	    (dot(position, tangent) - chordMinimum) /
	    max(chordMaximum - chordMinimum, 0.0001);

	float borderBand = 1.0 - smoothstep(
	                       halfBorderWidth,
	                       halfBorderWidth + 1.5 * inverseHeight,
	                       abs(signedDistance)
	                   );

	float revealAntialiasing = max(
	                               fwidth(revealPosition),
	                               0.0015
	                           );

	float revealFront = mix(
	                        -revealAntialiasing,
	                        1.0 + revealAntialiasing,
	                        uReveal
	                    );

	float revealMask = 1.0 - smoothstep(
	                       revealFront,
	                       revealFront + revealAntialiasing,
	                       revealPosition
	                   );

	float borderMask =
	    borderBand *
	    revealMask *
	    step(0.5, uBorder);

	float borderAlpha = borderMask * uBorderColor.a;

	float outputAlpha =
	    borderAlpha +
	    contentAlpha * (1.0 - borderAlpha);

	vec3 premultipliedColor =
	    uBorderColor.rgb * borderAlpha +
	    source.rgb * contentAlpha * (1.0 - borderAlpha);

	vec3 outputColor = outputAlpha > 0.0001
	                   ? premultipliedColor / outputAlpha
	                   : vec3(0.0);

	fragColor = vec4(outputColor, outputAlpha);
}