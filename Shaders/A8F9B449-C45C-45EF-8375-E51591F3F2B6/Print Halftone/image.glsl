// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template filter

// #alpha
// #grain label="Grain" group="Finish" default=4 size=2

// #choice label="Mode" group="Pattern" options="Monochrome,CMYK" default=1
uniform int uMode;

// #int label="Cell Size" group="Pattern" units="px" min=3 slidermax=30 default=8
uniform float uCellSize;

// #percent label="Dot Size" group="Pattern" min=20 max=200 default=100
uniform float uDotSize;

// #angle label="Angle" group="Pattern" default=0 osc={z} center=0.5,0.5
uniform float uAngle;

// #int label="Misregistration" group="Pattern" units="px" min=0 slidermax=12 default=1 visibleby=uMode visiblevalues={1}
uniform float uMisregistration;

// #percent label="Contrast" group="Appearance" min=0 max=200 default=110
uniform float uContrast;

// #percent label="Dot Gain" group="Appearance" min=-50 max=50 default=0
uniform float uDotGain;

// #percent label="Ink Amount" group="Appearance" min=0 max=150 default=100
uniform float uInkAmount;

// #percent label="Mix" group="Finish" min=0 max=100 default=100
uniform float uMix;

// No `pick=color` on either swatch. The eyedropper lives on the Color panel and
// the panel only exists for a shader declaring `#color-surface`, so a `pick=`
// here would be inert - and this shader has no honest ring to declare, its axes
// being screen geometry and ink density rather than light or hue. Even with a
// panel, the eyedropper writes every subscriber in one click, so Paper and Ink
// would both take the sampled colour and the print would come out blank.

// #color label="Paper" default="#F2E8D5"
uniform vec4 uPaper;

// #color label="Ink" default="#17131C"
uniform vec4 uInk;

mat2 halftoneRotation(float angle)
{
	float c = cos(angle);
	float s = sin(angle);
	return mat2(c, -s, s, c);
}

vec3 halftoneSource(vec2 samplePosition)
{
	vec3 color = texture(iChannel0, clamp(samplePosition / iResolution.xy, 0.0, 1.0)).rgb;
	return clamp((color - 0.5) * uContrast + 0.5, 0.0, 1.0);
}

vec4 halftoneCMYK(vec3 color)
{
	float black = 1.0 - max(color.r, max(color.g, color.b));
	float denominator = max(1.0 - black, 0.0001);
	float cyan = (1.0 - color.r - black) / denominator;
	float magenta = (1.0 - color.g - black) / denominator;
	float yellow = (1.0 - color.b - black) / denominator;
	return clamp(vec4(cyan, magenta, yellow, black), 0.0, 1.0);
}

float halftoneInk(vec3 color, int channel)
{
	if (channel < 0)
	{
		float luminance = dot(color, vec3(0.2126, 0.7152, 0.0722));
		return 1.0 - luminance;
	}

	vec4 cmyk = halftoneCMYK(color);
	if (channel == 0) return cmyk.x;
	if (channel == 1) return cmyk.y;
	if (channel == 2) return cmyk.z;
	return cmyk.w;
}

float halftoneDot(vec2 fragCoord, float angle, vec2 offset, int channel)
{
	float cellSize = max(uCellSize * iResolution.y / 1080.0, 1.0);
	mat2 rotation = halftoneRotation(angle);
	vec2 centered = fragCoord - 0.5 * iResolution.xy - offset;
	vec2 gridPosition = rotation * centered;
	vec2 cellCenter = (floor(gridPosition / cellSize) + 0.5) * cellSize;
	vec2 local = gridPosition - cellCenter;

	vec2 samplePosition = transpose(rotation) * cellCenter;
	samplePosition += 0.5 * iResolution.xy + offset;

	float amount = halftoneInk(halftoneSource(samplePosition), channel);
	amount = clamp(amount + uDotGain, 0.0, 1.0);

	float radius = 0.5 * cellSize * sqrt(amount) * uDotSize;
	float distanceToCenter = length(local);
	float aa = max(fwidth(distanceToCenter), 0.75);
	float dot = 1.0 - smoothstep(radius - aa, radius + aa, distanceToCenter);

	return dot * step(0.0001, amount);
}

void mirageFilterImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;
	vec4 source = texture(iChannel0, uv);
	vec3 printed;

	if (uMode == 0)
	{
		float dot = halftoneDot(fragCoord, uAngle, vec2(0.0), -1);
		float ink = clamp(dot * uInkAmount * uInk.a, 0.0, 1.0);
		printed = mix(uPaper.rgb, uInk.rgb, ink);
	}
	else
	{
		float shift = uMisregistration * iResolution.y / 1080.0;
		vec2 cyanOffset = vec2(-1.0, 0.35) * shift;
		vec2 magentaOffset = vec2(0.75, -0.55) * shift;
		vec2 yellowOffset = vec2(0.25, 0.8) * shift;

		float cyan = halftoneDot(fragCoord, uAngle + radians(15.0), cyanOffset, 0);
		float magenta = halftoneDot(fragCoord, uAngle + radians(75.0), magentaOffset, 1);
		float yellow = halftoneDot(fragCoord, uAngle, yellowOffset, 2);
		float black = halftoneDot(fragCoord, uAngle + radians(45.0), vec2(0.0), 3);

		cyan = clamp(cyan * uInkAmount, 0.0, 1.0);
		magenta = clamp(magenta * uInkAmount, 0.0, 1.0);
		yellow = clamp(yellow * uInkAmount, 0.0, 1.0);
		black = clamp(black * uInkAmount * uInk.a, 0.0, 1.0);

		printed = uPaper.rgb;
		printed *= mix(vec3(1.0), vec3(0.08, 0.68, 0.82), cyan);
		printed *= mix(vec3(1.0), vec3(0.92, 0.10, 0.48), magenta);
		printed *= mix(vec3(1.0), vec3(1.00, 0.82, 0.08), yellow);
		printed *= mix(vec3(1.0), uInk.rgb, black);
	}

	fragColor = vec4(mix(source.rgb, printed, uMix), source.a);
}

// FxPlug supplies iChannel0 premultiplied. The filter body keeps doing its
// existing maths in that representation; #alpha then expects straight colour,
// so unwrap once here before Mirage premultiplies the final output.
void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	mirageFilterImage(fragColor, fragCoord);
	if (fragColor.a > 0.0001)
		fragColor.rgb /= fragColor.a;
	else
		fragColor.rgb = vec3(0.0);
}
