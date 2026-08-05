// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template layout

// #alpha
// #motionblur on

// #choice label="Grid" group={"Layout","square.grid.3x3.fill"} options="2 × 2,3 × 2,3 × 3" default=0
uniform int uGrid;

// #int label="Cell" group="Layout" min=1 max=9 default=1 maxby=uGrid maxvalues={4,6,9}
uniform float uCell;

// #point label="Position" group={"Framing","crop"} default="0.5,0.5"
uniform vec2 uPosition;

// #multi label="Crop Size" group="Framing" fields={W,H} percent min={0,0} max={400,400} default="100,100" lockaspect
uniform vec2 uCropSize;

// #multi label="Crop Center" group="Framing" fields={X,Y} percent default="50,50"
uniform vec2 uCropCenter;

// #int label="Gap" group={"Appearance","square.dashed"} units="px" min=0 slidermax=80 default=0
uniform float uGap;

// #int label="Padding" group="Appearance" units="px" min=0 slidermax=100 default=0
uniform float uPadding;

// #percent label="Corner Radius" group="Appearance" min=0 max=100 default=0
uniform float uRadius;

// #int label="Feather" group="Appearance" units="px" min=0 slidermax=30 default=0
uniform float uFeather;

// #color label="Background" default="#FFFFFF"
uniform vec4 uBackground;

// @osc Position
//   primitive = position
//   binds = uPosition
//   grid = uGrid == 0 ? vec2(2.0, 2.0) : (uGrid == 1 ? vec2(3.0, 2.0) : vec2(3.0, 3.0))
//   index = clamp(uCell - 1.0, 0.0, grid.x * grid.y - 1.0)
//   column = index % grid.x
//   row = (index - column) / grid.x
//   pitch = (vec2(1.0) - vec2(uPadding) * 2.0 / size) / grid
//   cellMin = vec2(uPadding) / size + vec2(column, grid.y - row - 1.0) * pitch + vec2(uGap) * 0.5 / size
//   cellSize = pitch - vec2(uGap) / size
//   toPos = cellMin + uPosition * cellSize
//   fromPos = (pos - cellMin) / cellSize

// @osc Crop Size
//   primitive = box
//   binds = uCropSize
//   body = none
//   linked = true
//   grid = uGrid == 0 ? vec2(2.0, 2.0) : (uGrid == 1 ? vec2(3.0, 2.0) : vec2(3.0, 3.0))
//   index = clamp(uCell - 1.0, 0.0, grid.x * grid.y - 1.0)
//   column = index % grid.x
//   row = (index - column) / grid.x
//   pitch = (vec2(1.0) - vec2(uPadding) * 2.0 / size) / grid
//   cellMin = vec2(uPadding) / size + vec2(column, grid.y - row - 1.0) * pitch + vec2(uGap) * 0.5 / size
//   cellSize = pitch - vec2(uGap) / size
//   boxCenter = cellMin + uPosition * cellSize
//   center = boxCenter
//   extent = ringExtent(uCropSize / 4.0)
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

	float inside = min(max(distance.x, distance.y), 0.0);
	return outside + inside;
}

vec2 gridSize()
{
	if (uGrid == 0)
		return vec2(2.0, 2.0);

	if (uGrid == 1)
		return vec2(3.0, 2.0);

	return vec2(3.0, 3.0);
}

void cellBounds(
    int index,
    vec2 grid,
    vec2 resolution,
    out vec2 lower,
    out vec2 upper
)
{
	float column = mod(float(index), grid.x);
	float row = floor(float(index) / grid.x);

	vec2 padding = vec2(uPadding) / resolution;
	vec2 gap = vec2(uGap) / resolution;
	vec2 available = max(vec2(0.001), vec2(1.0) - padding * 2.0);
	vec2 pitch = available / grid;
	vec2 gridPosition = vec2(column, grid.y - row - 1.0);

	lower = padding + gridPosition * pitch + gap * 0.5;
	upper = padding + (gridPosition + 1.0) * pitch - gap * 0.5;

	vec2 center = (lower + upper) * 0.5;
	vec2 minimumSize = 1.0 / resolution;

	lower = min(lower, center - minimumSize * 0.5);
	upper = max(upper, center + minimumSize * 0.5);
}

float cellMask(
    vec2 fragCoord,
    vec2 lower,
    vec2 upper,
    vec2 resolution
)
{
	vec2 center = (lower + upper) * resolution * 0.5;
	vec2 halfSize = max((upper - lower) * resolution * 0.5, vec2(0.5));
	float radius = uRadius * min(halfSize.x, halfSize.y);

	float distance = roundedSDF(
	                     fragCoord - center,
	                     halfSize,
	                     radius,
	                     uRadius
	                 );

	float antialias = max(fwidth(distance), 0.5);
	float feather = max(uFeather, 0.0);

	return 1.0 - smoothstep(
	           -feather,
	           feather + antialias * 2.0,
	           distance
	       );
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 resolution = iResolution.xy;
	vec2 uv = fragCoord / resolution;
	vec2 grid = gridSize();

	int cellCount = int(grid.x * grid.y);
	int selectedCell = clamp(
	                       int(floor(uCell + 0.5)) - 1,
	                       0,
	                       cellCount - 1
	                   );

	vec2 selectedLower;
	vec2 selectedUpper;

	cellBounds(
	    selectedCell,
	    grid,
	    resolution,
	    selectedLower,
	    selectedUpper
	);

	float selectedMask = cellMask(
	                         fragCoord,
	                         selectedLower,
	                         selectedUpper,
	                         resolution
	                     );

	float allCellsMask = 0.0;

	for (int i = 0; i < 9; ++i)
	{
		if (i >= cellCount)
			break;

		vec2 lower;
		vec2 upper;
		cellBounds(i, grid, resolution, lower, upper);

		allCellsMask = max(
		                   allCellsMask,
		                   cellMask(fragCoord, lower, upper, resolution)
		               );
	}

	vec2 cellSize = max(
	                    selectedUpper - selectedLower,
	                    1.0 / resolution
	                );

	vec2 localPosition = (uv - selectedLower) / cellSize;
	vec2 position = uPosition / resolution;

	vec2 sourceExtent = vec2(
	                        min(1.0, cellSize.x / cellSize.y),
	                        min(1.0, cellSize.y / cellSize.x)
	                    );

	vec2 cropScale = max(uCropSize, vec2(0.001));

	vec2 samplePosition = uCropCenter +
	                      (localPosition - position) *
	                      sourceExtent /
	                      cropScale;

	vec2 insideSource =
	    step(vec2(0.0), samplePosition) *
	    step(samplePosition, vec2(1.0));

	float sourceMask = insideSource.x * insideSource.y;

	vec4 source = texture(
	                  iChannel0,
	                  clamp(samplePosition, 0.0, 1.0)
	              );

	float contentAlpha = source.a * selectedMask * sourceMask;
	float gutter = 1.0 - allCellsMask;
	float backgroundAlpha = uBackground.a * gutter;

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