// Wood texture for game board
uniform sampler2D wood_texture;
uniform sampler2D wood_normal_map;
uniform sampler2D wood_roughness_map;

// Stone texture for tower bases
uniform sampler2D stone_texture;
uniform sampler2D stone_normal_map;
uniform sampler2D stone_roughness_map;

// Metal texture for decorative elements
uniform sampler2D metal_texture;
uniform sampler2D metal_normal_map;
uniform sampler2D metal_roughness_map;
uniform sampler2D metal_metallic_map;

// Leather texture for game pieces
uniform sampler2D leather_texture;
uniform sampler2D leather_normal_map;
uniform sampler2D leather_roughness_map;

void fragment() {
    vec2 uv = UV;
    
    // Base material properties
    vec3 albedo;
    vec3 normal_map;
    float roughness;
    float metallic = 0.0;
    
    // Determine which material to use based on material_type uniform
    if (MATERIAL_TYPE == 0) { // Wood
        albedo = texture(wood_texture, uv).rgb;
        normal_map = texture(wood_normal_map, uv).rgb;
        roughness = texture(wood_roughness_map, uv).r;
        
        // Add wood grain detail
        float grain = sin(uv.y * 100.0) * 0.5 + 0.5;
        albedo = mix(albedo, albedo * 0.8, grain * 0.1);
        
        // Age the wood for medieval look
        albedo = mix(albedo, vec3(0.4, 0.3, 0.2), 0.2);
        roughness = mix(roughness, 0.8, 0.3); // Weathered wood is rougher
        
    } else if (MATERIAL_TYPE == 1) { // Stone
        albedo = texture(stone_texture, uv).rgb;
        normal_map = texture(stone_normal_map, uv).rgb;
        roughness = texture(stone_roughness_map, uv).r;
        
        // Add stone wear and aging
        float wear = noise(uv * 20.0) * 0.5 + 0.5;
        albedo = mix(albedo, vec3(0.5, 0.5, 0.5), wear * 0.2);
        roughness = mix(roughness, 1.0, wear * 0.3);
        
    } else if (MATERIAL_TYPE == 2) { // Metal
        albedo = texture(metal_texture, uv).rgb;
        normal_map = texture(metal_normal_map, uv).rgb;
        roughness = texture(metal_roughness_map, uv).r;
        metallic = texture(metal_metallic_map, uv).r;
        
        // Add metal patina and tarnish for medieval look
        float tarnish = noise(uv * 15.0) * 0.5 + 0.5;
        albedo = mix(albedo, vec3(0.3, 0.4, 0.2), tarnish * 0.4); // Green patina
        roughness = mix(roughness, 0.7, tarnish * 0.5); // Tarnished metal is rougher
        metallic = mix(metallic, 0.6, tarnish * 0.3); // Less metallic where tarnished
        
    } else if (MATERIAL_TYPE == 3) { // Leather
        albedo = texture(leather_texture, uv).rgb;
        normal_map = texture(leather_normal_map, uv).rgb;
        roughness = texture(leather_roughness_map, uv).r;
        
        // Add leather wear and cracks
        float wear = noise(uv * 25.0) * 0.5 + 0.5;
        albedo = mix(albedo, albedo * 0.7, wear * 0.3);
        roughness = mix(roughness, 0.9, wear * 0.2);
    }
    
    // Apply medieval color grading to all materials
    // Warmer, slightly desaturated look
    albedo = mix(albedo, vec3(dot(albedo, vec3(0.299, 0.587, 0.114))), 0.2); // Slight desaturation
    albedo = albedo * vec3(1.1, 0.95, 0.8); // Warm tint
    
    // Output to shader
    ALBEDO = albedo;
    NORMAL_MAP = normal_map;
    ROUGHNESS = roughness;
    METALLIC = metallic;
}
