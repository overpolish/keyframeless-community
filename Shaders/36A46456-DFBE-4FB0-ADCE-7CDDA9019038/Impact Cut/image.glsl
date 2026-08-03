// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template transition

// #motionblur on

// #choice label="Motion" group={"Impact", "bolt.fill"} options="Punch In,Punch Out" default=0
uniform int uMotion;

// #percent label="Zoom" group="Impact" min=0 max=100 default=35
uniform float uZoom;

// #percent label="Shake" group="Impact" min=0 max=100 default=18
uniform float uShake;

// #percent label="Radial Blur" group={"Blur", "drop.halffull"} min=0 max=100 default=40
uniform float uBlur;

// #percent label="Chromatic Split" group="Blur" min=0 max=100 default=18
uniform float uChromatic;

// #percent label="Cut Position" group={"Timing", "clock"} min=10 max=90 default=50
uniform float uCut;

// #percent label="Flash" group={"Flash", "sun.max"} min=0 max=100 default=55
uniform float uFlash;

// #percent label="Flash Width" group="Flash" min=1 max=50 default=16
uniform float uFlashWidth;

// #color label="Flash Colour" default="#FFFFFF"
uniform vec4 uFlashColor;

// #point label="Center" osc=position default="0.5,0.5"
uniform vec2 uCenter;

vec2 impactTransform(vec2 uv, vec2 center, float amount, float progress)
{
	float direction = uMotion == 0 ? 1.0 : -1.0;
	float scale = max(1.0 + direction * uZoom * 0.38 * amount, 0.35);
	float rotation = sin(progress * 83.7 + 1.2) * uShake * 0.025 * amount;

	float s = sin(rotation);
	float c = cos(rotation);
	vec2 p = uv - center;
	p = mat2(c, -s, s, c) * p;
	p /= scale;

	vec2 shake = vec2(sin(progress * 117.0), cos(progress * 91.0 + 0.7));
	p += shake * uShake * 0.014 * amount;

	return p + center;
}

vec4 impactTap(vec2 uv, int channel)
{
	if (channel == 0)
		return texture(iChannel0, clamp(uv, 0.0, 1.0));

	return texture(iChannel1, clamp(uv, 0.0, 1.0));
}

vec4 impactSample(vec2 uv, vec2 center, float blurAmount, float chromaticAmount, int channel)
{
	vec4 color = vec4(0.0);
	float total = 0.0;
	vec2 radial = (uv - center) * blurAmount;

	for (int i = -4; i <= 4; ++i)
	{
		float position = float(i) / 4.0;
		float weight = 1.0 - abs(position) * 0.65;
		color += impactTap(uv + radial * position, channel) * weight;
		total += weight;
	}

	color /= total;

	// The split's strength lives in the blend weight alone. Scaling the offset by
	// the same control as well squared its response, so the first half of the
	// slider did almost nothing and the last quarter did everything.
	vec2 separation = (uv - center) * chromaticAmount;
	color.r = mix(color.r, impactTap(uv + separation, channel).r, uChromatic);
	color.b = mix(color.b, impactTap(uv - separation, channel).b, uChromatic);

	return color;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;

	if (iProgress <= 0.0)
	{
		fragColor = texture(iChannel0, uv);
		return;
	}

	if (iProgress >= 1.0)
	{
		fragColor = texture(iChannel1, uv);
		return;
	}

	float progress = iProgress;
	float cut = clamp(uCut, 0.1, 0.9);
	float before = smoothstep(max(0.0, cut - 0.28), cut, progress);
	float after = 1.0 - smoothstep(cut, min(1.0, cut + 0.38), progress);
	float impact = progress < cut ? before : after;

	vec2 center = uCenter / iResolution.xy;
	vec2 transformedUV = impactTransform(uv, center, impact, progress);

	float blurAmount = uBlur * 0.045 * impact;
	float chromaticAmount = 0.018 * impact;

	vec4 color;

	int channel = progress < cut ? 0 : 1;
	color = impactSample(transformedUV, center, blurAmount, chromaticAmount, channel);

	float flashWidth = max(uFlashWidth, 0.001);
	float flash = 1.0 - smoothstep(0.0, flashWidth, abs(progress - cut));
	flash = flash * flash * uFlash * uFlashColor.a;

	color.rgb = mix(color.rgb, uFlashColor.rgb, flash);
	fragColor = color;
}