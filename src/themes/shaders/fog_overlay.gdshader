// src/themes/fog_overlay.gdshader
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture;

uniform vec4 fog_color : source_color = vec4(1.0,1.0,1.0,0.0);
uniform float band_height = 160.0;
uniform float time_of_day = 0.0;

void fragment(){
	vec4 src = texture(SCREEN_TEXTURE, SCREEN_UV);

	// simple band rising from bottom; alpha controls strength
	float y = (1.0 - SCREEN_UV.y) * (band_height / 160.0);
	float a = clamp(y * fog_color.a, 0.0, 1.0);

	vec3 col = mix(src.rgb, fog_color.rgb, a);
	COLOR = vec4(col, src.a);
}
