// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template layout

// #alpha
// #motionblur on

// #choice label="Arrangement" group={"Layout","rectangle.stack.fill"} options="Fan,Cascade,Scatter" default=0
uniform int uArrangement;

// #choice label="Cards" group="Layout" options="2,3,4,5" default=1
uniform int uCards;

// #int label="Card" group="Layout" min=1 max=5 default=1 maxby=uCards maxvalues={2,3,4,5}
uniform float uCard;

// #point label="Position" group={"Content","viewfinder"} default="0.5,0.5"
uniform vec2 uPosition;

// #multi label="Card Size" group="Content" fields={W,H} percent min={0,0} max={400,400} default="100,100" lockaspect
uniform vec2 uSize;

// #angle label="Rotation" group="Content" default=0
uniform float uRotation;

// #multi label="Crop Center" group="Content" fields={X,Y} percent default="50,50"
uniform vec2 uCropCenter;

// #percent label="Content Zoom" group="Content" min=1 max=400 default=100
uniform float uZoom;

// #percent label="Corner Radius" group={"Shape","squareshape"} min=0 max=100 default=6
uniform float uRadius;

// #float label="Feather" group="Shape" units="px" min=0 max=100 slidermax=30 default=0
uniform float uFeather;

// #float label="Border" group={"Border","square.dashed"} units="px" min=0 max=100 slidermax=40 default=6
uniform float uBorder;

// #color label="Border Colour" default="#FFFFFF"
uniform vec4 uBorderColor;

// #percent label="Shadow" group={"Shadow","app.shadow"} min=0 max=100 default=45
uniform float uShadow;

// #float label="Shadow Blur" group="Shadow" units="px" min=0 max=200 slidermax=80 default=24
uniform float uShadowBlur;

// A px field on a #multi is STORED as a frame fraction and only DISPLAYED in
// pixels, so the default and the slider span are both written in fractions:
// 0.00625 of the width and 0.011111 of the height are the 12 px the field
// reads at 1080p, and +/- 0.05 is roughly +/- 96 px across and +/- 54 px down.
// A literal "12,-12" is twelve frame widths, which parks the shadow off-screen
// while the control still reads as on.
// #multi label="Shadow Offset" group="Shadow" fields={X,Y} units={px,px} slidermin=-0.05 slidermax=0.05 default="0.00625,-0.011111"
uniform vec2 uShadowOffset;

// #color label="Shadow Colour" default="#00000099"
uniform vec4 uShadowColor;

// @osc Position
//   primitive = position
//   binds = uPosition
//   count = float(uCards + 2)
//   index = clamp(uCard - 1.0, 0.0, count - 1.0)
//   rank = index / max(count - 1.0, 1.0) - 0.5
//   fan = vec2(0.5 + rank * 0.58, 0.54 - abs(rank) * 0.16)
//   cascade = vec2(0.5 + rank * 0.48, 0.5 - rank * 0.34)
//   scatter = vec2(0.5) + vec2(sin((index + 1.0) * 12.7), sin((index + 1.0) * 31.3)) * 0.18
//   preset = uArrangement == 0 ? fan : (uArrangement == 1 ? cascade : scatter)
//   toPos = preset + uPosition - vec2(0.5)
//   fromPos = pos - preset + vec2(0.5)

// @osc Card Size
//   primitive = box
//   binds = uSize
//   body = none
//   linked = true
//   count = float(uCards + 2)
//   index = clamp(uCard - 1.0, 0.0, count - 1.0)
//   rank = index / max(count - 1.0, 1.0) - 0.5
//   fan = vec2(0.5 + rank * 0.58, 0.54 - abs(rank) * 0.16)
//   cascade = vec2(0.5 + rank * 0.48, 0.5 - rank * 0.34)
//   scatter = vec2(0.5) + vec2(sin((index + 1.0) * 12.7), sin((index + 1.0) * 31.3)) * 0.18
//   preset = uArrangement == 0 ? fan : (uArrangement == 1 ? cascade : scatter)
//   boxCenter = preset + uPosition - vec2(0.5)
//   center = boxCenter
//   extent = ringExtent(uSize / 4.0)
//   boxExtent = extent * vec2(min(1.0, 1.0 / aspect), min(1.0, aspect))
//   dragExtent = max(boxCenter - rect.min, rect.max - boxCenter) * vec2(max(1.0, aspect), max(1.0, 1.0 / aspect))
//   toRect = rect(boxCenter - boxExtent, boxCenter + boxExtent)
//   fromRect = ringNorm(dragExtent) * 4.0

// The render turns the card by presetAngle + uRotation, so the ring is drawn
// turned by the preset term too (angleOffset) or it reads out of phase with
// the card at Fan and Cascade. cardPreset()'s angles are in SHADER radians,
// which are radians(-degrees), so the display offset is their negated degrees.
// @osc Rotation
//   primitive = rotate
//   binds = uRotation
//   axes = z
//   count = float(uCards + 2)
//   index = clamp(uCard - 1.0, 0.0, count - 1.0)
//   rank = index / max(count - 1.0, 1.0) - 0.5
//   fan = vec2(0.5 + rank * 0.58, 0.54 - abs(rank) * 0.16)
//   cascade = vec2(0.5 + rank * 0.48, 0.5 - rank * 0.34)
//   scatter = vec2(0.5) + vec2(sin((index + 1.0) * 12.7), sin((index + 1.0) * 31.3)) * 0.18
//   preset = uArrangement == 0 ? fan : (uArrangement == 1 ? cascade : scatter)
//   cardCenter = preset + uPosition - vec2(0.5)
//   center = cardCenter
//   fanAngle = -rank * 0.45
//   cascadeAngle = rank * 0.12
//   scatterAngle = sin((index + 1.0) * 8.3) * 0.22
//   presetAngle = uArrangement == 0 ? fanAngle : (uArrangement == 1 ? cascadeAngle : scatterAngle)
//   angleOffset = -presetAngle * 180.0 / pi

