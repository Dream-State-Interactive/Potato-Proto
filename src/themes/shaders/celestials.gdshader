// src/themes/celestials.gdshader
shader_type canvas_item;

uniform vec4 sun_color  : source_color = vec4(1.0,0.95,0.85,1.0);
uniform vec4 moon_color : source_color = vec4(0.75,0.85,1.0,1.0);

uniform float time_of_day = 0.25;
uniform float sun_size  = 90.0;
uniform float moon_size = 70.0;

uniform float sun_core_softness  = 0.10; // 0..0.5
uniform float moon_core_softness = 0.06; // 0..0.5

uniform vec2  viewport_size = vec2(1920.0,1080.0);
uniform vec2  cam_zoom = vec2(1.0,1.0);
uniform vec2  orbit_center = vec2(0.50, 1.10);
uniform float orbit_radius = 0.80;

/* NEW: the current CanvasModulate RGB so we can compensate it */
uniform vec3 ambient_tint = vec3(1.0); // set from ThemeManager

void fragment() {
    vec2 uv = UV;

    float A = (time_of_day * 6.2831853) - 1.5707963;
    vec2 sun_pos  = orbit_center + vec2(cos(A),             -sin(A))           * orbit_radius;
    vec2 moon_pos = orbit_center + vec2(cos(A+3.1415926),   -sin(A+3.1415926)) * orbit_radius;

    float z = cam_zoom.x;
    float size_mul = 1.0 - 0.15 * max(0.0, 1.0 - z);

    float aspect = viewport_size.x / viewport_size.y;
    vec2 ds = uv - sun_pos;  ds.x  *= aspect;
    vec2 dm = uv - moon_pos; dm.x  *= aspect;

    float rs = (sun_size  / 400.0) * size_mul;
    float rm = (moon_size / 400.0) * size_mul;

    float d_s = length(ds);
    float d_m = length(dm);

    float sun_core  = 1.0 - smoothstep(rs*(1.0 - sun_core_softness),  rs, d_s);
    float moon_core = 1.0 - smoothstep(rm*(1.0 - moon_core_softness), rm, d_m);

    // Hand-off with a tiny overlap so neither vanishes on the horizon
    float altitude = sin(A);
    float sun_vis  = smoothstep(-0.04, 0.10,  altitude);
    float moon_vis = smoothstep(-0.04, 0.10, -altitude) * (1.0 - sun_vis*0.95);

    // Pre-tint color (what you WANT to see)
    vec3 col_pre = vec3(0.0);
    col_pre = mix(col_pre, sun_color.rgb,  sun_core  * sun_vis);
    col_pre = mix(col_pre, moon_color.rgb, moon_core * moon_vis);

    // Compensate CanvasModulate so whites stay white at night
    vec3 denom = max(ambient_tint, vec3(0.001));
    vec3 col = clamp(col_pre / denom, 0.0, 1.0);

    float a = max(sun_core * sun_vis, moon_core * moon_vis);
    COLOR = vec4(col, a);
}
