// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template filter

// #int label="Lines" group={"Grid", "grid"} min=8 max=512 slidermax=128 default=60
uniform float uLines;

// #choice label="Orientation" group="Grid" options="Both,Horizontal,Vertical" default=0
uniform int uOrientation;

// #int label="Thickness" group="Grid" units="px" min=1 max=32 slidermax=8 default=2
uniform float uThickness;

// #percent label="Displacement" group="Grid" min=0 max=200 default=100
uniform float uDisplacement;

// #color label="Line" default="#FFFFFF"
uniform vec4 uLine;

// One control, not two: Footage and Footage Level were multiplied together, so
// every visible result had a whole line of duplicate settings behind it and 0 on
// either one meant the same off. This is the product, and it reads as what it
// is - how much of the footage shows behind the lines, 0 for none.
// #percent label="Footage" group={"Background", "photo"} min=0 max=100 default=0
uniform float uFootage;

const int ORIENTATION_BOTH = 0;
const int ORIENTATION_HORIZONTAL = 1;
const int ORIENTATION_VERTICAL = 2;

float brightnessAt(vec2 position)
{
	vec3 color = texture(iChannel0, clamp(position, 0.0, 1.0)).rgb;
	return length(color) / 1.7320508;
}

float lineMask(float distance)
{
	float antialias = fwidth(distance) + 0.000001;

	return 1.0 - smoothstep(
	           0.0,
	           antialias * float(uThickness),
	           abs(distance)
	       );
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;
	vec3 source = texture(iChannel0, uv).rgb;

	float lineCount = max(float(uLines), 1.0);
	float aspect = iResolution.x / iResolution.y;
	vec2 cells = vec2(lineCount * aspect, lineCount);

	vec2 gridPosition = uv * cells;
	vec2 cell = floor(gridPosition);
	vec2 localPosition = fract(gridPosition) - 0.5;
	vec2 cellCenter = (cell + 0.5) / cells;

	float horizontalBrightness =
	    brightnessAt(vec2(uv.x, cellCenter.y)) -
	    0.5;

	float verticalBrightness =
	    brightnessAt(vec2(cellCenter.x, uv.y)) -
	    0.5;

	float horizontalLine = lineMask(
	                           localPosition.y -
	                           horizontalBrightness *
	                           uDisplacement
	                       );

	float verticalLine = lineMask(
	                         localPosition.x -
	                         verticalBrightness *
	                         uDisplacement
	                     );

	float line;

	if (uOrientation == ORIENTATION_HORIZONTAL)
		line = horizontalLine;
	else if (uOrientation == ORIENTATION_VERTICAL)
		line = verticalLine;
	else
		line = max(horizontalLine, verticalLine);

	line *= uLine.a;

	vec3 background = source * uFootage;

	vec3 color = mix(background, uLine.rgb, line);

	fragColor = vec4(color, 1.0);
}
