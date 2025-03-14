shader_type spatial;
render_mode blend_mix, ambient_light_disabled, depth_prepass_alpha;

// Define uniforms to hold custom textures
uniform sampler2D albedo_texture : source_color, filter_linear;
uniform float noise_intensity : hint_range(0.0, 2.0) = 1.0;

// Base noise scale and warp limits
const float base_max_noise_scale = 8.0;
const float base_min_noise_scale = 2.0;
const float base_max_noise_warp = 10.0;
const float base_min_noise_warp = 4.0;

// Fluctuation amount (adjustable)
const float scale_fluctuation = 0.8;
const float warp_fluctuation = 1.5;

// Function to interpolate values inversely with added instability
float unstable_lerp(float min_val, float max_val, float t, vec2 uv, float fluctuation) {
    float noise_offset = sin(uv.x * 10.0 + uv.y * 15.0 + TIME * 2.0) * fluctuation; // Adds an unstable variation
    return mix(max_val + noise_offset, min_val + noise_offset, t);
}

// Cellular Noise Function (for smoother gradients)
float cellular_noise(vec2 uv, float scale) {
    uv *= scale; // Apply dynamically adjusted scale

    vec2 p0 = floor(uv);
    vec2 p1 = p0 + vec2(1.0, 0.0);
    vec2 p2 = p0 + vec2(0.0, 1.0);
    vec2 p3 = p0 + vec2(1.0, 1.0);

    float d0 = length(uv - p0);
    float d1 = length(uv - p1);
    float d2 = length(uv - p2);
    float d3 = length(uv - p3);

    return min(min(d0, d1), min(d2, d3)); // Return closest cell distance
}

// Smoothed Wavy Noise Function with Warp (better for gradients)
float perlin_like_noise(vec2 uv) {
    // Adjust min/max scale and warp with dynamic fluctuation
    float min_noise_scale = base_min_noise_scale + sin(TIME) * scale_fluctuation;
    float max_noise_scale = base_max_noise_scale + cos(TIME * 1.2) * scale_fluctuation;
    float min_noise_warp = base_min_noise_warp + sin(TIME * 1.5) * warp_fluctuation;
    float max_noise_warp = base_max_noise_warp + cos(TIME * 1.7) * warp_fluctuation;

    // Apply inverse interpolation with fluctuation
    float noise_scale = unstable_lerp(min_noise_scale, max_noise_scale, noise_intensity, uv, scale_fluctuation);
    float noise_warp = unstable_lerp(min_noise_warp, max_noise_warp, noise_intensity, uv, warp_fluctuation);

    // Apply warp distortion
    uv.x += sin(uv.y * noise_warp) * 0.5;
    uv.y += cos(uv.x * noise_warp) * 0.5;

    return cellular_noise(uv, noise_scale);
}

void fragment() {
    vec4 albedo_tex = texture(albedo_texture, UV);
    ALPHA = 0.0; // Start fully transparent
}

void light() {
    float noise_value = perlin_like_noise(UV);
    float NdotL = max(dot(NORMAL, LIGHT), 0.0);
    vec3 lightColor = LIGHT_COLOR.rgb * ATTENUATION;
    DIFFUSE_LIGHT += ALBEDO * lightColor * NdotL;

    float illum = NdotL * (ATTENUATION / 3.0);
    float alpha_noise = smoothstep(0.2, 0.8, noise_value * noise_intensity);
    
    ALPHA = clamp(ALPHA + illum * alpha_noise, 0.0, 1.0);
}
