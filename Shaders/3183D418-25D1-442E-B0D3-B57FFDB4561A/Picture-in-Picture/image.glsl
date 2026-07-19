// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT
//
// Picture-in-picture. Apply to a clip stacked above your backplate: it draws
// itself small at the draggable Position (with shape, crop, border and drop
// shadow) and stays transparent elsewhere, so FCP's lane compositing keeps the
// clip beneath visible around it.

// #alpha

// #choice label="Shape" options="Rectangle,Square,Circle,Hexagon" default=0
uniform int uShape;

// #point label="Position" osc default="0.5,0.5"
uniform vec2 uPosition;

// #percent label="Size" min=0 default=28 osc=ring link=uPosition
uniform float uSize;

// #multi label="Crop Size" fields={W,H} percent min=0 default="100,100" lockaspect
uniform vec2 uCropSize;

// #multi label="Crop Center" fields={X,Y} percent default="50,50"
uniform vec2 uCropCenter;

// #percent label="Corner Radius" min=0 default=12
uniform float uRadius;

// #int label="Border" min=0 slidermax=20 default=8
uniform float uBorder;

// #color label="Border Colour" default="#FFFFFF"
uniform vec4 uBorderColor;

// #percent label="Shadow" min=0 default=55
uniform float uShadow;

// #int label="Shadow Blur" min=0 slidermax=50 default=22
uniform float uShadowBlur;

// #multi label="Shadow Offset" fields={X,Y} int default="0,-10"
uniform vec2 uShadowOffset;

// #color label="Shadow Colour" default="#333333"
uniform vec4 uShadowColor;

float sdRoundedRect(vec2 p, vec2 h, float r)
{
	r = min(r, min(h.x, h.y));
	vec2 d = abs(p) - h + r;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r;
}

float sdHexagon(vec2 p, float r)
{
	const vec3 k = vec3(-0.8660254, 0.5, 0.5773503);
	p = abs(p);
	p -= 2.0 * min(dot(k.xy, p), 0.0) * k.xy;
	p -= vec2(clamp(p.x, -k.z * r, k.z * r), r);
	return length(p) * sign(p.y);
}

float shapeSDF(vec2 p, vec2 h, float r, int shape)
{
	if (shape == 1) // Square
		return sdRoundedRect(p, vec2(min(h.x, h.y)), r);
	if (shape == 2) // Circle
		return length(p) - min(h.x, h.y);
	if (shape == 3) // Hexagon
		return sdHexagon(p, min(h.x, h.y));
	return sdRoundedRect(p, h, r); // Rectangle
}

void mainImage(out vec4 O, in vec2 fc)
{
	vec2 res = iResolution.xy;

	// Inset box, keeping the frame's aspect (width drives, height follows).
	vec2 h = vec2(res.x * uSize) * 0.5;
	h.y *= res.y / res.x;

	vec2 c = uPosition; // draggable position, #point delivers pixels
	vec2 p = fc - c;

	float r = uRadius * min(h.x, h.y);
	float d = shapeSDF(p, h, r, uShape);

	vec2 uv = (p / h) * 0.5 + 0.5; // 0..1 across the box
	vec2 cs = uCropSize; // already 0..1
	vec2 cc = uCropCenter; // already 0..1
	vec2 src = cc + (uv - 0.5) * cs;
	vec4 pip = texture(iChannel0, src);
	vec2 ib = step(vec2(0.0), src) * step(src, vec2(1.0));
	pip.rgb *= ib.x * ib.y; // outside the source frame reads black, not edge-smear

	float aa = 1.5;
	float inside = 1.0 - smoothstep(-aa, aa, d);
	float outer = 1.0 - smoothstep(-aa, aa, d - uBorder);
	vec3 contentRGB = mix(uBorderColor.rgb, pip.rgb, inside);
	float contentA = max(inside, outer * uBorderColor.a);

	// Shadow: same shape, offset + blurred, behind the content.
	float ds = shapeSDF(p - uShadowOffset, h + uBorder, r, uShape);
	float blur = max(uShadowBlur, 0.5);
	float shA = (1.0 - smoothstep(-blur, blur, ds)) * uShadow * uShadowColor.a;

	// Content OVER shadow, straight alpha (wrapper premultiplies on output).
	float outA = contentA + shA * (1.0 - contentA);
	vec3 outRGB = (contentRGB * contentA + uShadowColor.rgb * shA * (1.0 - contentA)) / max(outA, 1e-4);
	O = vec4(outRGB, outA);
}