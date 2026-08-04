// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template filter

// #alpha
// #choice label="Shape" group={"Mosaic", "square.grid.3x3.fill"} options="Square,Triangle,Diamond,Hexagon" default=1
uniform int uShape;

// #int label="Tiles" group="Mosaic" min=4 max=800 slidermax=200 default=40
uniform float uTiles;

// #choice label="Edges" group="Mosaic" options="Clamp,Mirror,Repeat" default=0
uniform int uEdges;

// #percent label="Mix" group={"Output", "slider.horizontal.below.rectangle"} min=0 max=100 default=100
uniform float uMix;

const int SHAPE_SQUARE = 0;
const int SHAPE_TRIANGLE = 1;
const int SHAPE_DIAMOND = 2;
const int SHAPE_HEXAGON = 3;

const int EDGES_CLAMP = 0;
const int EDGES_MIRROR = 1;
const int EDGES_REPEAT = 2;

const float SQRT_3 = 1.73205080757;
const float INV_SQRT_2 = 0.70710678118;

vec2 hexCenter(vec2 position)
{
	vec2 spacing = vec2(1.0, SQRT_3);
	vec2 firstOffset = mod(position, spacing) - spacing * 0.5;

	vec2 secondOffset =
	    mod(
	        position - spacing * 0.5,
	        spacing
	    ) -
	    spacing * 0.5;

	return dot(firstOffset, firstOffset) < dot(secondOffset, secondOffset)
	       ? position - firstOffset
	       : position - secondOffset;
}

vec2 mirrorRepeat(vec2 value)
{
	value = mod(abs(value), 2.0);
	return mix(value, 2.0 - value, step(1.0, value));
}

vec2 applyEdges(vec2 position)
{
	if (uEdges == EDGES_MIRROR)
		return mirrorRepeat(position);

	if (uEdges == EDGES_REPEAT)
		return fract(position);

	return clamp(position, 0.0, 1.0);
}

void mirageFilterImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;
	vec4 source = texture(iChannel0, uv);

	float aspect = iResolution.x / iResolution.y;
	float density = max(float(uTiles), 1.0);
	vec2 tileCount = vec2(density, max(1.0, density / aspect));

	vec2 samplePosition;

	if (uShape == SHAPE_SQUARE)
	{
		samplePosition =
		    (
		        floor(uv * tileCount) +
		        0.5
		    ) /
		    tileCount;
	}
	else if (uShape == SHAPE_TRIANGLE)
	{
		vec2 base = floor(uv * tileCount) / tileCount;
		vec2 local = fract(uv * tileCount);

		vec2 offset = vec2(
		                  step(1.0 - local.y, local.x),
		                  step(local.x, local.y)
		              );

		samplePosition =
		    base +
		    offset *
		    0.5 /
		    tileCount +
		    0.25 /
		    tileCount;
	}
	else if (uShape == SHAPE_DIAMOND)
	{
		mat2 rotateForward = mat2(
		                         INV_SQRT_2,
		                         -INV_SQRT_2,
		                         INV_SQRT_2,
		                         INV_SQRT_2
		                     );

		mat2 rotateBack = mat2(
		                      INV_SQRT_2,
		                      INV_SQRT_2,
		                      -INV_SQRT_2,
		                      INV_SQRT_2
		                  );

		vec2 centered =
		    (uv - 0.5) *
		    vec2(aspect, 1.0);

		vec2 cell =
		    floor(
		        rotateForward *
		        centered *
		        density
		    ) +
		    0.5;

		vec2 center =
		    rotateBack *
		    cell /
		    density;

		samplePosition =
		    center /
		    vec2(aspect, 1.0) +
		    0.5;
	}
	else
	{
		vec2 gridPosition =
		    vec2(uv.x * aspect, uv.y) *
		    density;

		vec2 center = hexCenter(gridPosition);

		samplePosition = vec2(
		                     center.x / density / aspect,
		                     center.y / density
		                 );
	}

	vec4 mosaic = texture(
	                  iChannel0,
	                  applyEdges(samplePosition)
	              );

	fragColor = mix(source, mosaic, uMix);
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
