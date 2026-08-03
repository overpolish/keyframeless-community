// SPDX-FileCopyrightText: 2011 Ashima Arts (simplex noise, Ian McEwan / stegu)
// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template filter

// #speed group={"Motion", "wind"}
// #seed group="Motion"

// #percent label="Amount" group={"Distortion", "waveform.path"} min=0 max=200 default=100
uniform float uAmount;

// #percent label="RGB Shift" group="Distortion" min=0 max=200 default=100
uniform float uRGBShift;

// #percent label="Interference" group={"Signal", "antenna.radiowaves.left.and.right"} min=0 max=200 default=100
uniform float uInterference;

// #percent label="Scanlines" group="Signal" min=0 max=200 default=100
uniform float uScanlines;

// #int label="Scanline Size" group="Signal" units="px" min=1 max=16 default=4
uniform float uScanlineSize;

vec3 mod289(vec3 value)
{
	return value - floor(value / 289.0) * 289.0;
}

vec2 mod289(vec2 value)
{
	return value - floor(value / 289.0) * 289.0;
}

vec3 permute(vec3 value)
{
	return mod289((value * 34.0 + 1.0) * value);
}

// Ashima Arts' 2D simplex noise from webgl-noise.
float simplexNoise(vec2 position)
{
	const vec4 coefficients = vec4(
	                              0.211324865405187,
	                              0.366025403784439,
	                              -0.577350269189626,
	                              0.024390243902439
	                          );

	vec2 cell = floor(position + dot(position, coefficients.yy));
	vec2 local = position - cell + dot(cell, coefficients.xx);
	vec2 offset = local.x > local.y ? vec2(1.0, 0.0) : vec2(0.0, 1.0);

	vec4 corners = local.xyxy + coefficients.xxzz;
	corners.xy -= offset;

	cell = mod289(cell);

	vec3 permutation = permute(
	                       permute(cell.y + vec3(0.0, offset.y, 1.0)) +
	                       cell.x +
	                       vec3(0.0, offset.x, 1.0)
	                   );

	vec3 weight = max(
	                  0.5 - vec3(
	                      dot(local, local),
	                      dot(corners.xy, corners.xy),
	                      dot(corners.zw, corners.zw)
	                  ),
	                  0.0
	              );

	weight *= weight;
	weight *= weight;

	vec3 gradient = 2.0 * fract(permutation * coefficients.www) - 1.0;
	vec3 height = abs(gradient) - 0.5;
	vec3 rounded = floor(gradient + 0.5);
	vec3 remainder = gradient - rounded;

	weight *=
	    1.79284291400159 -
	    0.85373472095314 *
	    (remainder * remainder + height * height);

	vec3 contribution;
	contribution.x = remainder.x * local.x + height.x * local.y;
	contribution.yz = remainder.yz * corners.xz + height.yz * corners.yw;

	return 130.0 * dot(weight, contribution);
}

float randomValue(vec2 position)
{
	return fract(
	           sin(dot(position, vec2(12.9898, 78.233))) *
	           43758.5453
	       );
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;
	float time = iTime * 2.0;

	float noise =
	    max(
	        0.0,
	        simplexNoise(vec2(time, uv.y * 0.3)) - 0.3
	    ) /
	    0.7;

	noise +=
	    (
	        simplexNoise(vec2(time * 10.0, uv.y * 2.4)) -
	        0.5
	    ) *
	    0.15;

	noise *= uAmount;

	float displacedX = uv.x - noise * noise * 0.25;
	fragColor = texture(iChannel0, vec2(displacedX, uv.y));

	float interference =
	    noise *
	    0.3 *
	    uInterference;

	fragColor.rgb = mix(
	                    fragColor.rgb,
	                    vec3(randomValue(vec2(uv.y * time))),
	                    interference
	                );

	float scanlineSize = max(float(uScanlineSize), 1.0);
	float scanlineBand = floor(mod(fragCoord.y / scanlineSize, 2.0));

	if (scanlineBand == 0.0)
		fragColor.rgb *= 1.0 - 0.15 * noise * uScanlines;

	float shift = noise * 0.05 * uRGBShift;

	float shiftedGreen = texture(
	                         iChannel0,
	                         vec2(displacedX + shift, uv.y)
	                     ).g;

	float shiftedBlue = texture(
	                        iChannel0,
	                        vec2(displacedX - shift, uv.y)
	                    ).b;

	// The taps are read from the raw source, so mixing them in at a fixed weight
	// would drag green and blue back toward un-interfered footage even at RGB
	// Shift 0, where the shift itself is zero and the control should do nothing.
	// Ramping the weight with the control up to its 100% value keeps the
	// documented look at default and makes zero an exact no-op.
	float shiftWeight = 0.25 * clamp(uRGBShift, 0.0, 1.0);

	fragColor.g = mix(fragColor.g, shiftedGreen, shiftWeight);
	fragColor.b = mix(fragColor.b, shiftedBlue, shiftWeight);
}
