// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template layout

// #alpha
// #motionblur on

// #choice label="Layout" group={"Layout","rectangle.split.2x1.fill"} options="Hero Left,Hero Right,Hero Top,Hero Bottom" default=0
uniform int uLayout;

// #int label="Area" group="Layout" min=1 max=3 default=1
uniform float uArea;

// #point label="Position" group={"Framing","crop"} default="0.5,0.5"
uniform vec2 uPosition;

// #multi label="Size" group="Framing" fields={W,H} percent min={0,0} max={400,400} default="100,100" lockaspect
uniform vec2 uSize;

// #multi label="Crop Center" group="Framing" fields={X,Y} percent default="50,50"
uniform vec2 uCropCenter;

// #int label="Gap" group={"Appearance","square.dashed"} units="px" min=0 slidermax=80 default=12
uniform float uGap;

// #int label="Padding" group="Appearance" units="px" min=0 slidermax=100 default=10
uniform float uPadding;

// #percent label="Corner Radius" group="Appearance" min=0 max=100 default=4
uniform float uRadius;

// #int label="Feather" group="Appearance" units="px" min=0 slidermax=30 default=0
uniform float uFeather;

// #color label="Background" default="#FFFFFF"
uniform vec4 uBackground;

// @osc Position
//   primitive = position
//   binds = uPosition
//   index = clamp(uArea - 1.0, 0.0, 2.0)
//   padding = vec2(uPadding) / size
//   gap = vec2(uGap) / size
//   usable = vec2(1.0) - padding * 2.0
//   vertical = uLayout < 2
//   reverse = uLayout == 1 || uLayout == 3
//   major = vertical ? usable.x * 0.6666667 : usable.y * 0.6666667
//   minor = vertical ? usable.y * 0.5 : usable.x * 0.5
//   areaMin = vertical ? (index < 0.5 ? vec2(reverse ? padding.x + usable.x - major + gap.x * 0.5 : padding.x, padding.y) : vec2(reverse ? padding.x : padding.x + major + gap.x * 0.5, padding.y + (index < 1.5 ? minor + gap.y * 0.5 : 0.0))) : (index < 0.5 ? vec2(padding.x, reverse ? padding.y : padding.y + usable.y - major + gap.y * 0.5) : vec2(padding.x + (index < 1.5 ? 0.0 : minor + gap.x * 0.5), reverse ? padding.y + major + gap.y * 0.5 : padding.y))
//   areaMax = vertical ? (index < 0.5 ? vec2(reverse ? 1.0 - padding.x : padding.x + major - gap.x * 0.5, 1.0 - padding.y) : vec2(reverse ? padding.x + usable.x - major - gap.x * 0.5 : 1.0 - padding.x, padding.y + (index < 1.5 ? usable.y : minor - gap.y * 0.5))) : (index < 0.5 ? vec2(1.0 - padding.x, reverse ? padding.y + major - gap.y * 0.5 : 1.0 - padding.y) : vec2(padding.x + (index < 1.5 ? minor - gap.x * 0.5 : usable.x), reverse ? 1.0 - padding.y : padding.y + usable.y - major - gap.y * 0.5))
//   areaSize = areaMax - areaMin
//   toPos = areaMin + uPosition * areaSize
//   fromPos = (pos - areaMin) / areaSize

// @osc Size
//   primitive = box
//   binds = uSize
//   body = none
//   linked = true
//   index = clamp(uArea - 1.0, 0.0, 2.0)
//   padding = vec2(uPadding) / size
//   usable = vec2(1.0) - padding * 2.0
//   vertical = uLayout < 2
//   reverse = uLayout == 1 || uLayout == 3
//   majorCenter = vertical ? vec2(reverse ? 1.0 - padding.x - usable.x / 3.0 : padding.x + usable.x / 3.0, 0.5) : vec2(0.5, reverse ? padding.y + usable.y / 3.0 : 1.0 - padding.y - usable.y / 3.0)
//   minorCenter = vertical ? vec2(reverse ? padding.x + usable.x / 6.0 : 1.0 - padding.x - usable.x / 6.0, index < 1.5 ? padding.y + usable.y * 0.75 : padding.y + usable.y * 0.25) : vec2(index < 1.5 ? padding.x + usable.x * 0.25 : padding.x + usable.x * 0.75, reverse ? 1.0 - padding.y - usable.y / 6.0 : padding.y + usable.y / 6.0)
//   baseCenter = index < 0.5 ? majorCenter : minorCenter
//   boxCenter = baseCenter + (uPosition - vec2(0.5)) * (vertical ? vec2(index < 0.5 ? usable.x * 0.6666667 : usable.x * 0.3333333, index < 0.5 ? usable.y : usable.y * 0.5) : vec2(index < 0.5 ? usable.x : usable.x * 0.5, index < 0.5 ? usable.y * 0.6666667 : usable.y * 0.3333333))
//   center = boxCenter
//   extent = ringExtent(uSize / 4.0)
//   boxExtent = extent * vec2(min(1.0, 1.0 / aspect), min(1.0, aspect))
//   dragExtent = max(boxCenter - rect.min, rect.max - boxCenter) * vec2(max(1.0, aspect), max(1.0, 1.0 / aspect))
//   toRect = rect(boxCenter - boxExtent, boxCenter + boxExtent)
//   fromRect = ringNorm(dragExtent) * 4.0

