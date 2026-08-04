// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template generator
// #alpha

// #audio label="Music" gate=-70 release=0.14 smooth=0.09
uniform vec4 uMusic[16];

// #int label="Bar Count" group={"Spectrum", "chart.bar.fill"} min=4 max=64 default=48
uniform int uBars;

// #percent label="Bar Width" group="Spectrum" min=0 max=100 default=68
uniform float uBarW;

// #percent label="Height" group="Spectrum" min=0 max=100 default=55
uniform float uHeight;

// #float label="Tilt" group={"Response", "slider.horizontal.3"} units="dB/oct" min=0 max=9 default=3
uniform float uTilt;

// #float label="Curve" group="Response" min=0.3 max=3 default=1
uniform float uCurve;

// #percent label="Floor" group="Response" min=0 max=20 default=2
uniform float uFloor;

// #percent label="Baseline" group={"Layout", "rectangle.3.group"} min=0 max=100 default=0
uniform float uBase;

// #percent label="Roundness" group={"Style", "sparkles"} min=0 max=100 default=100
uniform float uRound;

// #percent label="Glow" group="Style" min=0 max=100 default=35
uniform float uGlowAmt;

// #percent label="Reflection" group="Style" min=0 max=100 default=35
uniform float uReflect;

// #color label="Low Color" default="#FF3D7F"
uniform vec4 uLowColor;

// #color label="High Color" default="#3DE0FF"
uniform vec4 uHighColor;

float sdRoundBox(vec2 point, vec2 halfSize, float radius)
{
	radius = min(radius, min(halfSize.x, halfSize.y));
	vec2 q = abs(point) - halfSize + radius;

	return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - radius;
}

float barLevel(int bar)
{
	float bandSpan = float(uMusicBands) / float(uBars);
	float firstBand = float(bar) * bandSpan;

	int first = clamp(int(floor(firstBand)), 0, uMusicBands - 1);
	int last = clamp(int(floor(firstBand + bandSpan - 0.0001)), first, uMusicBands - 1);

	float level;

	if (last > first)
	{
		level = 0.0;

		for (int i = 0; i < uMusicBands; ++i)
		{
			if (i < first)
				continue;

			if (i > last)
				break;

			level = max(level, uMusicBand(i));
		}
	}
	else
	{
		float center = clamp(
		                   firstBand + bandSpan * 0.5 - 0.5,
		                   0.0,
		                   float(uMusicBands - 1)
		               );

		int lower = int(floor(center));
		int upper = min(lower + 1, uMusicBands - 1);

		level = mix(uMusicBand(lower), uMusicBand(upper), fract(center));
	}

	// Sonar bands are already log-spaced. 9.06 is how many octaves the 30 Hz
	// to 16 kHz analysis span covers, and 70 is the dB window a band level of
	// 0..1 represents, so the two turn dB per octave into level units.
	float frequency = (float(bar) + 0.5) / float(uBars);
	level += (uTilt * 9.06) * frequency / 70.0;

	return clamp(level, 0.0, 1.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 resolution = iResolution.xy;
	float aspect = resolution.x / resolution.y;
	vec2 p = fragCoord / resolution.y;

	float pitch = aspect / float(uBars);
	int bar = int(clamp(floor(p.x / pitch), 0.0, float(uBars - 1)));

	float barCenter = (float(bar) + 0.5) * pitch;
	float halfWidth = pitch * 0.5 * uBarW;
	float level = pow(barLevel(bar), uCurve);
	float height = max(mix(uFloor, uHeight, level), halfWidth * 0.6);
	float radius = halfWidth * uRound;
	float y = p.y - uBase;

	float upperDistance = sdRoundBox(
	                          vec2(p.x - barCenter, y - height * 0.5),
	                          vec2(halfWidth, height * 0.5),
	                          radius
	                      );

	float reflectedHeight = height * 0.55;

	float reflectedDistance = sdRoundBox(
	                              vec2(p.x - barCenter, -y - reflectedHeight * 0.5),
	                              vec2(halfWidth, reflectedHeight * 0.5),
	                              radius
	                          );

	float antialias = 1.5 / resolution.y;
	float upperFill = 1.0 - smoothstep(-antialias, antialias, upperDistance);
	float reflectionShape = 1.0 - smoothstep(-antialias, antialias, reflectedDistance);
	float reflectionFade = 1.0 - smoothstep(0.0, reflectedHeight, -y);
	float reflectedFill = reflectionShape * reflectionFade * uReflect;

	float glow = uGlowAmt * 0.02 / (max(upperDistance, 0.0) + 0.012);
	float barPosition = (float(bar) + 0.5) / float(uBars);
	vec3 tint = mix(uLowColor.rgb, uHighColor.rgb, barPosition);

	float alpha = clamp(
	                  upperFill + reflectedFill + glow * 0.5,
	                  0.0,
	                  1.0
	              );

	vec3 color = tint * (upperFill + reflectedFill + glow);

	vec3 straightColor = alpha > 0.0001 ? color / alpha : color;
	fragColor = vec4(straightColor, alpha);
}
