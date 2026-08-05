// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template filter

// #alpha

// #point label="Center" group={"Lens", "camera.filters"} osc=position default="0.5,0.5"
uniform vec2 uCenter;

// #percent label="Amount" group="Lens" min=0 max=100 default=70
uniform float uAmount;

// #percent label="Radius" group="Lens" min=5 max=800 slidermax=200 default=100 osc=ring link=uCenter
uniform float uRadius;

// #int label="Edge Feather" group="Lens" units="px" min=0 max=50 default=4
uniform float uFeather;

float frameMask(vec2 position, float feather)
{
	if (feather <= 0.0)
	{
		bool inside =
		    position.x >= 0.0 &&
		    position.x <= 1.0 &&
		    position.y >= 0.0 &&
		    position.y <= 1.0;

		return inside ? 1.0 : 0.0;
	}

	float left = smoothstep(0.0, feather, position.x);
	float right = 1.0 - smoothstep(1.0 - feather, 1.0, position.x);
	float bottom = smoothstep(0.0, feather, position.y);
	float top = 1.0 - smoothstep(1.0 - feather, 1.0, position.y);

	return left * right * bottom * top;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 resolution = iResolution.xy;
	vec2 uv = fragCoord / resolution;
	vec2 center = uCenter / resolution;

	float aspect = resolution.x / resolution.y;
	vec2 delta = (uv - center) * vec2(aspect, 1.0);

	float distance = length(delta);
	vec2 direction = distance > 0.00001 ? delta / distance : vec2(0.0);

	float maximumRadius =
	    length(max(center, 1.0 - center) * vec2(aspect, 1.0));

	float radius = max(maximumRadius * uRadius, 0.01);
	float power = (uAmount - 0.5) * 2.5;
	float effectiveDistance = distance;
	float normalizedDistance = distance / radius;

	if (normalizedDistance < 1.0)
	{
		float exponent = exp(power);
		float distortedDistance = pow(normalizedDistance, exponent) * radius;

		float blend =
		    1.0 -
		    smoothstep(0.75, 1.0, normalizedDistance);

		effectiveDistance = mix(distance, distortedDistance, blend);
	}

	vec2 distorted = direction * effectiveDistance;

	vec2 samplePosition =
	    center +
	    vec2(
	        distorted.x / aspect,
	        distorted.y
	    );

	float feather =
	    (uFeather * resolution.y / 1080.0) /
	    min(resolution.x, resolution.y);
	float mask = frameMask(samplePosition, feather);

	vec4 source = texture(
	                  iChannel0,
	                  clamp(samplePosition, 0.0, 1.0)
	              );

	vec3 straightColor =
	    source.a > 0.0001
	    ? source.rgb / source.a
	    : vec3(0.0);

	fragColor = vec4(straightColor, source.a * mask);
}
