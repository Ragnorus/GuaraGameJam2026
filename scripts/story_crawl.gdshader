shader_type canvas_item;
render_mode unshaded;

uniform float text_height = 1.0;
uniform float scroll_position = -80.0;

void fragment() {
	// Inverse perspective maps the flat story texture onto a receding plane.
	float depth_scale = mix(0.2, 1.0, UV.y);
	float distance = 560.0 * (1.0 / depth_scale - 1.0);
	vec2 source_uv = vec2(
		(UV.x - 0.5) / depth_scale + 0.5,
		(scroll_position - distance) / text_height
	);
	float inside = step(0.0, source_uv.x) * step(source_uv.x, 1.0)
		* step(0.0, source_uv.y) * step(source_uv.y, 1.0);
	vec4 story = texture(TEXTURE, clamp(source_uv, vec2(0.0), vec2(1.0)));
	story.a *= inside * smoothstep(0.0, 0.28, UV.y);
	COLOR = story;
}
