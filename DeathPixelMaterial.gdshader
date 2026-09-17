shader_type canvas_item;

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.5;
uniform bool emission_enabled = false;
uniform vec4 emission : source_color = vec4(1.0);
uniform float emission_energy_multiplier : hint_range(0.0, 5.0) = 0.0;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    vec3 base = tex.rgb * albedo_color.rgb;
    float sweep = 1.0 - smoothstep(0.0, 0.16 + roughness * 0.5, abs(sin((UV.x + UV.y + TIME * 0.12) * 3.14159)));
    float metallic_light = sweep * metallic * 0.55;
    float sheen = pow(max(0.0, 1.0 - abs(UV.x + UV.y - 1.0)), mix(5.0, 1.5, roughness)) * metallic * 0.25;
    vec3 result = base + vec3(metallic_light + sheen);
    if (emission_enabled) {
        result += emission.rgb * emission_energy_multiplier * (0.45 + sweep * 0.55);
    }
    COLOR = vec4(result, tex.a * albedo_color.a);
}
