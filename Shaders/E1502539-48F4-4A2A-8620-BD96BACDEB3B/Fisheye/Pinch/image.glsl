// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT
//
// Fisheye - a lens distortion filter over the source clip: bulge or pinch,
// centred on a draggable point with a draggable radius ring. Samples outside the
// frame are cut (premultiplied to empty), so nothing smears.

// #percent label="Amount" default=70
uniform float uAmount;

// #percent label="Radius" default=100 osc=ring link=uCenter
uniform float uRadius;

// #point label="Center" osc default="0.5,0.5"
uniform vec2 uCenter;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;
	float aspect = iResolution.x / iResolution.y;
	vec2 c = uCenter / iResolution.xy;

	vec2 d = (uv - c) * vec2(aspect, 1.0);
	float r = length(d);
	vec2 dir = r > 1e-5 ? d / r : vec2(0.0);

	float maxR = length(max(c, 1.0 - c) * vec2(aspect, 1.0));
	float R = max(maxR * uRadius, 0.01);

	float power = (uAmount - 0.5) * 2.5;

	float rEff = r;
	float rr = r / R;
	if (rr < 1.0)
	{
		float e = exp(power);
		float rn = pow(rr, e) * R;
		float blend = smoothstep(1.0, 0.75, rr);
		rEff = mix(r, rn, blend);
	}

	vec2 nd = dir * rEff;
	vec2 suv = c + vec2(nd.x / aspect, nd.y);

	float m = smoothstep(0.0, 0.004, suv.x) * smoothstep(1.0, 0.996, suv.x)
	          * smoothstep(0.0, 0.004, suv.y) * smoothstep(1.0, 0.996, suv.y);

	vec4 src = texture(iChannel0, clamp(suv, 0.0, 1.0));
	fragColor = vec4(src.rgb * m, src.a * m); // premultiplied cut - no smear
}