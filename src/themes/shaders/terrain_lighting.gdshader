// src/themes/shaders/terrain_lighting.gdshader
shader_type canvas_item;

// Celestials data (Same as cloud shader)
uniform vec2 sun_pos_uv;   // We will pass SCREEN coordinates here (0.0 to 1.0)
uniform vec2 moon_pos_uv;
uniform vec4 sun_color : source_color;
uniform vec4 moon_color : source_color;
uniform float sun_vis; 
uniform float moon_vis;

// Tuning
uniform float rim_width : hint_range(0.0, 1.0) = 0.4;
uniform float rim_intensity : hint_range(0.0, 5.0) = 1.5;

// Aspect ratio correction (passed from ThemeManager)
uniform float screen_aspect = 1.77; 

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    
    // 1. Calculate distance in SCREEN space (so the light stays fixed in the sky)
    // We adjust X by aspect ratio so the glow is circular, not oval.
    vec2 uv_corrected = vec2(SCREEN_UV.x * screen_aspect, SCREEN_UV.y);
    vec2 sun_corrected = vec2(sun_pos_uv.x * screen_aspect, sun_pos_uv.y);
    vec2 moon_corrected = vec2(moon_pos_uv.x * screen_aspect, moon_pos_uv.y);

    float dist_to_sun = distance(uv_corrected, sun_corrected);
    float dist_to_moon = distance(uv_corrected, moon_corrected);

    // 2. Calculate Light Strength (Glow)
    // Invert distance so closer = brighter
    float sun_glow = smoothstep(rim_width, 0.0, dist_to_sun);
    float moon_glow = smoothstep(rim_width, 0.0, dist_to_moon);

    // 3. Combine Light
    vec3 light_color = sun_color.rgb * sun_glow * sun_vis;
    light_color += moon_color.rgb * moon_glow * moon_vis;
    light_color *= rim_intensity;

    // 4. Apply to Texture
    // We Add the light (Screen/Add mode) to simulate backlighting/glare
    // We multiply by tex_color.a so we don't light up the empty space outside the polygon
    vec3 final_rgb = tex_color.rgb + (light_color * tex_color.a);
    
    COLOR = vec4(final_rgb, tex_color.a);
}