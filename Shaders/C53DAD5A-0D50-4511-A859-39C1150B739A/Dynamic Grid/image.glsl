// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template generator

// #speed group={"Motion", "wind"}
// #seed group="Motion"

// #choice label="Patterns" group={"Pattern", "square.grid.3x3"} options="Grid,Lines,Dashed Grid,Dotted Grid,Dots,Rings,Squares,Crosses,Crosshairs,Checkerboard,Diagonals" dropdown multiple default="Dotted Grid"
uniform int uPatterns;

// #int label="Cell Size" group="Pattern" min=8 slidermax=240 default=64 units="px"
uniform float uCellSize;

// #percent label="Element Size" group="Pattern" min=5 max=100 default=50
uniform float uElementSize;

// #float label="Stroke" group="Pattern" min=0.25 slidermax=8 default=1 units="px"
uniform float uStroke;

// #percent label="Line Strength" group="Pattern" min=0 max=100 default=30
uniform float uLineStrength;

// #percent label="Movement" group="Motion" min=0 max=100 default=35
uniform float uMovement;

// #percent label="Drift" group="Motion" min=0 max=100 default=20
uniform float uDrift;

// #angle label="Rotation" group={"Transform", "rotate.right"} default=0
uniform float uRotation;

// #point label="Center" group="Transform" osc=position default="0.5,0.5"
uniform vec2 uCenter;

// #percent label="Scale" group="Transform" min=25 max=400 default=100 osc=ring link=uCenter
uniform float uScale;

// #color label="Pattern Colours" optionsby=uPatterns default="#34312C,#81796D,#53636A,#A85A42,#C56B4B,#4E7F86,#B68A3C,#765885,#3D7188,#D5C9B4,#696157"
uniform vec4 uPatternColours[11];

// #color label="Background" default="#F3ECDD"
uniform vec4 uBackground;

// #percent label="Paper Texture" group={"Paper", "doc.text"} min=0 max=100 default=45
uniform float uPaper;

// #percent label="Fibres" group="Paper" min=0 max=100 default=30
uniform float uFibres;

// #percent label="Flecks" group="Paper" min=0 max=100 default=18
uniform float uFlecks;

// #percent label="Grain" group="Paper" min=0 max=100 default=18
uniform float uGrain;

float patternHash(vec2 value)
{
	value = fract(value * vec2(0.3183099, 0.3678794)) + 0.1;
	value += dot(value, value + 19.19);
	return fract(value.x * value.y);
}

float valueNoise(vec2 position)
{
	vec2 cell = floor(position);
	vec2 local = fract(position);
	local = local * local * (3.0 - 2.0 * local);

	float a = patternHash(cell);
	float b = patternHash(cell + vec2(1.0, 0.0));
	float c = patternHash(cell + vec2(0.0, 1.0));
	float d = patternHash(cell + vec2(1.0, 1.0));

	return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}

bool patternEnabled(int bit)
{
	return (uPatterns & bit) != 0;
}

vec2 repeatCell(vec2 position, float spacing)
{
	return mod(position + spacing * 0.5, spacing) - spacing * 0.5;
}

float axisFootprint(float coordinate)
{
	return max(length(vec2(dFdx(coordinate), dFdy(coordinate))), 1e-6);
}

float axisStroke(float distance, float coordinate, float width)
{
	float footprint = axisFootprint(coordinate);
	float halfWidth = 0.5 * width * footprint;
	float antialiasing = 0.75 * footprint;

	return 1.0 - smoothstep(
	           halfWidth - antialiasing,
	           halfWidth + antialiasing,
	           distance
	       );
}

float distanceStroke(float distance, float width)
{
	float footprint = max(fwidth(distance), 1e-6);
	float halfWidth = 0.5 * width * footprint;

	return 1.0 - smoothstep(
	           halfWidth - footprint,
	           halfWidth + footprint,
	           distance
	       );
}

float filledShape(float distance)
{
	float antialiasing = max(fwidth(distance), 1e-6);
	return 1.0 - smoothstep(-antialiasing, antialiasing, distance);
}

float solidGrid(vec2 position, float spacing)
{
	vec2 distance = abs(repeatCell(position, spacing));

	float vertical = axisStroke(distance.x, position.x, uStroke);
	float horizontal = axisStroke(distance.y, position.y, uStroke);

	return max(vertical, horizontal);
}

