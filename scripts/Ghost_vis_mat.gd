shader_type spatial;

render_mode blend_mix, unshaded, depth_draw_alpha_prepass;

uniform float highlight_strength : hint_range(0.0, 1.0) = 0.0; // Set from script
uniform float threshold : hint_range(0.0, 1.0) = 0.5; // When highlight_strength exceeds this, ghost becomes visible

void fragment() {
	// If the ghost is sufficiently highlighted, show it; otherwise, make it fully transparent.
	if (highlight_strength >= threshold) {
		ALPHA = 1.0;
		ALBEDO = vec3(1.0); // White ghost; change as needed.
	} else {
		ALPHA = 0.0;
	}
}
