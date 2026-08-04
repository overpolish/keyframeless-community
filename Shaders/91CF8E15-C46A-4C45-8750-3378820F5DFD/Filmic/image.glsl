// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template filter

// #alpha
// #color-surface ring=light xaxis="Open,Deep" yaxis="Clipped,Rolled"

// #percent label="Highlight Rolloff" group={"Highlights", "sun.max"} min=0 max=100 default=40 surface="y:+30"
uniform float uRolloff;

// #float label="Recover" group={"Highlights", "sun.max"} units="×" min=1 slidermax=8 default=2
uniform float uRecover;

// The knee is a level of light, not a code value, so the eyedropper reads it
// after the decode: click the brightest thing that must stay untouched and the
// shoulder starts above it. Toe Knee is the same kind of number but stays off
// the eyedropper, because one click writes every subscriber at once and a
// highlight sample would drag the shadow threshold up with it.
// #percent label="Knee" group={"Highlights", "sun.max"} min=20 max=95 default=70 pick=luma-linear
uniform float uKnee;

// #percent label="Shadow Toe" group={"Shadows", "moon"} min=0 max=100 default=25 surface="x:+25"
uniform float uToe;

// #percent label="Toe Knee" group={"Shadows", "moon"} min=2 max=50 default=18
uniform float uToeKnee;

// #percent label="Mix" group={"Finish", "switch.2"} min=0 max=100 default=100
uniform float uMix;

// The shoulder: everything from the knee up to Recover is folded into the space
// between the knee and white, approaching white without ever reaching it.
//
// Exponential rather than a clamp or a smoothstep, because it has no end: whatever
// Tone pushed up there lands somewhere below white instead of piling onto a single
// clipped value. That pile-up is what a blown highlight IS - detail flattened into
// one number - and no later control can get it back.
float shoulder(float x, float knee, float recover)
{
	if (x <= knee) return x;
	float span = max(recover - knee, 0.0001);
	return knee + (1.0 - knee) * (1.0 - exp(-(x - knee) / span));
}

// The toe, mirrored in intent but not in shape: a power on the shadows alone, which
// steepens the ramp out of black. Anchored at its own knee so the mids the rest of
// the grade was judged on do not move.
float toe(float x, float knee, float strength)
{
	if (strength <= 0.0 || x >= knee) return x;
	return knee * pow(max(x, 0.0) / knee, 1.0 + strength * 1.2);
}

void mirageFilterImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;
	vec4 source = texture(iChannel0, uv);

	vec3 linear = decodeToLinear(source.rgb);

	// At zero rolloff the knee sits at white, so nothing below white is touched and
	// the control is a true identity rather than a very gentle curve.
	float knee = mix(1.0, uKnee, uRolloff);
	float recover = max(uRecover, knee + 0.01);

	// Per channel, not on luminance. A channel that clips alone is what turns a
	// warm highlight magenta, and rolling each one separately lets the brightest
	// parts desaturate toward white the way film does, instead of holding a
	// saturated colour right up to the clip and then breaking.
	vec3 graded = vec3(shoulder(linear.r, knee, recover),
	                   shoulder(linear.g, knee, recover),
	                   shoulder(linear.b, knee, recover));

	graded = vec3(toe(graded.r, uToeKnee, uToe),
	              toe(graded.g, uToeKnee, uToe),
	              toe(graded.b, uToeKnee, uToe));

	fragColor = vec4(mix(source.rgb, encodeFromLinear(graded), uMix), source.a);
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
