// src/themes/shaders/terrain_lighting.gdshader
shader_type canvas_item;

// --- Celestials ---
uniform vec2 sun_pos_uv;   
uniform vec2 moon_pos_uv;
uniform vec4 sun_color : source_color;
uniform vec4 moon_color : source_color;
uniform float sun_vis; 
uniform float moon_vis;

// --- Atmosphere (Global Glow) ---
uniform float rim_width : hint_range(0.0, 4.0) = 2.5; 
uniform float rim_intensity : hint_range(0.0, 2.0) = 0.3; 
uniform float falloff_curve : hint_range(0.1, 3.0) = 0.5;
uniform float screen_aspect = 1.77; 

// --- Surface Edge (Top Down Glow) ---
// How far down the hill the light radiates (0.0 = top only, 1.0 = bottom)
uniform float surface_edge_size : hint_range(0.0, 1.0) = 0.3;
// How bright the edge is
uniform float surface_edge_intensity : hint_range(0.0, 5.0) = 0.8;

// --- Dithering ---
uniform float dither_strength : hint_range(0.0, 0.02) = 0.008;

float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
    vec4 base_color = COLOR;
    
    // --- 1. Atmosphere Calculation (Screen Space) ---
    vec2 uv_corrected = vec2(SCREEN_UV.x * screen_aspect, SCREEN_UV.y);
    vec2 sun_corrected = vec2(sun_pos_uv.x * screen_aspect, sun_pos_uv.y);
    vec2 moon_corrected = vec2(moon_pos_uv.x * screen_aspect, moon_pos_uv.y);

    float dist_sun = distance(uv_corrected, sun_corrected);
    float dist_moon = distance(uv_corrected, moon_corrected);

    float sun_atmos = clamp(1.0 - (dist_sun / rim_width), 0.0, 1.0);
    float moon_atmos = clamp(1.0 - (dist_moon / rim_width), 0.0, 1.0);

    sun_atmos = pow(sun_atmos, falloff_curve);
    moon_atmos = pow(moon_atmos, falloff_curve);

    // --- 2. Surface Edge Calculation (UV Space) ---
    // UV.y is 0.0 at the top, 1.0 at the bottom.
    // We invert it so 1.0 is at the top.
    float vertical_gradient = 1.0 - UV.y;
    
    // Create a gradient that is white at the top and fades out by 'surface_edge_size'
    // smoothstep(min, max, value) -> returns 0 if value < min, 1 if value > max
    float edge_glow = smoothstep(1.0 - surface_edge_size, 1.0, vertical_gradient);
    
    // Optional: Square it to make the falloff softer
    edge_glow = pow(edge_glow, 2.0);

    // --- 3. Combine Lights ---
    vec3 light = vec3(0.0);
    
    // Add Atmosphere
    light += sun_color.rgb * sun_atmos * sun_vis * rim_intensity;
    light += moon_color.rgb * moon_atmos * moon_vis * rim_intensity;
    
    // Add Surface Edge (Multiplied by sun visibility so it disappears at night/if sun is gone)
    // We also multiply by sun_atmos slightly so the edge glows more when closer to the sun
    float sun_proximity_factor = 0.5 + (0.5 * sun_atmos); // Always have at least 50% edge glow, more near sun
    light += sun_color.rgb * edge_glow * sun_vis * surface_edge_intensity * sun_proximity_factor;
    
    // Add Moon Edge
    float moon_proximity_factor = 0.5 + (0.5 * moon_atmos);
    light += moon_color.rgb * edge_glow * moon_vis * surface_edge_intensity * moon_proximity_factor;

    // --- 4. Dithering ---
    float noise = (random(FRAGCOORD.xy) - 0.5) * dither_strength;
    light += noise;

    // --- 5. Apply ---
    vec3 final_rgb = base_color.rgb + (light * base_color.a);
    COLOR = vec4(final_rgb, base_color.a);
}