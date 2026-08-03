// SPDX-FileCopyrightText: nwoeanhinnogaehr
// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template transition
//
// Derived from https://gist.github.com/nwoeanhinnogaehr/b185145363d65751009b
// HSV conversion from http://lolengine.net/blog/2013/07/27/rgb-to-hsv-in-glsl

// No `#color-surface ring=hue`, even though this is the one file in the family
// whose whole subject is hue. A puck on a hue ring reports an ABSOLUTE hue -
// the bearing IS the colour under it - and nothing here holds one. There is no
// target hue: every pixel travels from its own hue to its own, so the shader
// never names a colour a handle could point at. Hue Turns is a count of extra
// revolutions on top of that, and a bearing is single-valued round the circle,
// so -3, 0 and +3 turns would all draw the puck in the same place.

// #choice label="Hue Path" group={"Colour", "paintpalette"} options="Linear,Shortest,Forward,Reverse" default=0
uniform int uHuePath;

// #float label="Hue Turns" group="Colour" min=-3 max=3 default=0
uniform float uHueTurns;

// #percent label="Saturation Boost" group="Colour" min=-100 max=200 default=0
uniform float uSaturationBoost;

// #percent label="Brightness Boost" group="Colour" min=-100 max=100 default=0
uniform float uBrightnessBoost;

// #choice label="Blend Curve" group={"Timing", "clock"} options="Linear,Smooth,Ease In,Ease Out" default=0
uniform int uBlendCurve;

vec3 hsvToRGB(vec3 color)
{
	const vec4 coefficients = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 channels = abs(fract(color.xxx + coefficients.xyz) * 6.0 - coefficients.www);
	return color.z * mix(coefficients.xxx, clamp(channels - coefficients.xxx, 0.0, 1.0), color.y);
}

vec3 rgbToHSV(vec3 color)
{
	const vec4 coefficients = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 first = mix(vec4(color.bg, coefficients.wz), vec4(color.gb, coefficients.xy), step(color.b, color.g));
	vec4 second = mix(vec4(first.xyw, color.r), vec4(color.r, first.yzx), step(first.x, color.r));
	float difference = second.x - min(second.w, second.y);
	return vec3(abs(second.z + (second.w - second.y) / (6.0 * difference + 0.001)), difference / (second.x + 0.001), second.x);
}

float shapeProgress(float progress)
{
	if (uBlendCurve == 1)
		return progress * progress * (3.0 - 2.0 * progress);

	if (uBlendCurve == 2)
		return progress * progress;

	if (uBlendCurve == 3)
		return 1.0 - (1.0 - progress) * (1.0 - progress);

	return progress;
}

float hueDifference(float fromHue, float toHue)
{
	float difference = toHue - fromHue;

	if (uHuePath == 1)
		return fract(difference + 0.5) - 0.5;

	if (uHuePath == 2)
		return fract(difference);

	if (uHuePath == 3)
		return -fract(-difference);

	return difference;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;
	float linearProgress = clamp(iProgress, 0.0, 1.0);

	vec4 fromColor = texture(iChannel0, uv);
	vec4 toColor = texture(iChannel1, uv);

	if (linearProgress <= 0.0)
	{
		fragColor = fromColor;
		return;
	}

	if (linearProgress >= 1.0)
	{
		fragColor = toColor;
		return;
	}

	float progress = shapeProgress(linearProgress);
	vec3 fromHSV = rgbToHSV(fromColor.rgb);
	vec3 toHSV = rgbToHSV(toColor.rgb);

	if (fromColor.a < 0.0001)
		fromHSV = toHSV;

	if (toColor.a < 0.0001)
		toHSV = fromHSV;

	if (fromHSV.y < 0.001)
		fromHSV.x = toHSV.x;

	if (toHSV.y < 0.001)
		toHSV.x = fromHSV.x;

	float hueDelta = hueDifference(fromHSV.x, toHSV.x) + uHueTurns;
	float hue = fract(fromHSV.x + hueDelta * progress);
	float saturation = mix(fromHSV.y, toHSV.y, progress);
	float brightness = mix(fromHSV.z, toHSV.z, progress);

	float midpoint = sin(progress * 3.14159265);
	saturation = clamp(saturation + uSaturationBoost * midpoint, 0.0, 1.0);
	brightness = clamp(brightness + uBrightnessBoost * midpoint, 0.0, 1.0);

	vec3 color = hsvToRGB(vec3(hue, saturation, brightness));
	float alpha = mix(fromColor.a, toColor.a, progress);

	fragColor = vec4(color, alpha);
}