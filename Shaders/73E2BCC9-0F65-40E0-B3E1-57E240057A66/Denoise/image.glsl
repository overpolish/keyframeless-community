// SPDX-FileCopyrightText: 2026 overpolish
// SPDX-License-Identifier: MIT

// #template filter
// #alpha
// #frames offsets="-2,-1,+1,+2"
// #motionblur off

// #percent label="Strength" group={"Denoise", "camera.filters"} min=0 max=150 slidermax=100 default=70
uniform float uStrength;

// Chroma tolerates far more averaging than luma does: colour noise is the ugly
// blotchy kind, the eye reads colour at a fraction of the resolution it reads
// brightness at, and the codec already threw most of the chroma away. So this
// starts at full while luma sits at 70 - that asymmetry IS the look of a good
// denoise, and running them off one slider is what makes cheap NR go plastic.
// #percent label="Chroma Strength" group={"Denoise", "camera.filters"} min=0 max=150 slidermax=100 default=100
uniform float uChromaStrength;

// How big a frame-to-frame difference still counts as noise rather than as
// something that moved. Too low and heavy grain reads as motion and nothing is
// averaged; too high and small real changes are averaged away. It is a size,
// not an amount, which is why it is its own control and not part of Strength.
// #percent label="Noise Size" group={"Denoise", "camera.filters"} min=0 max=200 slidermax=100 default=40
uniform float uNoiseSize;

// Off samples each neighbour where the pixel already is. Fine searches a 3x3
// window around it for the best match first, so a panning shot still denoises
// instead of being rejected wholesale by the motion gate. Fine costs about 6.5x
// the texture reads (see the tap budget below) - it is the export setting.
// #choice label="Tracking" group={"Denoise", "camera.filters"} options="Off,Fine" default=1
uniform int uTracking;

// #percent label="Spatial" group={"Denoise", "camera.filters"} min=0 max=150 slidermax=100 default=35
uniform float uSpatial;

// Panel-owned session state, not a parameter: no inspector row, no keyframes,
// nothing stored. It rides the preview row beside Before and Split under the M
// shortcut, which every template has whether or not it declares a colour
// surface, and because the default is false the diagnostic can never reach a
// render or a reopened project.
// #bool label="Show Noise" group={"Finish", "switch.2"} default=false preview=selection
uniform bool uShowNoise;

// #percent label="Mix" group={"Finish", "switch.2"} min=0 max=100 default=100
uniform float uMix;

// TAP BUDGET, per pixel, counted honestly:
//
//   Tracking Off   9 + 4 x 5        =  29 texture reads
//   Tracking Fine  9 + 4 x (9 x 5)  = 189 texture reads
//
// The 9 is the current frame's 3x3 box, read once and used twice: its first
// five entries are the cross patch every match is scored on, and all nine are
// the spatial fallback's kernel. Off evaluates one candidate position per
// neighbour, so its search genuinely costs nothing. Fine evaluates nine, and
// the best candidate's centre tap IS the colour that gets blended, so tracking
// never pays for a re-sample afterwards.

// Centre first, then the four edge-adjacent, then the four diagonals. One array
// does three jobs: the search pattern, the cross patch (the first five), and
// the 3x3 box (all nine). Centre-first is also what lets the search penalty
// below make standing still win a tie.
const vec2 kOffsets[9] = vec2[9](vec2(0.0, 0.0), vec2(1.0, 0.0), vec2(-1.0, 0.0),
                                 vec2(0.0, 1.0), vec2(0.0, -1.0), vec2(1.0, 1.0),
                                 vec2(-1.0, 1.0), vec2(1.0, -1.0), vec2(-1.0, -1.0));

const vec3 kLumaWeights = vec3(0.2126, 0.7152, 0.0722);

float lumaOf(vec3 c)
{
	return dot(c, kLumaWeights);
}

