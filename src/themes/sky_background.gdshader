// src/themes/sky_background.gdshader
shader_type canvas_item;

uniform vec4 sky_top    : source_color = vec4(0.25,0.45,0.95,1.0);
uniform vec4 sky_bottom : source_color = vec4(0.85,0.92,1.0,1.0);
uniform float horizon_curve = 0.35;

void fragment() {
    float h = pow(1.0 - UV.y, clamp(horizon_curve, 0.0, 1.0));
    vec3 col = mix(sky_bottom.rgb, sky_top.rgb, h);
    COLOR = vec4(col, 1.0);
}
