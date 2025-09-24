// src/themes/palette_grade.gdshader
shader_type canvas_item;
render_mode unshaded;

// Declare screen texture in Godot 4.x:
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture;

// Palette (a 1D or small 2D ramp texture)
uniform sampler2D palette_tex : source_color;
uniform float amount = 0.4;      // set to 0.0 in script if no palette
uniform float time_of_day = 0.0; // optional subtle modulation

vec3 grade(vec3 c){
	// If amount is ~0, skip grading (avoids needing textureSize checks)
	if (amount <= 0.0001) return c;

	// Assume palette is a horizontal ramp (e.g., 256x1)
	float l = clamp((c.r + c.g + c.b) / 3.0, 0.0, 1.0);
	vec3 p = texture(palette_tex, vec2(l, 0.5)).rgb;
	return mix(c, p, amount);
}

void fragment(){
	vec4 src = texture(SCREEN_TEXTURE, SCREEN_UV);
	vec3 g = grade(src.rgb);
	COLOR = vec4(g, src.a);
}
