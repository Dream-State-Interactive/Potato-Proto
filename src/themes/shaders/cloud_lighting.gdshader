// src/themes/cloud_lighting.gdshader
shader_type canvas_item;

// Celestials data, passed in from ThemeManager
uniform vec2 sun_pos_uv;
uniform vec2 moon_pos_uv;
uniform vec4 sun_color : source_color;
uniform vec4 moon_color : source_color;
uniform float sun_vis; // 0.0 to 1.0 visibility
uniform float moon_vis; // 0.0 to 1.0 visibility

// Tuning parameters for the lighting effect
uniform float rim_width : hint_range(0.0, 0.5) = 0.15;
uniform float rim_blur : hint_range(0.0, 0.5) = 0.2;
uniform float rim_intensity : hint_range(0.0, 5.0) = 2.0;

void fragment() {
    // Get the base color and alpha from the cloud texture
    vec4 tex_color = texture(TEXTURE, UV);

    // --- Wrapped Distance Calculation for Repeating Textures ---
    // This calculates the shortest distance, wrapping around the 0.0-1.0 UV space.
    vec2 sun_diff = abs(UV - sun_pos_uv);
    vec2 wrapped_sun_diff = min(sun_diff, 1.0 - sun_diff);
    float dist_to_sun = length(wrapped_sun_diff);

    vec2 moon_diff = abs(UV - moon_pos_uv);
    vec2 wrapped_moon_diff = min(moon_diff, 1.0 - moon_diff);
    float dist_to_moon = length(wrapped_moon_diff);

    // --- Original light strength calculation (creates a spotlight shape) ---
    float sun_light_strength = smoothstep(rim_width + rim_blur, rim_width, dist_to_sun);
    float moon_light_strength = smoothstep(rim_width + rim_blur, rim_width, dist_to_moon);

    // --- Edge Masking ---
    // Create a mask that is only visible on the semi-transparent edges of the cloud.
    // The formula (a * (1-a)) peaks when alpha is 0.5 (the softest edge).
    // The multiplier of 4.0 boosts this peak to a value of 1.0.
    float edge_mask = tex_color.a * (1.0 - tex_color.a) * 4.0;

    // --- Combine everything ---
    // Start with the base light from each celestial
    vec3 rim_light = sun_color.rgb * sun_light_strength * sun_vis;
    rim_light += moon_color.rgb * moon_light_strength * moon_vis;
    
    // Apply the intensity and, crucially, the edge mask
    rim_light *= rim_intensity * edge_mask;

    // Add the final, masked light to the original texture color
    vec3 final_color = tex_color.rgb + rim_light;
    
    COLOR = vec4(final_color, tex_color.a);
}