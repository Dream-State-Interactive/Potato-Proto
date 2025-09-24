// src/themes/sky_bodies.gdshader
shader_type canvas_item;

uniform vec4 sun_color  : source_color = vec4(1.0,0.95,0.85,1.0);
uniform vec4 moon_color : source_color = vec4(0.80,0.90,1.0,1.0);

uniform float time_of_day = 0.25;
uniform float sun_size  = 90.0;
uniform float moon_size = 70.0;

uniform float sun_core_softness  = 0.08;
uniform float sun_glow_radius_mul = 1.20;
uniform float sun_halo_radius_mul = 1.60;
uniform float sun_glow_strength   = 0.30;
uniform float sun_halo_strength   = 0.12;

uniform float moon_core_softness  = 0.05;
uniform float moon_glow_radius_mul = 1.35;
uniform float moon_glow_strength   = 0.20;

uniform vec2 viewport_size = vec2(1920.0,1080.0);
uniform vec2 cam_zoom = vec2(1.0,1.0);
uniform vec2  orbit_center = vec2(0.5, 1.20);
uniform float orbit_radius = 0.85;

void fragment() {
    float A = (time_of_day * 6.2831853) - 1.5707963;
    vec2 sun_pos  = orbit_center + vec2(cos(A),               -sin(A))               * orbit_radius;
    vec2 moon_pos = orbit_center + vec2(cos(A + 3.1415926),   -sin(A + 3.1415926))   * orbit_radius;

    float z = cam_zoom.x;
    float size_mul = 1.0 - 0.15 * max(0.0, 1.0 - z);

    float aspect = viewport_size.x / viewport_size.y;
    vec2 uv = UV;

    vec2 ds = uv - sun_pos;  ds.x  *= aspect;
    vec2 dm = uv - moon_pos; dm.x *= aspect;

    float rs = (sun_size  / 400.0) * size_mul;
    float rm = (moon_size / 400.0) * size_mul;

    float d_s = length(ds);
    float d_m = length(dm);

    float sun_core = 1.0 - smoothstep(rs*(1.0 - sun_core_softness), rs, d_s);
    float sun_glow = 1.0 - smoothstep(rs, rs*sun_glow_radius_mul, d_s);
    sun_glow = max(sun_glow - sun_core, 0.0);
    float sun_halo = 1.0 - smoothstep(rs*sun_glow_radius_mul, rs*sun_halo_radius_mul, d_s);

    float moon_core = 1.0 - smoothstep(rm*(1.0 - moon_core_softness), rm, d_m);
    float moon_glow = 1.0 - smoothstep(rm, rm*moon_glow_radius_mul, d_m);
    moon_glow = max(moon_glow - moon_core, 0.0);

    float altitude = sin(A);
    float sun_vis  = smoothstep(0.02, 0.15,  altitude);
    float moon_vis = smoothstep(0.02, 0.15, -altitude) * (1.0 - sun_vis);

    vec3 col = vec3(0.0);
    col = mix(col, sun_color.rgb,  sun_core * sun_vis);
    col += sun_color.rgb  * (sun_glow * sun_glow_strength + sun_halo * sun_halo_strength) * sun_vis;

    col = mix(col, moon_color.rgb, moon_core * moon_vis);
    col += moon_color.rgb * (moon_glow * moon_glow_strength) * moon_vis;

    // fully opaque where anything is drawn
    float a = clamp(max(max(sun_core, moon_core), max(sun_glow, max(sun_halo, moon_glow))), 0.0, 1.0);
    COLOR = vec4(col, a);
}