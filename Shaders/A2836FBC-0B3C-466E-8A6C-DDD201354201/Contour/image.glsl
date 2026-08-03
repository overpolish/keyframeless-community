// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template generator

// #speed group={"Motion", "wind"}
// #seed group="Motion"
// #grain label="Grain" group={"Finish", "camera.filters"} default=0 size=2

// #color label="Colours" min=2 max=4 default="#AD1AE6,#99CCF0,#FFAD66,#FA6159"
uniform vec4 uColours[4];

// #percent label="Swirl" group={"Pattern", "circle.hexagongrid"} min=0 max=200 default=100
uniform float uSwirl;

// #int label="Lines" group="Pattern" min=8 max=80 default=40
uniform float uLines;

// #percent label="Line Intensity" group="Pattern" min=0 max=100 default=60
uniform float uLineIntensity;

// #point label="Center" group={"Transform", "viewfinder"} osc=position default="0.5,0.5"
uniform vec2 uCenter;

// #percent label="Scale" group="Transform" min=25 max=400 default=100 osc=ring link=uCenter
uniform float uScale;

vec3 samplePalette(float position)
{
	int count = max(uColoursCount, 1);

	if (count == 1)
		return uColours[0].rgb;

	float paletteIndex = clamp(position, 0.0, 1.0) * float(count - 1);
	int lower = int(floor(paletteIndex));
	int upper = min(lower + 1, count - 1);

	return mix(uColours[lower].rgb, uColours[upper].rgb, fract(paletteIndex));
}

vec2 swirlField(vec2 position, float time, float amount)
{
	float angle =
	    sin(position.x * 2.0 + time) +
	    cos(position.y * 2.3 - time * 0.7);

	angle *= amount * 0.6;

	float cosine = cos(angle);
	float sine = sin(angle);

	return mat2(cosine, -sine, sine, cosine) * position;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 position = (fragCoord - uCenter) / iResolution.y;
	position /= max(uScale, 0.01);

	float time = iTime * 0.5;
	vec2 swirled = swirlField(position, time, uSwirl);

	float palettePosition = clamp(
	                            0.5 + 0.5 * (swirled.x * 0.6 + swirled.y * 0.5),
	                            0.0,
	                            1.0
	                        );

	vec3 color = samplePalette(palettePosition);
	color = clamp(color * (0.85 + color * 0.35), 0.0, 1.0);

	float contourPosition = palettePosition * float(uLines);
	float contourDistance = min(fract(contourPosition), 1.0 - fract(contourPosition));
	float antialias = fwidth(contourPosition) + 0.0001;

	float line =
	    1.0 -
	    smoothstep(
	        0.06,
	        0.06 + antialias,
	        contourDistance
	    );

	float lineVariation =
	    0.5 +
	    0.5 * sin(swirled.x * 0.6 + time * 0.5);

	line *= mix(0.35, 1.0, lineVariation) * uLineIntensity;

	vec3 highlight = mix(color, vec3(1.0), 0.6);
	color = mix(color, highlight, line);

	fragColor = vec4(color, 1.0);
}