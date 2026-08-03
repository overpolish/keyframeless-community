// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template generator

// #speed group={"Motion", "wind"}
// #seed group="Motion"

// #grain label="Grain" group={"Finish", "camera.filters"} default=0 size=2

// #color label="Colours" min=2 max=4 default="#5BC8E8,#B57EE8,#FF8FB0,#FFD98F"
uniform vec4 uColours[4];

// #int label="Cell Count" group={"Cells", "circle.hexagongrid"} min=6 max=28 default=16
uniform float uCells;

// #percent label="Wave" group="Cells" min=0 max=200 default=100
uniform float uWave;

// #percent label="Edge Width" group={"Glow", "sparkles"} min=10 max=250 default=100
uniform float uEdgeWidth;

// #percent label="Brightness" group="Glow" min=0 max=200 default=100
uniform float uGlow;

// #point label="Center" group={"Transform", "viewfinder"} osc=position default="0.5,0.5"
uniform vec2 uCenter;

// #percent label="Scale" group="Transform" min=25 max=400 default=100 osc=ring link=uCenter
uniform float uScale;

vec3 palette(float position)
{
	int count = max(uColoursCount, 1);

	if (count == 1)
		return uColours[0].rgb;

	float paletteIndex = clamp(position, 0.0, 1.0) * float(count - 1);
	int lower = int(floor(paletteIndex));
	int upper = min(lower + 1, count - 1);

	return mix(uColours[lower].rgb, uColours[upper].rgb, fract(paletteIndex));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 position = (fragCoord - uCenter) / iResolution.y;
	position *= 1.8 / max(uScale, 0.001);

	float time = iTime * 0.3;
	int cellCount = int(uCells);

	float nearestDistance = 9.0;
	float secondDistance = 9.0;
	vec2 nearestSite = vec2(0.0);

	for (int i = 0; i < 28; ++i)
	{
		if (i >= cellCount)
			break;

		float index = float(i);
		// Four rows is what the visible span holds at 0.5 apart. Sites past
		// the fourth wrap back to the first row instead of stacking off-frame,
		// where a raised Cell Count would add nothing.
		float row = mod(floor(index / 5.0), 4.0);

		vec2 site = vec2(
		                1.6 * sin(index * 2.3),
		                -0.75 + 0.5 * row + uWave * 0.28 * sin(index + time + position.x)
		            );

		float distanceToSite = distance(position, site);

		if (distanceToSite < nearestDistance)
		{
			secondDistance = nearestDistance;
			nearestDistance = distanceToSite;
			nearestSite = site;
		}
		else if (distanceToSite < secondDistance)
		{
			secondDistance = distanceToSite;
		}
	}

	float cellHue = 0.5 + 0.5 * sin(1.5 * nearestSite.x + 2.0 * nearestSite.y);
	float backgroundHue = 0.5 + 0.5 * sin(0.8 * position.x + 0.2 * time);
	vec3 color = mix(palette(backgroundHue), palette(cellHue), 0.6);

	float boundaryDistance = secondDistance - nearestDistance;
	float antialiasing = fwidth(boundaryDistance);
	float edgeWidth = 0.05 * uEdgeWidth;
	float bloomWidth = 0.25 * uEdgeWidth;

	float edge = 1.0 - smoothstep(edgeWidth - antialiasing, edgeWidth + antialiasing, boundaryDistance);
	float bloom = 1.0 - smoothstep(0.0, bloomWidth + antialiasing, boundaryDistance);

	color += edge * uGlow;
	color += bloom * palette(cellHue) * uGlow * 0.25;

	fragColor = vec4(color * 1.15, 1.0);
}