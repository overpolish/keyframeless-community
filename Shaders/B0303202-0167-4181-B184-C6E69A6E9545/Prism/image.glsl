// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template filter

// #alpha
// #choice label="Glass" group={"Pattern", "circle.hexagongrid"} options="Facets,Fluted,Tiles" default=0
uniform int uStyle;

// #int label="Cell Size" group="Pattern" units="px" min=12 slidermax=240 default=80
uniform float uCellSize;

// #angle label="Rotation" group="Pattern" default=0 osc={z} link=uCenter
uniform float uRotation;

// #point label="Center" group="Pattern" osc=position default="0.5,0.5"
uniform vec2 uCenter;

// #percent label="Refraction" group={"Appearance", "sparkles"} min=0 max=100 default=35
uniform float uRefraction;

// #percent label="Dispersion" group="Appearance" min=0 max=100 default=18
uniform float uDispersion;

// #percent label="Edge Light" group="Appearance" min=0 max=100 default=30
uniform float uEdgeLight;

// #percent label="Frost" group="Appearance" min=0 max=100 default=8
uniform float uFrost;

// #percent label="Mix" group={"Finish", "switch.2"} min=0 max=100 default=100
uniform float uMix;

const float TAU = 6.28318530718;

float glassHash(vec2 position)
{
	position = fract(position * vec2(0.3183099, 0.3678794)) + 0.1;
	position += dot(position, position + 19.19);
	return fract(position.x * position.y);
}

vec2 glassDirection(vec2 cell)
{
	float angle = glassHash(cell) * TAU;
	return vec2(cos(angle), sin(angle));
}

vec2 glassRotate(vec2 value, float angle)
{
	float sine = sin(angle);
	float cosine = cos(angle);
	return vec2(cosine * value.x + sine * value.y, -sine * value.x + cosine * value.y);
}

void glassPattern(vec2 position, out vec2 surfaceNormal, out float edge)
{
	float cellSize = max(uCellSize * iResolution.y / 1080.0, 1.0);
	vec2 grid = position / cellSize;
	vec2 cell = floor(grid);
	vec2 local = fract(grid) - 0.5;
	float aa = max(fwidth(grid.x), fwidth(grid.y));

	if (uStyle == 0)
	{
		float triangle = step(local.y, local.x);
		vec2 facet = cell * 2.0 + vec2(triangle, 1.0 - triangle);
		surfaceNormal = glassDirection(facet);

		float outerEdge = min(0.5 - abs(local.x), 0.5 - abs(local.y));
		float diagonalEdge = abs(local.x - local.y) * 0.70710678;
		float edgeDistance = min(outerEdge, diagonalEdge);
		edge = 1.0 - smoothstep(aa, aa * 4.0, edgeDistance);
	}
	else if (uStyle == 1)
	{
		float phase = grid.x * TAU;
		surfaceNormal = vec2(cos(phase), 0.0);

		float ridge = abs(sin(phase));
		edge = 1.0 - smoothstep(0.0, max(fwidth(phase) * 2.0, 0.08), ridge);
	}
	else
	{
		vec2 tileNormal = local / sqrt(0.08 + dot(local, local));
		surfaceNormal = tileNormal;

		float edgeDistance = min(0.5 - abs(local.x), 0.5 - abs(local.y));
		edge = 1.0 - smoothstep(aa, aa * 4.0, edgeDistance);
	}
}

vec3 glassSample(vec2 pixelPosition)
{
	vec2 uv = clamp(pixelPosition / iResolution.xy, 0.0, 1.0);
	return texture(iChannel0, uv).rgb;
}

void mirageFilterImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 centered = fragCoord - uCenter;
	vec2 patternPosition = glassRotate(centered, uRotation);

	vec2 patternNormal;
	float edge;
	glassPattern(patternPosition, patternNormal, edge);

	vec2 screenNormal = glassRotate(patternNormal, -uRotation);
	float refraction = uRefraction * uCellSize * iResolution.y / 1080.0 * 0.18;
	vec2 displacement = screenNormal * refraction;

	float separation = uDispersion * 12.0;
	vec2 chromaOffset = screenNormal * separation;
	vec2 samplePosition = fragCoord + displacement;

	vec3 glassColor;
	glassColor.r = glassSample(samplePosition + chromaOffset).r;
	glassColor.g = glassSample(samplePosition).g;
	glassColor.b = glassSample(samplePosition - chromaOffset).b;

	float frostRadius = uFrost * uCellSize * iResolution.y / 1080.0 * 0.08;
	if (frostRadius > 0.001)
	{
		vec2 diagonal = vec2(0.70710678) * frostRadius;
		vec3 blurred = glassSample(samplePosition + vec2(frostRadius, 0.0));
		blurred += glassSample(samplePosition + vec2(-frostRadius, 0.0));
		blurred += glassSample(samplePosition + vec2(0.0, frostRadius));
		blurred += glassSample(samplePosition + vec2(0.0, -frostRadius));
		blurred += glassSample(samplePosition + diagonal);
		blurred += glassSample(samplePosition - diagonal);
		blurred *= 1.0 / 6.0;
		glassColor = mix(glassColor, blurred, uFrost);
	}

	float facing = 0.5 + 0.5 * dot(normalize(screenNormal + vec2(0.0001)), normalize(vec2(-0.6, 0.8)));
	float edgeLight = edge * uEdgeLight;
	glassColor *= 1.0 + edgeLight * (0.08 + 0.12 * facing);
	glassColor += edgeLight * (0.12 + 0.18 * facing);

	vec4 source = texture(iChannel0, fragCoord / iResolution.xy);
	fragColor = vec4(mix(source.rgb, glassColor, uMix), source.a);
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