// WHY THE BLEND HAPPENS ON ENCODED VALUES, NOT LINEAR LIGHT.
//
// The neighbours arrive in exactly the encoding iChannel0 is in - display-coded
// - and they stay that way here. Three reasons, in order of weight:
//
// 1. Noise is roughly even across the tonal range in the encoded domain and
//    wildly uneven in linear. Shot noise grows with the square root of the
//    light, and the camera's transfer curve is very nearly the transform that
//    flattens that back out, which is why grain looks the same in a face and in
//    a wall. So ONE threshold works everywhere here. In linear the same number
//    is enormous in the shadows and invisible in the highlights, and the
//    control would need a per-stop curve to mean anything.
// 2. The gate compares a difference against that threshold, so both sides have
//    to be in the same domain. Decode one and the control stops being a size.
// 3. 189 decodes and one re-encode per pixel is not a rounding error at 4K.
//
// The tradeoff, stated plainly: averaging encoded values is not an
// energy-correct average, so a blend across a hard luminance transition lands
// slightly dark of the true linear mean. That only bites where the frames
// genuinely differ across a hard edge - which is precisely where the gate has
// already driven the weight to zero, so the case the error would show up in is
// the case that never blends. Every practical TNR makes this trade.

// WHY REC.709 LUMA + COLOUR DIFFERENCE, NOT OKLAB.
//
// The split is not being used to measure how different two colours look - it is
// being used to denoise brightness and colour at different rates. Luma plus
// `rgb - luma` does exactly that, is an exact round trip (adding the luma back
// returns the original), costs a dot product, and matches the space the noise
// was created and subsampled in. Oklab would want a linearisation and a cube
// root on every one of those 189 taps to buy perceptual uniformity that no
// decision here asks for.
vec3 chromaOf(vec3 c, float y)
{
	return c - y;
}

// The motion gate. Half weight exactly at the threshold, and EXACTLY zero past
// 3.5x it rather than a small tail: a neighbour that cannot be matched must
// contribute nothing at all, because a ghost at 2% is still a ghost and it is
// the one artefact that makes a denoiser unusable. The falloff between is
// smooth, so a pixel drifting in and out of the gate fades rather than flicks.
float gateWeight(float sad, float thresh)
{
	float x = sad / max(thresh, 1e-5);
	return exp2(-x * x) * (1.0 - smoothstep(2.0, 3.5, x));
}

// Find where this neighbour's copy of the pixel actually is, and report how well
// it matched. The score is a mean absolute luma difference over the 5-tap cross
// patch: a patch rather than the single pixel because a single-pixel comparison
// on noisy footage is measuring the noise, and luma rather than RGB because
// chroma is the noisiest channel and would dominate a decision that is about
// geometry.
vec3 alignNeighbor(int idx, vec2 uv, vec2 texel, float curY[5], int candidates,
                   out float bestSad)
{
	bestSad = 1.0;
	float bestScore = 1e9;
	vec3 bestColor = vec3(0.0);

	for (int k = 0; k < candidates; k++)
	{
		vec2 d = kOffsets[k] * texel;
		vec3 center = iNeighborAt(idx, uv + d).rgb;
		float sad = abs(lumaOf(center) - curY[0]);
		for (int t = 1; t < 5; t++)
			sad += abs(lumaOf(iNeighborAt(idx, uv + d + kOffsets[t] * texel).rgb) - curY[t]);
		sad *= 0.2;

		// The best of nine noisy measurements is biased low - pick the minimum
		// of anything random and you get less than its average. Unpenalised,
		// the search therefore "finds a match" everywhere, correlates each
		// neighbour's noise with this pixel's, and quietly costs the blend some
		// of the averaging it was there for. Measured on a still noisy scene at
		// full Strength: an unpenalised search leaves 0.56x the noise, 0.25 per
		// pixel of travel leaves 0.48x, and not searching at all leaves 0.46x.
		// A real 1px shift still wins with 0.25 in the way (over 91% of taps
		// find it, horizontally and diagonally), because a genuine match is not
		// 25% better, it is several times better. The GATE sees the UNPENALISED
		// number, so the penalty biases where to look and never what to trust.
		float score = sad * (1.0 + 0.25 * (abs(kOffsets[k].x) + abs(kOffsets[k].y)));
		if (score < bestScore)
		{
			bestScore = score;
			bestSad = sad;
			bestColor = center;
		}
	}
	return bestColor;
}

void mirageFilterImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 uv = fragCoord / iResolution.xy;
	vec2 texel = 1.0 / iResolution.xy;

	vec4 src = texture(iChannel0, uv);

	vec3 box[9];
	box[0] = src.rgb;
	for (int k = 1; k < 9; k++)
		box[k] = texture(iChannel0, uv + kOffsets[k] * texel).rgb;

	float curY[5];
	for (int t = 0; t < 5; t++)
		curY[t] = lumaOf(box[t]);

	vec3 source = box[0];
	float sourceY = curY[0];
	vec3 sourceC = chromaOf(source, sourceY);

	// One candidate is the pixel where it already is, so Tracking Off spends
	// nothing on the search rather than searching a window of size one.
	int candidates = (uTracking == 1) ? 9 : 1;

	float sad[iNeighborCount];
	vec3 matched[iNeighborCount];
	float minSad = 1.0;

	for (int i = 0; i < iNeighborCount; i++)
	{
		float s;
		matched[i] = alignNeighbor(i, uv, texel, curY, candidates, s);
		sad[i] = s;
		minSad = min(minSad, s);
	}

	// The threshold is the user's Noise Size scaled by a LOCAL noise estimate,
	// and the estimate is the smallest patch difference any neighbour achieved.
	//
	// Why that and not the local variance of this frame: variance cannot tell
	// noise from texture. Gravel, foliage and hair have huge local variance and
	// may carry no noise at all, so a variance-scaled threshold refuses to
	// denoise exactly the detailed areas where grain is most visible, and over-
	// smooths flat sky. The best temporal match is a TEMPORAL measurement -
	// over a still textured area the texture cancels between frames and what is
	// left IS the noise floor.
	//
	// The estimate is CLAMPED to the authored size, which is the no-ghosting
	// guarantee: in a moving region every neighbour mismatches badly, so an
	// unclamped estimate would be huge, the threshold would open to swallow it,
	// and the shader would cheerfully average two different pictures together.
	// Clamped, the threshold can only ever range over 0.5x to 1.5x a noise-
	// sized number, so a real move is always far outside it and is always
	// weighted to zero.
	float sigma = mix(0.004, 0.06, uNoiseSize);
	float thresh = sigma * 0.5 + min(minSad, sigma);

	float wsum = 1.0;
	vec3 accum = source;
	for (int i = 0; i < iNeighborCount; i++)
	{
		float w = gateWeight(sad[i], thresh);
		wsum += w;
		accum += matched[i] * w;
	}

	vec3 mean = accum / wsum;
	float meanY = lumaOf(mean);
	vec3 meanC = chromaOf(mean, meanY);

	float outY = mix(sourceY, meanY, uStrength);
	vec3 outC = mix(sourceC, meanC, uChromaStrength);

	// How much of the available temporal evidence survived the gate. 1 means
	// every neighbour matched, 0 means none did, and the second case is exactly
	// where the temporal pass has done nothing at all.
	float confidence = (wsum - 1.0) / float(iNeighborCount);

	// Spatial fallback. Without it a moving subject keeps every bit of its grain
	// while the static background loses all of its - and grain that boils in one
	// region and not the neighbouring one is far more visible than grain
	// everywhere. This is a 3x3 edge-aware average, weighted down where a tap
	// disagrees with the centre so it blurs the noise and not the edges, and it
	// only fades in where the temporal pass gave up.
	float spatial = uSpatial * (1.0 - confidence);
	if (spatial > 0.001)
	{
		float sw = 1.0;
		vec3 sacc = source;
		for (int k = 1; k < 9; k++)
		{
			float dy = lumaOf(box[k]) - sourceY;
			// Diagonals count half: they are further away, and this is the
			// cheapest way to keep a 3x3 box from reading as a square.
			float kernel = (k < 5) ? 1.0 : 0.5;
			float w = exp2(-(dy * dy) / (2.0 * thresh * thresh)) * kernel;
			sw += w;
			sacc += box[k] * w;
		}
		vec3 sm = sacc / sw;
		float smY = lumaOf(sm);
		// Luma takes 0.6 of the amount and chroma all of it, for the same reason
		// the temporal strengths are split: a spatially blurred luma is a soft
		// picture, a spatially blurred chroma is just clean colour.
		outY = mix(outY, smY, spatial * 0.6);
		outC = mix(outC, chromaOf(sm, smY), spatial);
	}

	vec3 denoised = clamp(vec3(outY) + outC, 0.0, 1.0);
	vec3 result = mix(source, denoised, uMix);

	// Show Noise renders what was REMOVED, around mid grey, amplified 8x: a
	// one-code-value difference becomes eight and is legible on a monitor. Read
	// it as grain-only means the settings are right, and any edge or feature you
	// can recognise means detail is being taken with the noise. It is computed
	// after Mix, so pulling Mix down visibly weakens the diagnostic too.
	if (uShowNoise)
		result = clamp(0.5 + (source - result) * 8.0, 0.0, 1.0);

	fragColor = vec4(result, src.a);
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