float roundedSDF(vec2 point, vec2 halfSize, float radius, float radiusAmount)
{
	float power = mix(5.0, 2.0, radiusAmount);
	vec2 distance = abs(point) - halfSize + radius;
	vec2 outsideDistance = max(distance, 0.0);

	float outside = pow(
	                    pow(outsideDistance.x, power) +
	                    pow(outsideDistance.y, power),
	                    1.0 / power
	                ) - radius;

	return outside + min(max(distance.x, distance.y), 0.0);
}

float shapeMask(float distance, float feather)
{
	float antialias = max(fwidth(distance), 0.5);

	return 1.0 - smoothstep(
	           -feather,
	           feather + antialias * 2.0,
	           distance
	       );
}

void cardPreset(
    int index,
    int count,
    out vec2 center,
    out float angle
)
{
	float rank =
	    float(index) /
	    max(float(count - 1), 1.0) -
	    0.5;

	if (uArrangement == 0)
	{
		center = vec2(
		             0.5 + rank * 0.58,
		             0.54 - abs(rank) * 0.16
		         );

		angle = -rank * 0.45;
		return;
	}

	if (uArrangement == 1)
	{
		center = vec2(
		             0.5 + rank * 0.48,
		             0.5 - rank * 0.34
		         );

		angle = rank * 0.12;
		return;
	}

	float fi = float(index) + 1.0;

	center = vec2(0.5) +
	         vec2(
	             sin(fi * 12.7),
	             sin(fi * 31.3)
	         ) * 0.18;

	angle = sin(fi * 8.3) * 0.22;
}

vec2 inverseRotate(vec2 point, float angle)
{
	float cosine = cos(angle);
	float sine = sin(angle);

	return mat2(
	           cosine, -sine,
	           sine, cosine
	       ) * point;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 resolution = iResolution.xy;

	int cardCount = uCards + 2;
	int cardIndex = clamp(
	                    int(floor(uCard + 0.5)) - 1,
	                    0,
	                    cardCount - 1
	                );

	vec2 presetCenter;
	float presetAngle;

	cardPreset(
	    cardIndex,
	    cardCount,
	    presetCenter,
	    presetAngle
	);

	vec2 userOffset =
	    uPosition -
	    resolution * 0.5;

	vec2 cardCenter =
	    presetCenter * resolution +
	    userOffset;

	float angle =
	    presetAngle +
	    uRotation;

	vec2 scale =
	    max(uSize, vec2(0.001));

	vec2 halfSize =
	    resolution *
	    vec2(0.22) *
	    scale;

	float radius =
	    uRadius *
	    min(halfSize.x, halfSize.y);

	vec2 cardPosition = inverseRotate(
	                        fragCoord - cardCenter,
	                        angle
	                    );

	float cardDistance = roundedSDF(
	                         cardPosition,
	                         halfSize,
	                         radius,
	                         uRadius
	                     );

	float contentMask = shapeMask(
	                        cardDistance,
	                        max(uFeather, 0.0)
	                    );

	float outerMask = shapeMask(
	                      cardDistance - uBorder,
	                      max(uFeather, 0.0)
	                  );

	float borderMask = max(
	                       outerMask - contentMask,
	                       0.0
	                   );

	vec2 cardUV =
	    cardPosition /
	    (halfSize * 2.0) +
	    0.5;

	float zoom =
	    max(uZoom, 0.001);

	vec2 sourcePosition =
	    uCropCenter +
	    (cardUV - 0.5) /
	    zoom;

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
	    contentMask *
	    insideSource;

	float borderAlpha =
	    borderMask *
	    uBorderColor.a;

	float cardAlpha =
	    borderAlpha +
	    contentAlpha * (1.0 - borderAlpha);

	vec3 cardPremultiplied =
	    uBorderColor.rgb * borderAlpha +
	    source.rgb *
	    contentAlpha *
	    (1.0 - borderAlpha);

	vec2 shadowCenter =
	    cardCenter +
	    uShadowOffset * resolution;

	vec2 shadowPosition = inverseRotate(
	                          fragCoord - shadowCenter,
	                          angle
	                      );

	float shadowDistance = roundedSDF(
	                           shadowPosition,
	                           halfSize,
	                           radius,
	                           uRadius
	                       ) - uBorder;

	float shadowSoftness =
	    max(uShadowBlur, 0.5);

	float shadowMask = 1.0 - smoothstep(
	                       -shadowSoftness,
	                       shadowSoftness,
	                       shadowDistance
	                   );

	float shadowAlpha =
	    shadowMask *
	    uShadow *
	    uShadowColor.a;

	float outputAlpha =
	    cardAlpha +
	    shadowAlpha * (1.0 - cardAlpha);

	vec3 premultipliedColor =
	    cardPremultiplied +
	    uShadowColor.rgb *
	    shadowAlpha *
	    (1.0 - cardAlpha);

	vec3 outputColor =
	    outputAlpha > 0.0001
	    ? premultipliedColor / outputAlpha
	    : vec3(0.0);

	fragColor = vec4(
	                outputColor,
	                outputAlpha
	            );
}