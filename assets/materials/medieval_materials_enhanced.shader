// Placeholder textures for medieval materials
// These will be replaced with actual textures when available

// Wood textures
uniform sampler2D wood_albedo_texture;
uniform sampler2D wood_normal_texture;
uniform sampler2D wood_roughness_texture;
uniform sampler2D wood_ao_texture;

// Stone textures
uniform sampler2D stone_albedo_texture;
uniform sampler2D stone_normal_texture;
uniform sampler2D stone_roughness_texture;
uniform sampler2D stone_ao_texture;

// Metal textures
uniform sampler2D metal_albedo_texture;
uniform sampler2D metal_normal_texture;
uniform sampler2D metal_roughness_texture;
uniform sampler2D metal_metallic_texture;

// Leather textures
uniform sampler2D leather_albedo_texture;
uniform sampler2D leather_normal_texture;
uniform sampler2D leather_roughness_texture;
uniform sampler2D leather_ao_texture;

// Material parameters
uniform int material_type; // 0=wood, 1=stone, 2=metal, 3=leather
uniform float age_factor; // 0.0 = new, 1.0 = very aged
uniform float detail_factor; // 0.0 = smooth, 1.0 = highly detailed

void vertex() {
    // Add slight vertex displacement based on normal map for detail
    if (detail_factor > 0.0) {
        vec2 uv = UV;
        float height = 0.0;
        
        if (material_type == 0) { // Wood
            height = texture(wood_normal_texture, uv).r;
        } else if (material_type == 1) { // Stone
            height = texture(stone_normal_texture, uv).r;
        } else if (material_type == 2) { // Metal
            height = texture(metal_normal_texture, uv).r;
        } else if (material_type == 3) { // Leather
            height = texture(leather_normal_texture, uv).r;
        }
        
        // Apply displacement along normal
        VERTEX += NORMAL * height * detail_factor * 0.02;
    }
}

void fragment() {
    vec2 uv = UV;
    
    // Default material properties
    vec3 albedo = vec3(0.5);
    vec3 normal_map = vec3(0.5, 0.5, 1.0);
    float roughness = 0.5;
    float metallic = 0.0;
    float ao = 1.0;
    
    // Apply material-specific textures and properties
    if (material_type == 0) { // Wood
        // Base wood color (darker, warmer tones for medieval look)
        albedo = texture(wood_albedo_texture, uv).rgb;
        normal_map = texture(wood_normal_texture, uv).rgb;
        roughness = texture(wood_roughness_texture, uv).r;
        ao = texture(wood_ao_texture, uv).r;
        
        // Add wood grain detail
        float grain = sin(uv.y * 100.0) * 0.5 + 0.5;
        albedo = mix(albedo, albedo * 0.8, grain * 0.1 * detail_factor);
        
        // Age the wood for medieval look
        albedo = mix(albedo, vec3(0.3, 0.2, 0.1), 0.2 * age_factor);
        roughness = mix(roughness, 0.9, 0.3 * age_factor); // Weathered wood is rougher
        
    } else if (material_type == 1) { // Stone
        albedo = texture(stone_albedo_texture, uv).rgb;
        normal_map = texture(stone_normal_texture, uv).rgb;
        roughness = texture(stone_roughness_texture, uv).r;
        ao = texture(stone_ao_texture, uv).r;
        
        // Add stone wear and aging
        float wear = noise(uv * 20.0) * 0.5 + 0.5;
        albedo = mix(albedo, vec3(0.5, 0.5, 0.5), wear * 0.2 * age_factor);
        roughness = mix(roughness, 1.0, wear * 0.3 * age_factor);
        
        // Add moss to old stone
        if (age_factor > 0.6) {
            float moss = noise(uv * 30.0) * 0.5 + 0.5;
            albedo = mix(albedo, vec3(0.2, 0.3, 0.1), moss * 0.3 * (age_factor - 0.6));
        }
        
    } else if (material_type == 2) { // Metal
        albedo = texture(metal_albedo_texture, uv).rgb;
        normal_map = texture(metal_normal_texture, uv).rgb;
        roughness = texture(metal_roughness_texture, uv).r;
        metallic = texture(metal_metallic_texture, uv).r;
        
        // Add metal patina and tarnish for medieval look
        float tarnish = noise(uv * 15.0) * 0.5 + 0.5;
        
        // Mix between rust and patina based on age
        vec3 rust_color = vec3(0.5, 0.2, 0.1);
        vec3 patina_color = vec3(0.2, 0.4, 0.3);
        vec3 tarnish_color = mix(rust_color, patina_color, 0.5);
        
        albedo = mix(albedo, tarnish_color, tarnish * 0.4 * age_factor);
        roughness = mix(roughness, 0.8, tarnish * 0.5 * age_factor);
        metallic = mix(metallic, 0.3, tarnish * 0.7 * age_factor);
        
    } else if (material_type == 3) { // Leather
        albedo = texture(leather_albedo_texture, uv).rgb;
        normal_map = texture(leather_normal_texture, uv).rgb;
        roughness = texture(leather_roughness_texture, uv).r;
        ao = texture(leather_ao_texture, uv).r;
        
        // Add leather wear and cracks
        float wear = noise(uv * 25.0) * 0.5 + 0.5;
        albedo = mix(albedo, albedo * 0.7, wear * 0.3 * age_factor);
        roughness = mix(roughness, 0.9, wear * 0.2 * age_factor);
        
        // Enhance normal map for cracks in old leather
        normal_map = mix(normal_map, normal_map * 1.5, age_factor);
    }
    
    // Apply medieval color grading to all materials
    // Warmer, slightly desaturated look
    float luminance = dot(albedo, vec3(0.299, 0.587, 0.114));
    albedo = mix(albedo, vec3(luminance), 0.2); // Slight desaturation
    albedo = albedo * vec3(1.1, 0.95, 0.8); // Warm tint
    
    // Apply ambient occlusion
    albedo *= ao;
    
    // Output to shader
    ALBEDO = albedo;
    NORMAL_MAP = normal_map;
    ROUGHNESS = roughness;
    METALLIC = metallic;
    AO = ao;
}
