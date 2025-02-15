shader_type canvas_item;

uniform float tile_factor_x : hint_range(0.1, 10.0) = 1.0;
uniform float tile_factor_y : hint_range(0.1, 10.0) = 1.0;

void fragment() {
    vec2 tiled_uv = fract(UV * vec2(tile_factor_x, tile_factor_y));
    COLOR = texture(TEXTURE, tiled_uv);
}
