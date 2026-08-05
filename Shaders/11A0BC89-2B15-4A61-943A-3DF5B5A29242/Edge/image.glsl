// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template filter

// #alpha
// #int label="Levels" group={"Posterise", "square.stack.3d.up"} min=2 max=8 default=4
uniform float uLevels;

// #percent label="Amount" group={"Edges", "scribble"} min=0 max=100 default=100
uniform float uEdges;

// #int label="Width" group="Edges" units="px" min=1 max=8 default=1
uniform float uEdgeWidth;

// #percent label="Threshold" group="Edges" min=0 max=200 default=40
uniform float uEdgeThreshold;

// #percent label="Softness" group="Edges" min=1 max=200 default=80
uniform float uEdgeSoftness;

// #color label="Edge Colour" default="#0A0A0A"
uniform vec4 uEdgeCol;

float luminanceAt(vec2 position)
{
	vec3 color = texture(iChannel0, clamp(position, 0.0, 1.0)).rgb;
	return dot(color, vec3(0.299, 0.587, 0.114));
}

void mirageFilterImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;
	vec4 source = texture(iChannel0, uv);

	float levels = max(float(uLevels), 2.0);
	vec3 posterised = floor(source.rgb * (levels - 1.0) + 0.5) / (levels - 1.0);

	vec2 pixelStep = (uEdgeWidth * iResolution.y / 1080.0) / iResolution.xy;

	float topLeft = luminanceAt(uv + pixelStep * vec2(-1.0, 1.0));
	float top = luminanceAt(uv + pixelStep * vec2(0.0, 1.0));
	float topRight = luminanceAt(uv + pixelStep * vec2(1.0, 1.0));
	float left = luminanceAt(uv + pixelStep * vec2(-1.0, 0.0));
	float right = luminanceAt(uv + pixelStep * vec2(1.0, 0.0));
	float bottomLeft = luminanceAt(uv + pixelStep * vec2(-1.0, -1.0));
	float bottom = luminanceAt(uv + pixelStep * vec2(0.0, -1.0));
	float bottomRight = luminanceAt(uv + pixelStep * vec2(1.0, -1.0));

	float horizontal =
	    topRight +
	    2.0 * right +
	    bottomRight -
	    topLeft -
	    2.0 * left -
	    bottomLeft;

	float vertical =
	    topLeft +
	    2.0 * top +
	    topRight -
	    bottomLeft -
	    2.0 * bottom -
	    bottomRight;

	float magnitude = length(vec2(horizontal, vertical));
	float softness = max(uEdgeSoftness, 0.0001);

	float edge = smoothstep(
	                 uEdgeThreshold,
	                 uEdgeThreshold + softness,
	                 magnitude
	             );

	edge *= uEdges;

	vec3 color = mix(posterised, uEdgeCol.rgb, edge);
	fragColor = vec4(color, source.a);
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