float horizontalLines(vec2 position, float spacing)
{
	float distance = abs(repeatCell(position, spacing).y);
	return axisStroke(distance, position.y, uStroke) * uLineStrength;
}

float dashedGrid(vec2 position, float spacing)
{
	vec2 distance = abs(repeatCell(position, spacing));
	vec2 dashDistance = abs(repeatCell(position, spacing * 0.34));

	float vertical = axisStroke(distance.x, position.x, uStroke);
	float horizontal = axisStroke(distance.y, position.y, uStroke);

	float verticalDash = 1.0 - smoothstep(
	                         spacing * 0.09,
	                         spacing * 0.09 + axisFootprint(position.y),
	                         dashDistance.y
	                     );

	float horizontalDash = 1.0 - smoothstep(
	                           spacing * 0.09,
	                           spacing * 0.09 + axisFootprint(position.x),
	                           dashDistance.x
	                       );

	return max(vertical * verticalDash, horizontal * horizontalDash);
}

float dottedGrid(vec2 position, float spacing)
{
	vec2 local = repeatCell(position, spacing);
	float radius = spacing * 0.055 * uElementSize;
	return filledShape(length(local) - radius);
}

float dotsPattern(vec2 position, float spacing)
{
	vec2 local = repeatCell(position, spacing);
	float radius = spacing * 0.10 * uElementSize;
	return filledShape(length(local) - radius);
}

float ringsPattern(vec2 position, float spacing)
{
	vec2 local = repeatCell(position, spacing);
	float radius = spacing * 0.22 * uElementSize;
	return distanceStroke(abs(length(local) - radius), uStroke);
}

float squaresPattern(vec2 position, float spacing)
{
	vec2 local = abs(repeatCell(position, spacing));
	vec2 halfSize = vec2(spacing * 0.20 * uElementSize);
	vec2 delta = local - halfSize;

	float distance =
	    length(max(delta, 0.0)) +
	    min(max(delta.x, delta.y), 0.0);

	return distanceStroke(abs(distance), uStroke);
}

float crossesPattern(vec2 position, float spacing)
{
	vec2 local = abs(repeatCell(position, spacing));
	float extent = spacing * 0.20 * uElementSize;

	float horizontal =
	    axisStroke(local.y, position.y, uStroke) *
	    (1.0 - smoothstep(
	         extent,
	         extent + axisFootprint(position.x),
	         local.x
	     ));

	float vertical =
	    axisStroke(local.x, position.x, uStroke) *
	    (1.0 - smoothstep(
	         extent,
	         extent + axisFootprint(position.y),
	         local.y
	     ));

	return max(horizontal, vertical);
}

float crosshairsPattern(vec2 position, float spacing)
{
	vec2 local = abs(repeatCell(position, spacing));
	float inner = spacing * 0.055 * uElementSize;
	float outer = spacing * 0.22 * uElementSize;

	float horizontal =
	    axisStroke(local.y, position.y, uStroke) *
	    smoothstep(
	        inner - axisFootprint(position.x),
	        inner + axisFootprint(position.x),
	        local.x
	    ) *
	    (1.0 - smoothstep(
	         outer,
	         outer + axisFootprint(position.x),
	         local.x
	     ));

	float vertical =
	    axisStroke(local.x, position.x, uStroke) *
	    smoothstep(
	        inner - axisFootprint(position.y),
	        inner + axisFootprint(position.y),
	        local.y
	    ) *
	    (1.0 - smoothstep(
	         outer,
	         outer + axisFootprint(position.y),
	         local.y
	     ));

	return max(horizontal, vertical);
}

float checkerboardPattern(vec2 position, float spacing)
{
	vec2 cell = floor(position / spacing);
	return mod(cell.x + cell.y, 2.0);
}

float diagonalsPattern(vec2 position, float spacing)
{
	float diagonalSpacing = spacing * 0.5;
	float diagonal = position.x + position.y;

	float distance = abs(
	                     mod(diagonal + diagonalSpacing * 0.5, diagonalSpacing) -
	                     diagonalSpacing * 0.5
	                 );

	return axisStroke(distance, diagonal, uStroke);
}

