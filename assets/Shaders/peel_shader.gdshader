shader_type canvas_item;
uniform vec2 hit_points[64];
uniform int hit_count = 0;
uniform float peel_radius = 0.5;

void fragment() {
    vec4 original_color = texture(TEXTURE, UV);
    float alpha = original_color.a;
    for (int i = 0; i < hit_count; i++) {
        if (distance(UV, hit_points[i]) < peel_radius) {
            alpha = 0.0;
            break;
        }
    }
    COLOR = vec4(original_color.rgb, alpha);
}