// src/themes/sky_background.gdshader
shader_type canvas_item;

// NEW theme colors
uniform vec4 sky_top    : source_color = vec4(0.25,0.45,0.95,1.0);
uniform vec4 sky_bottom : source_color = vec4(0.85,0.92,1.0,1.0);
uniform float horizon_curve = 0.35;

// OLD theme colors (for transitions)
uniform vec4 sky_top_old    : source_color = vec4(0.25,0.45,0.95,1.0);
uniform vec4 sky_bottom_old : source_color = vec4(0.85,0.92,1.0,1.0);
uniform float horizon_curve_old = 0.35;

// Blend factor for the transition
uniform float transition_blend : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    // Interpolate between old and new theme values
    vec4 final_sky_top = mix(sky_top_old, sky_top, transition_blend);
    vec4 final_sky_bottom = mix(sky_bottom_old, sky_bottom, transition_blend);
    float final_horizon_curve = mix(horizon_curve_old, horizon_curve, transition_blend);

    // Original drawing logic
    float h = pow(1.0 - UV.y, clamp(final_horizon_curve, 0.0, 1.0));
    vec3 col = mix(final_sky_bottom.rgb, final_sky_top.rgb, h);
    COLOR = vec4(col, 1.0);
}