void compositePattern(inout vec4 canvas, float mask, vec4 ink)
{
	float sourceAlpha = clamp(mask * ink.a, 0.0, 1.0);
	float opacity = sourceAlpha + canvas.a * (1.0 - sourceAlpha);

	vec3 premultiplied =
	    ink.rgb * sourceAlpha +
	    canvas.rgb * canvas.a * (1.0 - sourceAlpha);

	canvas.rgb = opacity > 1e-5 ? premultiplied / opacity : vec3(0.0);
	canvas.a = opacity;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 resolution = iResolution.xy;
	float aspect = resolution.x / resolution.y;

	vec2 uv = fragCoord / resolution;
	vec2 center = uCenter / resolution;
	vec2 position = (uv - center) * vec2(aspect, 1.0);

	position /= max(uScale, 0.001);

	float cosine = cos(uRotation);
	float sine = sin(uRotation);
	position = mat2(cosine, -sine, sine, cosine) * position;

	float time = iTime;
	// Constant by design: it only decorrelates the two noise axes below. The
	// movement comes from time, not from this.
	float seed = patternHash(vec2(13.7, 41.3));

	vec2 kineticOffset = vec2(
	                         valueNoise(vec2(time * 0.21 + seed * 17.0, 3.1)),
	                         valueNoise(vec2(7.4, time * 0.17 + seed * 29.0))
	                     ) - 0.5;

	kineticOffset *= uMovement * 0.16;
	kineticOffset += vec2(time * 0.035, -time * 0.021) * uDrift;
	position += kineticOffset;

	// Straight-edged patterns are aligned to the physical pixel lattice.
	float patternPixelsPerUnit = resolution.y * max(uScale, 0.001);
	vec2 pixelPosition =
	    (floor(position * patternPixelsPerUnit) + 0.5) /
	    patternPixelsPerUnit;

	float spacing = max(uCellSize, 1.0) / resolution.y;

	float coarsePaper = valueNoise(fragCoord * 0.012 + 31.7) - 0.5;
	float finePaper = patternHash(fragCoord + 71.0) - 0.5;

	float fibreNoise =
	    sin(
	        fragCoord.y * 0.72 +
	        valueNoise(vec2(fragCoord.x * 0.01, 4.0)) * 4.0
	    ) * 0.5;

	float fleckNoise = step(
	                       0.992,
	                       patternHash(floor(fragCoord * 0.55) + 93.1)
	                   );

	vec3 paper = uBackground.rgb;
	paper *= 1.0 + coarsePaper * 0.08 * uPaper;
	paper += finePaper * 0.035 * uGrain;
	paper += fibreNoise * 0.018 * uFibres;
	paper -= fleckNoise * 0.12 * uFlecks;

	vec4 canvas = vec4(max(paper, vec3(0.0)), uBackground.a);

	if (patternEnabled(1))
		compositePattern(
		    canvas,
		    solidGrid(pixelPosition, spacing),
		    uPatternColours[0]
		);

	if (patternEnabled(2))
		compositePattern(
		    canvas,
		    horizontalLines(pixelPosition, spacing),
		    uPatternColours[1]
		);

	if (patternEnabled(4))
		compositePattern(
		    canvas,
		    dashedGrid(pixelPosition, spacing),
		    uPatternColours[2]
		);

	if (patternEnabled(8))
		compositePattern(
		    canvas,
		    dottedGrid(position, spacing),
		    uPatternColours[3]
		);

	if (patternEnabled(16))
		compositePattern(
		    canvas,
		    dotsPattern(position, spacing),
		    uPatternColours[4]
		);

	if (patternEnabled(32))
		compositePattern(
		    canvas,
		    ringsPattern(position, spacing),
		    uPatternColours[5]
		);

	if (patternEnabled(64))
		compositePattern(
		    canvas,
		    squaresPattern(pixelPosition, spacing),
		    uPatternColours[6]
		);

	if (patternEnabled(128))
		compositePattern(
		    canvas,
		    crossesPattern(position, spacing),
		    uPatternColours[7]
		);

	if (patternEnabled(256))
		compositePattern(
		    canvas,
		    crosshairsPattern(position, spacing),
		    uPatternColours[8]
		);

	if (patternEnabled(512))
		compositePattern(
		    canvas,
		    checkerboardPattern(position, spacing) * 0.12,
		    uPatternColours[9]
		);

	if (patternEnabled(1024))
		compositePattern(
		    canvas,
		    diagonalsPattern(pixelPosition, spacing),
		    uPatternColours[10]
		);

	fragColor = canvas;
}