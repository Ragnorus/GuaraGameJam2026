shader_type canvas_item;
render_mode unshaded;

uniform sampler2D left_texture : source_color, filter_linear;
uniform sampler2D right_texture : source_color, filter_linear;
uniform vec2 transition_origin;
uniform vec2 transition_size;
uniform vec2 left_origin;
uniform vec2 right_origin;
uniform vec2 left_texture_size;
uniform vec2 right_texture_size;
uniform float left_scale;
uniform float right_scale;

void fragment() {
	vec2 world_position = transition_origin + UV * transition_size;
	vec2 left_uv = (world_position - left_origin) / (left_texture_size * left_scale);
	vec2 right_uv = (world_position - right_origin) / (right_texture_size * right_scale);
	vec4 left_color = texture(left_texture, clamp(left_uv, vec2(0.0), vec2(1.0)));
	vec4 right_color = texture(right_texture, clamp(right_uv, vec2(0.0), vec2(1.0)));
	COLOR = mix(left_color, right_color, smoothstep(0.0, 1.0, UV.x));
}
