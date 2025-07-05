shader_type canvas_item;
uniform float aging_factor = 0.0;
uniform vec4 aged_color : source_color = vec4(0.4, 0.3, 0.15, 1.0);

void fragment() {
	vec4 original_color = texture(TEXTURE, UV);
	COLOR.rgb = mix(original_color.rgb, aged_color.rgb, aging_factor);
	COLOR.a = original_color.a;
}