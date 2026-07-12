// CRT / retro TV — processes the source clip on iChannel0
vec2 curve(vec2 uv) {
    uv = uv * 2.0 - 1.0;
    vec2 off = abs(uv.yx) / vec2(6.0, 4.0);
    uv = uv + uv * off * off;          // barrel distortion
    return uv * 0.5 + 0.5;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv  = fragCoord / iResolution.xy;
    vec2 cuv = curve(uv);

    // outside the curved glass = black bezel
    if (cuv.x < 0.0 || cuv.x > 1.0 || cuv.y < 0.0 || cuv.y > 1.0) {
        fragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    // chromatic aberration: split R/B radially
    vec2 dir = cuv - 0.5;
    float ca = 0.004;
    float r = texture(iChannel0, cuv + dir * ca).r;
    float g = texture(iChannel0, cuv).g;
    float b = texture(iChannel0, cuv - dir * ca).b;
    vec3 col = vec3(r, g, b);

    // scanlines
    float scan = 0.5 + 0.5 * sin(cuv.y * iResolution.y * 3.14159);
    col *= mix(0.88, 1.0, scan);

    // rolling flicker + vignette + brightness gain
    col *= 1.0 - 0.03 * sin(iTime * 12.0 + cuv.y * 8.0);
    col *= clamp(1.0 - dot(dir, dir) * 0.45, 0.0, 1.0);
    col *= 1.18;

    fragColor = vec4(col, 1.0);
}