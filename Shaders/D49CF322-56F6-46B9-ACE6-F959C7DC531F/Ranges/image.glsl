// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template filter

// #color-surface ring=hue

// Three handles in one circle. Controls sharing a `puck=` name share a handle, so
// all three corrections are visible and draggable at once - no mode control, and no
// switching back and forth to compare what the shadows are doing to what the
// highlights are doing.

// Each control points at the hue it actually produces, measured on the same perceptual
// scale that paints the ring. Push a puck toward the part of the ring you want in that
// tonal range and that is what you get. All three pucks share the two directions, so a
// warm-shadow cool-highlight split reads as two handles leaning opposite ways round the
// same wheel. No compass labels - red and cyan are 166 degrees apart and green and
// magenta 186, so a square four-word cross would have to lie about where the colours are.

// #float label="Red / Cyan" group={"Shadows", "moon"} puck={"Shadows", "moon"} min=-100 max=100 default=0 surface="x:+35 y:+19"
uniform float uShadowRC;

// #float label="Green / Magenta" group={"Shadows", "moon"} puck={"Shadows", "moon"} min=-100 max=100 default=0 surface="x:-32 y:+25"
uniform float uShadowGM;

// #float label="Red / Cyan" group={"Midtones", "circle"} puck={"Midtones", "circle"} min=-100 max=100 default=0 surface="x:+35 y:+19"
uniform float uMidRC;

// #float label="Green / Magenta" group={"Midtones", "circle"} puck={"Midtones", "circle"} min=-100 max=100 default=0 surface="x:-32 y:+25"
uniform float uMidGM;

// #float label="Red / Cyan" group={"Highlights", "sun.max"} puck={"Highlights", "sun.max"} min=-100 max=100 default=0 surface="x:+35 y:+19"
uniform float uHighRC;

// #float label="Green / Magenta" group={"Highlights", "sun.max"} puck={"Highlights", "sun.max"} min=-100 max=100 default=0 surface="x:-32 y:+25"
uniform float uHighGM;

// Shadows, midtones and highlights are the three ranges a grade argues in, so
// the set of three is fixed. What is not fixed is WHERE one stops being the
// next: a shot lit at the top of the range and a shot lit at the bottom
// disagree about which tones are "the shadows" by more than any amount of
// falloff can absorb. So the two boundaries are controls and the range set is
// not.
//
// Each boundary is the luminance the range reaches, and falloff is how far back
// from it the handover starts - which is exactly the reading the fixed windows
// already had, with 45 and 55 the numbers they were built at. So a project made
// before these controls existed opens on its own render.
//
// No `pick=` on either. The eyedropper writes every subscribed control in one
// click, so two boundaries subscribed to it would both land on the tone that
// was clicked and close the midtone band completely.

// #percent label="Shadows End" group={"Shadows", "moon"} min=0 max=100 default=45
uniform float uShadowEnd;

// #percent label="Shadow Falloff" group={"Shadows", "moon"} min=5 max=100 default=45
uniform float uShadowFalloff;

// #percent label="Highlights Start" group={"Highlights", "sun.max"} min=0 max=100 default=55
uniform float uHighStart;

// #percent label="Highlight Falloff" group={"Highlights", "sun.max"} min=5 max=100 default=45
uniform float uHighFalloff;

// #percent label="Preserve Brightness" group={"Finish", "switch.2"} min=0 max=100 default=100
uniform float uPreserve;

// #percent label="Mix" group={"Finish", "switch.2"} min=0 max=100 default=100
uniform float uMix;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;
	vec4 source = texture(iChannel0, uv);

	vec3 linear = decodeToLinear(source.rgb);
	float luminance = dot(linear, LUMA);

	// The boundaries cannot pass each other. Highlights beginning below where the
	// shadows end leaves no midtone band anywhere in the picture, and a wheel
	// labelled Midtones that cannot do anything is worse than a slider that stops
	// moving. It is also what keeps the two ramps DISJOINT, which is why the
	// weights below need no renormalising to sum to one.
	float highStart = max(uHighStart, uShadowEnd);

	// Three overlapping weights that SUM TO ONE at every luminance. Midtones are
	// whatever the other two are not, which is what keeps the ranges from adding up
	// to a double correction where they meet - the usual failure of three
	// independently-windowed wheels.
	float shadowW = 1.0 - smoothstep(uShadowEnd - max(uShadowFalloff, 0.02), uShadowEnd, luminance);
	float highW = smoothstep(highStart, highStart + max(uHighFalloff, 0.02), luminance);
	float midW = max(1.0 - shadowW - highW, 0.0);

	vec3 gain = balanceGain(uShadowRC, uShadowGM) * shadowW +
	            balanceGain(uMidRC, uMidGM) * midW +
	            balanceGain(uHighRC, uHighGM) * highW;

	vec3 balanced = linear * gain;

	// Rescale to the luminance we started with, so a balance move changes colour and
	// only colour. Without it every wheel doubles as an exposure control and you end
	// up fighting Tone.
	float balancedLuma = dot(balanced, LUMA);
	vec3 preserved = balanced * (luminance / max(balancedLuma, 0.0001));
	balanced = mix(balanced, preserved, uPreserve);

	fragColor = vec4(mix(source.rgb, encodeFromLinear(balanced), uMix), source.a);
}
