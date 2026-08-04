// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template filter

// #alpha
// A point the line passes through, dragged in the viewer. It is a position rather
// than a distance-from-centre because the thing being placed is a horizon, and a
// horizon is somewhere in the picture, not a number of percent from the middle.
// #point label="Position" group={"Grad", "line.diagonal"} osc=position default="0.5,0.5"
uniform vec2 uPosition;

// Rotation of the line, with its ring on the same point. 90 by default so the graded
// side is the TOP of the frame, which is what a graduated ND is for.
// #angle label="Angle" group="Grad" osc={z} link=uPosition default=90
uniform float uAngle;

// The width of the transition across the line, in frame heights, so the same value
// gives the same picture at every resolution and on every aspect ratio.
// #percent label="Softness" group="Grad" min=0 max=200 default=45
uniform float uSoftness;

// Signed stops on the graded side. Defaulted to a stop down so a fresh apply shows
// where the line is, which is the one thing the user needs to see before they can
// place it.
// #float label="Exposure" group={"Exposure", "sun.max"} units="stops" min=-5 max=5 default=-1
uniform float uExposure;

// Sky-grad blue, the colour a real glass grad is coated with. It has no effect until
// Tint Amount is raised, so the default is a starting point rather than a look.
// #color label="Tint" default="#7FA8D6"
uniform vec4 uTint;

// #percent label="Tint Amount" group={"Tint", "paintbrush"} min=0 max=100 default=0
uniform float uTintAmount;

// #percent label="Mix" group={"Finish", "switch.2"} min=0 max=100 default=100
uniform float uMix;

// 0 well on the ungraded side, 1 well on the graded side, exactly 0.5 on the line.
float gradMask(vec2 uv, vec2 resolution)
{
	float aspect = resolution.x / resolution.y;

	// A #point arrives in fragCoord pixels, so dividing by the resolution lands it in
	// the same space as uv with no flip: both have y increasing DOWNWARD. The flip
	// belongs at the object-space boundary, and there is no object space here.
	vec2 offset = (uv - uPosition / resolution) * vec2(aspect, 1.0);

	// #angle delivers radians(-degrees), which is what makes a rotation read the same
	// way round in this y-down space as it does on the dial. So the axis drops
	// straight in, and a positive Angle swings the graded side anticlockwise on
	// screen: 0 grades the right, 90 the top, 180 the left.
	vec2 axis = vec2(cos(uAngle), sin(uAngle));
	float across = dot(offset, axis);

	// Half the declared width each side of the line. The fwidth floor keeps a
	// Softness of 0 as a clean antialiased edge rather than a staircase.
	float halfWidth = max(uSoftness * 0.5, fwidth(across));

	return smoothstep(-halfWidth, halfWidth, across);
}

void mirageFilterImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 resolution = iResolution.xy;
	vec2 uv = fragCoord / resolution;
	vec4 source = texture(iChannel0, uv);

	float mask = gradMask(uv, resolution);
	vec3 linear = decodeToLinear(source.rgb);

	// A glass grad is neutral density: it takes a fixed fraction of the LIGHT away
	// from one side of the frame. exp2 on linear values is that, and it is why a
	// -1 stop grad holds a sky's cloud detail instead of flattening it. The same
	// scaling on encoded code values would pull the transition line into visibility
	// as a banding edge, because the amount of tone it eats changes with brightness.
	linear *= exp2(uExposure * mask);

	// The tint is a filter normalised to luminance 1, so Tint Amount only changes the
	// colour of the graded side. Exposure stays the only control that decides how far
	// down that side goes, which is what makes the two stackable without a fight.
	vec3 tint = decodeToLinear(uTint.rgb);
	float tintLuma = dot(tint, vec3(0.2126, 0.7152, 0.0722));
	vec3 tintFilter = tintLuma > 0.0001 ? tint / tintLuma : vec3(1.0);
	linear *= mix(vec3(1.0), tintFilter, clamp(uTintAmount, 0.0, 1.0) * mask);

	vec3 graded = encodeFromLinear(max(linear, 0.0));
	fragColor = vec4(mix(source.rgb, graded, uMix), source.a);
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
