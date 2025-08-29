shader_type spatial;

uniform vec4 highlight_color : source_color = vec4(0.0, 0.75, 1.0, 1.0); // Leuchtendes Blau als Standard
uniform float fresnel_power : hint_range(0.1, 5.0) = 1.5;

void fragment() {
    float fresnel = pow(1.0 - dot(NORMAL, VIEW), fresnel_power);
    ALBEDO = highlight_color.rgb;
    ALPHA = fresnel;
}