float roundedSDF(vec2 point, vec2 halfSize, float radius, float radiusAmount)
{
	float power = mix(5.0, 2.0, radiusAmount);
	vec2 distance = abs(point) - halfSize + radius;
	vec2 outsideDistance = max(distance, 0.0);

	float outside = pow(
	                    pow(outsideDistance.x, power) + pow(outsideDistance.y, power),
	                    1.0 / power
	                ) - radius;

	return outside + min(max(distance.x, distance.y), 0.0);
}

void areaBounds(
    int index,
    vec2 resolution,
    out vec2 lower,
    out vec2 upper
)
{
	vec2 padding = vec2(uPadding);
	vec2 gap = vec2(uGap);
	vec2 frameLower = padding;
	vec2 frameUpper = resolution - padding;
	vec2 available = max(frameUpper - frameLower, vec2(1.0));

	bool vertical = uLayout < 2;
	bool reverse = uLayout == 1 || uLayout == 3;

	if (vertical)
	{
		float division = reverse
		                 ? frameLower.x + available.x / 3.0
		                 : frameLower.x + available.x * 2.0 / 3.0;

		if (index == 0)
		{
			lower = reverse
			        ? vec2(division + gap.x * 0.5, frameLower.y)
			        : frameLower;

			upper = reverse
			        ? frameUpper
			        : vec2(division - gap.x * 0.5, frameUpper.y);

			return;
		}

		float middle = frameLower.y + available.y * 0.5;

		lower.x = reverse
		          ? frameLower.x
		          : division + gap.x * 0.5;

		upper.x = reverse
		          ? division - gap.x * 0.5
		          : frameUpper.x;

		if (index == 1)
		{
			lower.y = middle + gap.y * 0.5;
			upper.y = frameUpper.y;
		}
		else
		{
			lower.y = frameLower.y;
			upper.y = middle - gap.y * 0.5;
		}

		return;
	}

	float division = reverse
	                 ? frameLower.y + available.y * 2.0 / 3.0
	                 : frameLower.y + available.y / 3.0;

	if (index == 0)
	{
		lower = reverse
		        ? frameLower
		        : vec2(frameLower.x, division + gap.y * 0.5);

		upper = reverse
		        ? vec2(frameUpper.x, division - gap.y * 0.5)
		        : frameUpper;

		return;
	}

	float middle = frameLower.x + available.x * 0.5;

	lower.y = reverse
	          ? division + gap.y * 0.5
	          : frameLower.y;

	upper.y = reverse
	          ? frameUpper.y
	          : division - gap.y * 0.5;

	if (index == 1)
	{
		lower.x = frameLower.x;
		upper.x = middle - gap.x * 0.5;
	}
	else
	{
		lower.x = middle + gap.x * 0.5;
		upper.x = frameUpper.x;
	}
}

float areaMask(
    vec2 fragCoord,
    vec2 lower,
    vec2 upper
)
{
	vec2 center = (lower + upper) * 0.5;
	vec2 halfSize = max((upper - lower) * 0.5, vec2(0.5));
	float radius = uRadius * min(halfSize.x, halfSize.y);

	float distance = roundedSDF(
	                     fragCoord - center,
	                     halfSize,
	                     radius,
	                     uRadius
	                 );

	float antialias = max(fwidth(distance), 0.5);

	return 1.0 - smoothstep(
	           -max(uFeather, 0.0),
	           max(uFeather, 0.0) + antialias * 2.0,
	           distance
	       );
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 resolution = iResolution.xy;
	vec2 uv = fragCoord / resolution;
	int selectedArea = clamp(int(floor(uArea + 0.5)) - 1, 0, 2);

	vec2 selectedLower;
	vec2 selectedUpper;
	areaBounds(selectedArea, resolution, selectedLower, selectedUpper);

	float selectedMask = areaMask(
	                         fragCoord,
	                         selectedLower,
	                         selectedUpper
	                     );

	float allAreasMask = 0.0;

	for (int i = 0; i < 3; ++i)
	{
		vec2 lower;
		vec2 upper;
		areaBounds(i, resolution, lower, upper);
		allAreasMask = max(allAreasMask, areaMask(fragCoord, lower, upper));
	}

	vec2 areaSize = max(
	                    selectedUpper - selectedLower,
	                    vec2(1.0)
	                );

	vec2 areaLower = selectedLower / resolution;
	vec2 areaExtent = areaSize / resolution;
	vec2 localPosition = (uv - areaLower) / areaExtent;
	vec2 position = uPosition / resolution;

	vec2 sourceExtent = vec2(
	                        min(1.0, areaExtent.x / areaExtent.y),
	                        min(1.0, areaExtent.y / areaExtent.x)
	                    );

	vec2 scale = max(uSize, vec2(0.001));

	vec2 samplePosition = uCropCenter +
	                      (localPosition - position) *
	                      sourceExtent /
	                      scale;

	vec2 insideSource =
	    step(vec2(0.0), samplePosition) *
	    step(samplePosition, vec2(1.0));

	float sourceMask = insideSource.x * insideSource.y;

	vec4 source = texture(
	                  iChannel0,
	                  clamp(samplePosition, 0.0, 1.0)
	              );

	float contentAlpha = source.a * selectedMask * sourceMask;
	float backgroundAlpha = uBackground.a * (1.0 - allAreasMask);

	float outputAlpha =
	    contentAlpha +
	    backgroundAlpha * (1.0 - contentAlpha);

	vec3 premultiplied =
	    source.rgb * contentAlpha +
	    uBackground.rgb * backgroundAlpha * (1.0 - contentAlpha);

	vec3 outputColor = outputAlpha > 0.0001
	                   ? premultiplied / outputAlpha
	                   : vec3(0.0);

	fragColor = vec4(outputColor, outputAlpha);
}