// src/themes/celestials_glow.gdshader
shader_type canvas_item;

// Add this line:
render_mode unshaded, blend_add;

uniform vec4 sun_color  : source_color = vec4(1.0,0.95,0.85,1.0);
uniform vec4 moon_color : source_color = vec4(0.75,0.85,1.0,1.0);

uniform float time_of_day = 0.25;
uniform float sun_size  = 90.0;
uniform float moon_size = 70.0;

// ring shaping
uniform float sun_glow_radius_mul = 1.40;
uniform float sun_halo_radius_mul = 2.20;
uniform float sun_glow_strength   = 0.35;
uniform float sun_halo_strength   = 0.18;

uniform float moon_glow_radius_mul = 1.60;
uniform float moon_glow_strength   = 0.30;

uniform vec2  viewport_size = vec2(1920.0,1080.0);
uniform vec2  cam_zoom = vec2(1.0,1.0);
uniform vec2  orbit_center = vec2(0.50, 1.10);
uniform float orbit_radius = 0.80;

// ambient compensation (fed from ThemeManager)
uniform vec3 ambient_tint = vec3(1.0);

// NEW: global alpha for the glow pass (since alpha scales the add)
uniform float glow_alpha = 0.70; // tweak 0..1

void fragment() {
    vec2 uv = UV;

    float A = (time_of_day * 6.2831853) - 1.5707963;
    vec2 sun_pos  = orbit_center + vec2(cos(A),             -sin(A))           * orbit_radius;
    vec2 moon_pos = orbit_center + vec2(cos(A+3.1415926),   -sin(A+3.1415926)) * orbit_radius;

    float z = cam_zoom.x;
    float size_mul = 1.0 - 0.15 * max(0.0, 1.0 - z);

    float aspect = viewport_size.x / viewport_size.y;
    vec2 ds = uv - sun_pos;  ds.x *= aspect;
    vec2 dm = uv - moon_pos; dm.x *= aspect;

    float rs = (sun_size  / 400.0) * size_mul;
    float rm = (moon_size / 400.0) * size_mul;

    float d_s = length(ds);
    float d_m = length(dm);

    float sun_glow = 1.0 - smoothstep(rs,                     rs*sun_glow_radius_mul, d_s);
    float sun_halo = 1.0 - smoothstep(rs*sun_glow_radius_mul, rs*sun_halo_radius_mul, d_s);
    // remove core
    sun_glow = max(sun_glow - (1.0 - smoothstep(rs*0.85, rs, d_s)), 0.0);

    float moon_glow = 1.0 - smoothstep(rm, rm*moon_glow_radius_mul, d_m);
    moon_glow = max(moon_glow - (1.0 - smoothstep(rm*0.85, rm, d_m)), 0.0);

    float altitude = sin(A);
    float sun_vis  = smoothstep(-0.04, 0.10,  altitude);
    float moon_vis = smoothstep(-0.04, 0.10, -altitude) * (1.0 - sun_vis*0.95);

    vec3 add_pre =
        sun_color.rgb  * (sun_glow * sun_glow_strength + sun_halo * sun_halo_strength) * sun_vis +
        moon_color.rgb * (moon_glow * moon_glow_strength) * moon_vis;

    // Compensate CanvasModulate
    vec3 denom = max(ambient_tint, vec3(0.001));
    vec3 add = clamp(add_pre / denom, 0.0, 1.0);

    // Alpha MUST be > 0 with blend_add
    COLOR = vec4(add, glow_alpha);
}
