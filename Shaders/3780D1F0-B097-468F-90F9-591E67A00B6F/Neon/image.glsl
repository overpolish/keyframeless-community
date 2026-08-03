// SPDX-FileCopyrightText: 2025 Paul Bakaus
// SPDX-License-Identifier: MIT

// #template generator

// #speed group={"Motion", "wind"}
// #seed group="Motion"

// #grain label="Grain" group={"Finish", "camera.filters"} default=10 size=2

// Four NAMED tiers - outer, surface, inner, core - each with its own
// multiplier below. Not a #gradient: a ramp has no way to say which stop is
// the core.
// #color label="Colours" min=1 max=4 default="#001518,#00E5FF,#7CFBFF,#FFFFFF"
uniform vec4 uColours[4];

// #color label="Background" default="#04060A"
uniform vec4 uColorBack;

// #percent label="Wisp Amount" group={"Shape", "scribble.variable"} min=0 max=100 default=70
uniform float uWisps;

// #percent label="Strand Density" group="Shape" min=20 max=250 default=100
uniform float uStrands;

// #percent label="Radiance" group={"Appearance", "sun.max.fill"} min=0 max=200 default=100
uniform float uRadiance;

// #point label="Center" group={"Transform", "viewfinder"} osc=position default="0.5,0.5"
uniform vec2 uCenter;

// #percent label="Scale" group="Transform" min=25 max=400 default=100 osc=ring link=uCenter
uniform float uScale;

float hash21(vec2 position)
{
	position = fract(position * vec2(123.34, 456.21));
	position += dot(position, position + 45.164);
	return fract(position.x * position.y);
}

float valueNoise(vec2 position)
{
	vec2 cell = floor(position);
	vec2 local = fract(position);
	vec2 blend = local * local * (3.0 - 2.0 * local);

	float bottomLeft = hash21(cell);
	float bottomRight = hash21(cell + vec2(1.0, 0.0));
	float topLeft = hash21(cell + vec2(0.0, 1.0));
	float topRight = hash21(cell + vec2(1.0, 1.0));

	return mix(
	           mix(bottomLeft, bottomRight, blend.x),
	           mix(topLeft, topRight, blend.x),
	           blend.y
	       );
}

float tendrilField(vec2 position, float time)
{
	vec2 strandPosition = position * uStrands;

	float broad = valueNoise(
	                  vec2(
	                      strandPosition.x * 6.0 - time * 0.125,
	                      strandPosition.y * 6.0 + time * 0.100
	                  ) + 10.0
	              );

	float detail = valueNoise(
	                   vec2(
	                       strandPosition.x * 12.0 + time * 0.150,
	                       strandPosition.y * 11.0 - time * 0.140
	                   ) + vec2(23.7, 20.0)
	               );

	float structure = valueNoise(
	                      vec2(
	                          strandPosition.x * 3.0,
	                          strandPosition.y * 3.5 - time * 0.075
	                      ) + vec2(7.1, 0.0)
	                  );

	float tendrils = broad * 0.5 + detail * 0.3 + structure * 0.2;
	tendrils = smoothstep(0.40, 0.62, tendrils);

	float confinement = smoothstep(
	                        1.25,
	                        0.15,
	                        length(position * vec2(0.95, 1.0))
	                    );

	return tendrils * confinement;
}

float vignette(vec2 position)
{
	return smoothstep(1.3, 0.4, length(position * vec2(0.9, 1.0)));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 resolution = iResolution.xy;
	float aspect = resolution.x / resolution.y;

	vec2 position = (fragCoord - uCenter) / resolution.y;
	position /= max(uScale, 0.001);

	float backgroundDistance = length(position * vec2(0.8, 1.0));
	vec3 color = uColorBack.rgb * uColorBack.a * max(1.0 - backgroundDistance * 0.3, 0.0);

	float field = tendrilField(position, iTime);
	float wisps = clamp(field * uWisps * 1.4, 0.0, 2.0);

	float outerGlow = smoothstep(0.04, 0.30, wisps);
	float surface = smoothstep(0.20, 0.52, wisps);
	float inner = smoothstep(0.45, 0.85, wisps);
	float core = smoothstep(0.85, 1.30, wisps);

	int colourCount = max(uColoursCount, 1);
	vec4 outerSwatch = uColours[0];
	vec4 surfaceSwatch = uColours[min(1, colourCount - 1)];
	vec4 innerSwatch = uColours[min(2, colourCount - 1)];
	vec4 coreSwatch = uColours[min(3, colourCount - 1)];

	vec3 outerColor = outerSwatch.rgb * outerSwatch.a * 1.2 * uRadiance;
	vec3 surfaceColor = surfaceSwatch.rgb * surfaceSwatch.a * 2.5 * uRadiance;
	vec3 innerColor = innerSwatch.rgb * innerSwatch.a * 3.5 * uRadiance;
	vec3 coreColor = coreSwatch.rgb * coreSwatch.a * 5.0 * uRadiance;

	vec3 wispColor = outerColor * outerGlow;
	wispColor = mix(wispColor, surfaceColor, surface * 0.95);
	wispColor = mix(wispColor, innerColor, inner * 0.95);
	wispColor = mix(wispColor, coreColor, core);
	wispColor += surfaceColor * 0.4 * surface * (1.0 - inner);

	color += wispColor;

	float ambient = valueNoise(
	                    vec2(
	                        position.x * 3.0 + iTime * 0.1,
	                        position.y * 3.0
	                    ) + 50.0
	                );

	ambient = smoothstep(0.4, 0.6, ambient) * 0.06;
	color += outerColor * ambient * 0.15;
	color *= vignette(position);

	color = max(color, vec3(0.0));
	color = color * (2.51 * color + 0.03) /
	        (color * (2.43 * color + 0.59) + 0.14);
	color = pow(max(color, vec3(0.0)), vec3(0.90));

	fragColor = vec4(color, 1.0);
}