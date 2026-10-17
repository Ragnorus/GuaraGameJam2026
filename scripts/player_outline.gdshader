shader_type canvas_item;
render_mode unshaded;

uniform vec4 frame_uv;
uniform vec4 outline_color : source_color = vec4(1.0, 0.85, 0.48, 0.95);
varying vec4 sprite_modulate;

void vertex() {
	sprite_modulate = COLOR;
}

float inside_frame(vec2 uv) {
	return step(frame_uv.x, uv.x) * step(frame_uv.y, uv.y)
		* step(uv.x, frame_uv.z) * step(uv.y, frame_uv.w);
}

void fragment() {
	vec4 original = texture(TEXTURE, UV);
	float edge = 0.0;
	float halo = 0.0;
	for (int i = 0; i < 8; i++) {
		float angle = float(i) * 0.785398163;
		vec2 direction = vec2(cos(angle), sin(angle)) * TEXTURE_PIXEL_SIZE;
		vec2 edge_uv = UV + direction * 3.0;
		vec2 halo_uv = UV + direction * 7.0;
		edge = max(edge, texture(TEXTURE, clamp(edge_uv, frame_uv.xy, frame_uv.zw)).a * inside_frame(edge_uv));
		halo = max(halo, texture(TEXTURE, clamp(halo_uv, frame_uv.xy, frame_uv.zw)).a * inside_frame(halo_uv));
	}
	float outline_alpha = max(edge * outline_color.a, halo * 0.18) * (1.0 - original.a);
	float alpha = original.a + outline_alpha;
	vec3 color = (original.rgb * original.a + outline_color.rgb * outline_alpha) / max(alpha, 0.0001);
	COLOR = vec4(color, alpha) * sprite_modulate;
}
