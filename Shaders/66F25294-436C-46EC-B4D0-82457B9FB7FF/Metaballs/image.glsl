// SPDX-FileCopyrightText: The paper-design/shaders authors
// SPDX-License-Identifier: Apache-2.0
//
// Metaballs - derived from the metaballs shader in paper-design/shaders
// (https://github.com/paper-design/shaders). Translated to GLSL for Shader and
// adapted for its directive controls. Coloured gooey balls roam on smooth noise
// paths and merge into organic blobs over a background.

// #color label="Colours" min=1 max=6 default="#FF5FA2,#7A5CFF,#33C4FF,#4DE3B0"
uniform vec4 uColours[6];

// #color label="Background" default="#0A0A14"
uniform vec4 uBackground;

// #int label="Balls" min=1 max=20 default=8
uniform float uBalls;

// #percent label="Ball Size" default=75
uniform float uBallSize;

// #point label="Center" osc default="0.5,0.5"
uniform vec2 uCenter;

// #percent label="Scale" default=100 osc=ring link=uCenter
uniform float uScale;

const int MB_MAX_BALLS = 20;

float mbHash21(vec2 p)
{
	p = fract(p * vec2(0.3183099, 0.3678794)) + 0.1;
	p += dot(p, p + 19.19);
	return fract(p.x * p.y);
}

// Smooth 1D drift (Catmull-Rom through hashed points): continuous velocity, so
// blobs glide instead of easing to a near-stop at each control point.
float mbNoise(float x)
{
	float i = floor(x);
	float f = fract(x);
	float a = mbHash21(vec2(i - 1.0, 0.0));
	float b = mbHash21(vec2(i, 0.0));
	float c = mbHash21(vec2(i + 1.0, 0.0));
	float d = mbHash21(vec2(i + 2.0, 0.0));
	return 0.5 * (2.0 * b + (-a + c) * f + (2.0 * a - 5.0 * b + 4.0 * c - d) * f * f +
	              (-a + 3.0 * b - 3.0 * c + d) * f * f * f);
}

float mbBall(vec2 uv, vec2 c, float p)
{
	float s = 0.5 * length(uv - c);
	s = 1.0 - clamp(s, 0.0, 1.0);
	return pow(s, p);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	float aspect = iResolution.x / iResolution.y;
	// Value noise loses precision at large arguments, so wrap the phase (a no-op
	// for normal clips; only bites huge Seed / very long timelines).
	float tAnim = 0.2 * mod(iTime, 2048.0); // Speed/Seed shape iTime

	vec2 origin = uCenter / iResolution.xy; // #point delivers pixels
	vec2 c = fragCoord / iResolution.xy - (origin - 0.5) - 0.5;
	c.x *= aspect; // round balls
	c /= max(uScale, 0.01);
	vec2 shapeUV = c + 0.5;

	float count = max(1.0, uBalls);
	int cCount = int(max(float(uColoursCount), 1.0) + 0.5);

	vec3 totalColor = vec3(0.0);
	float totalShape = 0.0;
	float totalOpacity = 0.0;

	for (int i = 0; i < MB_MAX_BALLS; i++)
	{
		if (i >= int(ceil(count)))
			break;

		float idxFract = float(i) / float(MB_MAX_BALLS);
		float angle = 6.28318530718 * idxFract;
		float speed = 1.0 - 0.2 * idxFract;

		float noiseX = mbNoise(angle * 10.0 + float(i) + tAnim * speed);
		float noiseY = mbNoise(angle * 20.0 + float(i) - tAnim * speed);
		vec2 pos = vec2(0.5) + 1e-4 + 0.9 * (vec2(noiseX, noiseY) - 0.5);

		vec4 ballColor = uColours[i % cCount];
		ballColor.rgb *= ballColor.a;

		float sizeFrac = 1.0;
		if (float(i) > floor(count - 1.0))
			sizeFrac *= fract(count);

		float shape = mbBall(shapeUV, pos, 45.0 - 30.0 * uBallSize * sizeFrac);
		shape *= pow(uBallSize, 0.2);
		shape = smoothstep(0.0, 1.0, shape);

		totalColor += ballColor.rgb * shape;
		totalShape += shape;
		totalOpacity += ballColor.a * shape;
	}

	totalColor /= max(totalShape, 1e-4);
	totalOpacity /= max(totalShape, 1e-4);

	float edgeW = fwidth(totalShape);
	float finalShape = smoothstep(0.4, 0.4 + edgeW, totalShape);

	vec3 color = totalColor * finalShape;
	float opacity = totalOpacity * finalShape;

	vec3 bg = uBackground.rgb * uBackground.a;
	color = color + bg * (1.0 - opacity);
	opacity = opacity + uBackground.a * (1.0 - opacity);

	fragColor = vec4(color, opacity);
}