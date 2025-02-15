shader_type canvas_item;

// This uniform is controlled solely by auto-scroll.
uniform float uv_offset_x : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    // Only shift the U coordinate based on the auto-scroll offset.
    vec2 shifted_uv = vec2(fract(UV.x + uv_offset_x), UV.y);
    COLOR = texture(TEXTURE, shifted_uv);
}
