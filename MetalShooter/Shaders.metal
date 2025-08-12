//
//  Shaders.metal
//  MetalShooter
//
//  Metal4 着色器 - Phase 3 高级渲染特性
//  支持PBR材质、动态光照和实时阴影
//

#include <metal_stdlib>
#include "ShaderTypes.h"
using namespace metal;

// MARK: - 常量定义

constant float PI = 3.14159265359;
constant float EPSILON = 1e-6;
constant int MAX_LIGHTS = 32;
constant int PCF_SAMPLES = 16;

// MARK: - 顶点着色器输出结构

struct VertexOut {
    float4 position [[position]];
    float3 worldPosition;
    float3 normal;
    float3 tangent;
    float3 bitangent;
    float2 texCoords;
    float4 color;
    float4 shadowCoords0;  // 级联阴影贴图坐标 0
    float4 shadowCoords1;  // 级联阴影贴图坐标 1
    float4 shadowCoords2;  // 级联阴影贴图坐标 2
    float4 shadowCoords3;  // 级联阴影贴图坐标 3
};

// MARK: - PBR 材质结构

struct PBRMaterial {
    float3 albedo;
    float metallic;
    float roughness;
    float3 normal;
    float ao;  // 环境遮蔽
    float3 emission;
};

// MARK: - 主要顶点着色器

vertex VertexOut vertex_main(const VertexIn vertexIn [[stage_in]],
                           constant Uniforms &uniforms [[buffer(1)]],
                           constant LightingData &lightingData [[buffer(2)]]) {
    VertexOut out;
    
    // 计算世界空间位置
    float4 worldPosition = uniforms.modelMatrix * float4(vertexIn.position, 1.0);
    out.worldPosition = worldPosition.xyz;
    
    // 计算最终位置 (MVP变换)
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * worldPosition;
    
    // 变换法线到世界空间
    float3x3 normalMatrix = float3x3(uniforms.modelMatrix.columns[0].xyz,
                                   uniforms.modelMatrix.columns[1].xyz,
                                   uniforms.modelMatrix.columns[2].xyz);
    out.normal = normalize(normalMatrix * vertexIn.normal);
    
    // 计算切线空间（用于法线贴图）
    if (length(vertexIn.tangent) > 0.0) {
        out.tangent = normalize(normalMatrix * vertexIn.tangent);
        out.bitangent = cross(out.normal, out.tangent);
    } else {
        // 如果没有切线信息，计算一个
        float3 c1 = cross(out.normal, float3(0.0, 0.0, 1.0));
        float3 c2 = cross(out.normal, float3(0.0, 1.0, 0.0));
        out.tangent = normalize(length(c1) > length(c2) ? c1 : c2);
        out.bitangent = cross(out.normal, out.tangent);
    }
    
    // 传递纹理坐标和颜色
    out.texCoords = vertexIn.texCoords;
    out.color = vertexIn.color;
    
    // 计算阴影贴图坐标（级联阴影贴图）
    out.shadowCoords0 = lightingData.shadowMatrices[0] * worldPosition;
    out.shadowCoords1 = lightingData.shadowMatrices[1] * worldPosition;
    out.shadowCoords2 = lightingData.shadowMatrices[2] * worldPosition;
    out.shadowCoords3 = lightingData.shadowMatrices[3] * worldPosition;
    
    return out;
}

// MARK: - PBR 光照函数

float3 getNormalFromMap(float3 tangentSpaceNormal, float3 worldPos, float3 normal, float2 texCoords) {
    float3 Q1 = dfdx(worldPos);
    float3 Q2 = dfdy(worldPos);
    float2 st1 = dfdx(texCoords);
    float2 st2 = dfdy(texCoords);
    
    float3 N = normalize(normal);
    float3 T = normalize(Q1 * st2.y - Q2 * st1.y);
    float3 B = -normalize(cross(N, T));
    float3x3 TBN = float3x3(T, B, N);
    
    return normalize(TBN * tangentSpaceNormal);
}

float DistributionGGX(float3 N, float3 H, float roughness) {
    float a = roughness * roughness;
    float a2 = a * a;
    float NdotH = max(dot(N, H), 0.0);
    float NdotH2 = NdotH * NdotH;
    
    float num = a2;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = PI * denom * denom;
    
    return num / denom;
}

float GeometrySchlickGGX(float NdotV, float roughness) {
    float r = (roughness + 1.0);
    float k = (r * r) / 8.0;
    
    float num = NdotV;
    float denom = NdotV * (1.0 - k) + k;
    
    return num / denom;
}

float GeometrySmith(float3 N, float3 V, float3 L, float roughness) {
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float ggx2 = GeometrySchlickGGX(NdotV, roughness);
    float ggx1 = GeometrySchlickGGX(NdotL, roughness);
    
    return ggx1 * ggx2;
}

float3 fresnelSchlick(float cosTheta, float3 F0) {
    return F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

float3 fresnelSchlickRoughness(float cosTheta, float3 F0, float roughness) {
    return F0 + (max(float3(1.0 - roughness), F0) - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

// MARK: - 阴影采样函数

float sampleShadowMap(depth2d<float> shadowMap, sampler shadowSampler, float3 shadowCoords, float bias) {
    if (shadowCoords.z > 1.0) return 0.0;
    
    // 使用固定的纹理分辨率，或从uniform传递
    float2 texelSize = 1.0 / 1024.0;  // 假设1024x1024的阴影贴图
    float shadow = 0.0;
    
    // PCF (Percentage Closer Filtering)
    for (int x = -1; x <= 1; ++x) {
        for (int y = -1; y <= 1; ++y) {
            float2 offset = float2(x, y) * texelSize;
            float pcfDepth = shadowMap.sample(shadowSampler, shadowCoords.xy + offset);
            shadow += (shadowCoords.z - bias) > pcfDepth ? 1.0 : 0.0;
        }
    }
    shadow /= 9.0;
    
    return shadow;
}

float calculateShadow(VertexOut in,
                     constant LightingData &lightingData,
                     depth2d<float> shadowMaps[4],
                     sampler shadowSampler) {
    // 选择合适的级联阴影贴图
    float depth = length(in.worldPosition - lightingData.cameraPosition);
    int cascadeIndex = 3;
    float4 shadowCoords;
    
    if (depth < lightingData.cascadeDistances.x) {
        cascadeIndex = 0;
        shadowCoords = in.shadowCoords0;
    } else if (depth < lightingData.cascadeDistances.y) {
        cascadeIndex = 1;
        shadowCoords = in.shadowCoords1;
    } else if (depth < lightingData.cascadeDistances.z) {
        cascadeIndex = 2;
        shadowCoords = in.shadowCoords2;
    } else {
        cascadeIndex = 3;
        shadowCoords = in.shadowCoords3;
    }
    
    shadowCoords.xyz /= shadowCoords.w;
    shadowCoords.xy = shadowCoords.xy * 0.5 + 0.5;
    shadowCoords.y = 1.0 - shadowCoords.y;  // 翻转Y坐标
    
    float bias = max(0.05 * (1.0 - dot(in.normal, -lightingData.directionalLight.direction)), 0.005);
    
    return sampleShadowMap(shadowMaps[cascadeIndex], shadowSampler, shadowCoords.xyz, bias);
}

// MARK: - 光照计算函数

float3 calculateDirectionalLight(DirectionalLightData light, float3 normal, float3 viewDir, PBRMaterial material) {
    float3 lightDir = normalize(-light.direction);
    float3 halfwayDir = normalize(lightDir + viewDir);
    
    // 漫反射
    float NdotL = max(dot(normal, lightDir), 0.0);
    
    // Cook-Torrance BRDF
    float NdotV = max(dot(normal, viewDir), 0.0);
    float3 F0 = mix(float3(0.04), material.albedo, material.metallic);
    
    float NDF = DistributionGGX(normal, halfwayDir, material.roughness);
    float G = GeometrySmith(normal, viewDir, lightDir, material.roughness);
    float3 F = fresnelSchlick(max(dot(halfwayDir, viewDir), 0.0), F0);
    
    float3 kS = F;
    float3 kD = float3(1.0) - kS;
    kD *= 1.0 - material.metallic;
    
    float3 numerator = NDF * G * F;
    float denominator = 4.0 * NdotV * NdotL + EPSILON;
    float3 specular = numerator / denominator;
    
    return (kD * material.albedo / PI + specular) * light.color * light.intensity * NdotL;
}

float3 calculatePointLight(PointLightData light, float3 fragPos, float3 normal, float3 viewDir, PBRMaterial material) {
    float3 lightDir = normalize(light.position - fragPos);
    float distance = length(light.position - fragPos);
    
    if (distance > light.range) return float3(0.0);
    
    float attenuation = 1.0 / (1.0 + 0.09 * distance + 0.032 * (distance * distance));
    
    float3 halfwayDir = normalize(lightDir + viewDir);
    
    float NdotL = max(dot(normal, lightDir), 0.0);
    float NdotV = max(dot(normal, viewDir), 0.0);
    float3 F0 = mix(float3(0.04), material.albedo, material.metallic);
    
    float NDF = DistributionGGX(normal, halfwayDir, material.roughness);
    float G = GeometrySmith(normal, viewDir, lightDir, material.roughness);
    float3 F = fresnelSchlick(max(dot(halfwayDir, viewDir), 0.0), F0);
    
    float3 kS = F;
    float3 kD = float3(1.0) - kS;
    kD *= 1.0 - material.metallic;
    
    float3 numerator = NDF * G * F;
    float denominator = 4.0 * NdotV * NdotL + EPSILON;
    float3 specular = numerator / denominator;
    
    float3 radiance = light.color * light.intensity * attenuation;
    
    return (kD * material.albedo / PI + specular) * radiance * NdotL;
}

float3 calculateSpotLight(SpotLightData light, float3 fragPos, float3 normal, float3 viewDir, PBRMaterial material) {
    float3 lightDir = normalize(light.position - fragPos);
    float distance = length(light.position - fragPos);
    
    if (distance > light.range) return float3(0.0);
    
    // 聚光灯衰减
    float theta = dot(lightDir, normalize(-light.direction));
    float epsilon = light.innerConeAngle - light.outerConeAngle;
    float intensity = clamp((theta - light.outerConeAngle) / epsilon, 0.0, 1.0);
    
    if (intensity <= 0.0) return float3(0.0);
    
    float attenuation = 1.0 / (1.0 + 0.09 * distance + 0.032 * (distance * distance));
    
    float3 halfwayDir = normalize(lightDir + viewDir);
    
    float NdotL = max(dot(normal, lightDir), 0.0);
    float NdotV = max(dot(normal, viewDir), 0.0);
    float3 F0 = mix(float3(0.04), material.albedo, material.metallic);
    
    float NDF = DistributionGGX(normal, halfwayDir, material.roughness);
    float G = GeometrySmith(normal, viewDir, lightDir, material.roughness);
    float3 F = fresnelSchlick(max(dot(halfwayDir, viewDir), 0.0), F0);
    
    float3 kS = F;
    float3 kD = float3(1.0) - kS;
    kD *= 1.0 - material.metallic;
    
    float3 numerator = NDF * G * F;
    float denominator = 4.0 * NdotV * NdotL + EPSILON;
    float3 specular = numerator / denominator;
    
    float3 radiance = light.color * light.intensity * attenuation * intensity;
    
    return (kD * material.albedo / PI + specular) * radiance * NdotL;
}

// MARK: - 主要片段着色器

fragment float4 fragment_pbr(VertexOut in [[stage_in]],
                            constant Uniforms &uniforms [[buffer(1)]],
                            constant LightingData &lightingData [[buffer(2)]],
                            constant MaterialData &materialData [[buffer(3)]],
                            texture2d<float> albedoTexture [[texture(0)]],
                            texture2d<float> normalTexture [[texture(1)]],
                            texture2d<float> metallicRoughnessTexture [[texture(2)]],
                            texture2d<float> aoTexture [[texture(3)]],
                            texture2d<float> emissiveTexture [[texture(4)]],
                            depth2d<float> shadowMap0 [[texture(5)]],
                            depth2d<float> shadowMap1 [[texture(6)]],
                            depth2d<float> shadowMap2 [[texture(7)]],
                            depth2d<float> shadowMap3 [[texture(8)]],
                            sampler textureSampler [[sampler(0)]],
                            sampler shadowSampler [[sampler(1)]]) {
    
    // 构建PBR材质
    PBRMaterial material;
    
    // 采样反照率贴图
    float3 albedoSample = albedoTexture.sample(textureSampler, in.texCoords).rgb;
    material.albedo = materialData.baseColor.rgb * albedoSample * in.color.rgb;
    
    // 采样金属度粗糙度贴图
    float2 metallicRoughness = metallicRoughnessTexture.sample(textureSampler, in.texCoords).bg;
    material.metallic = materialData.metallic * metallicRoughness.x;
    material.roughness = materialData.roughness * metallicRoughness.y;
    
    // 采样环境遮蔽贴图
    material.ao = aoTexture.sample(textureSampler, in.texCoords).r;
    
    // 采样自发光贴图
    material.emission = materialData.emissive.rgb * emissiveTexture.sample(textureSampler, in.texCoords).rgb;
    
    // 计算法线
    float3 normalSample = normalTexture.sample(textureSampler, in.texCoords).rgb;
    normalSample = normalize(normalSample * 2.0 - 1.0);
    
    float3x3 TBN = float3x3(normalize(in.tangent),
                           normalize(in.bitangent),
                           normalize(in.normal));
    
    float3 normal = normalize(TBN * normalSample);
    material.normal = normal;
    
    // 计算视线方向
    float3 viewDir = normalize(lightingData.cameraPosition - in.worldPosition);
    
    // 初始化光照累积
    float3 Lo = float3(0.0);
    
    // 计算阴影
    depth2d<float> shadowMaps[4] = {shadowMap0, shadowMap1, shadowMap2, shadowMap3};
    float shadow = calculateShadow(in, lightingData, shadowMaps, shadowSampler);
    
    // 计算方向光照明
    if (lightingData.directionalLight.intensity > 0.0) {
        float3 directionalContrib = calculateDirectionalLight(lightingData.directionalLight, normal, viewDir, material);
        Lo += directionalContrib * (1.0 - shadow);
    }
    
    // 计算点光源照明
    for (int i = 0; i < lightingData.pointLightCount; i++) {
        Lo += calculatePointLight(lightingData.pointLights[i], in.worldPosition, normal, viewDir, material);
    }
    
    // 计算聚光灯照明
    for (int i = 0; i < lightingData.spotLightCount; i++) {
        Lo += calculateSpotLight(lightingData.spotLights[i], in.worldPosition, normal, viewDir, material);
    }
    
    // 环境光照
    float3 F = fresnelSchlickRoughness(max(dot(normal, viewDir), 0.0), 
                                      mix(float3(0.04), material.albedo, material.metallic), 
                                      material.roughness);
    
    float3 kS = F;
    float3 kD = 1.0 - kS;
    kD *= 1.0 - material.metallic;
    
    float3 ambient = lightingData.ambientColor * material.albedo * material.ao * kD;
    
    // 最终颜色
    float3 color = ambient + Lo + material.emission;
    
    // HDR色调映射
    color = color / (color + float3(1.0));
    
    // Gamma校正
    color = pow(color, float3(1.0/2.2));
    
    return float4(color, materialData.baseColor.a * in.color.a);
}

// MARK: - 阴影着色器

vertex float4 shadow_vertex(const VertexIn vertexIn [[stage_in]],
                           constant ShadowUniforms &shadowUniforms [[buffer(1)]]) {
    float4 position = float4(vertexIn.position, 1.0);
    return shadowUniforms.mvpMatrix * position;
}

// MARK: - 点光源阴影着色器

struct PointShadowVertexOut {
    float4 position [[position]];
    float3 worldPosition;
};

vertex PointShadowVertexOut point_shadow_vertex(const VertexIn vertexIn [[stage_in]],
                                               constant PointShadowUniforms &uniforms [[buffer(1)]]) {
    PointShadowVertexOut out;
    
    float4 worldPos = float4(vertexIn.position, 1.0);
    out.worldPosition = worldPos.xyz;
    out.position = uniforms.mvpMatrix * worldPos;
    
    return out;
}

fragment float point_shadow_fragment(PointShadowVertexOut in [[stage_in]],
                                   constant PointShadowUniforms &uniforms [[buffer(1)]]) {
    // 计算从光源到片段的距离
    float lightDistance = length(in.worldPosition - uniforms.lightPosition);
    
    // 归一化距离 (0.0 到 1.0)
    lightDistance = lightDistance / uniforms.lightRange;
    
    return lightDistance;
}

// MARK: - 简单着色器 (用于测试)

vertex VertexOut vertex_simple(const VertexIn vertexIn [[stage_in]],
                             constant Uniforms &uniforms [[buffer(1)]]) {
    VertexOut out;
    
    // 应用模型-视图-投影矩阵变换
    float4 worldPos = uniforms.modelMatrix * float4(vertexIn.position, 1.0);
    float4 viewPos = uniforms.viewMatrix * worldPos;
    out.position = uniforms.projectionMatrix * viewPos;
    
    out.worldPosition = worldPos.xyz;
    out.normal = (uniforms.modelMatrix * float4(vertexIn.normal, 0.0)).xyz;
    out.tangent = (uniforms.modelMatrix * float4(vertexIn.tangent, 0.0)).xyz;
    out.bitangent = cross(out.normal, out.tangent);
    out.texCoords = vertexIn.texCoords;
    out.color = vertexIn.color;
    out.shadowCoords0 = float4(0.0);
    out.shadowCoords1 = float4(0.0);
    out.shadowCoords2 = float4(0.0);
    out.shadowCoords3 = float4(0.0);
    return out;
}

// 调试着色器 - 直接使用属性索引来测试
vertex VertexOut vertex_debug_attributes(const VertexIn vertexIn [[stage_in]]) {
    VertexOut out;
    out.position = float4(vertexIn.position, 1.0);
    out.worldPosition = vertexIn.position;
    out.normal = vertexIn.normal;
    out.tangent = vertexIn.tangent;
    out.bitangent = float3(0, 1, 0);  // 固定值
    out.texCoords = vertexIn.texCoords;
    
    // 调试：直接设置颜色来测试
    out.color = vertexIn.color;
    
    out.shadowCoords0 = float4(0.0);
    out.shadowCoords1 = float4(0.0);
    out.shadowCoords2 = float4(0.0);
    out.shadowCoords3 = float4(0.0);
    return out;
}

fragment float4 fragment_simple(VertexOut in [[stage_in]]) {
    return in.color;
}

// 调试着色器 - 返回固定的渐变颜色
fragment float4 fragment_debug(VertexOut in [[stage_in]]) {
    // 基于屏幕位置创建渐变
    float2 uv = (in.position.xy / 800.0);  // 假设屏幕宽度800
    return float4(uv.x, uv.y, 0.5, 1.0);
}

// 另一个调试着色器 - 返回顶点颜色但调试输出
fragment float4 fragment_color_debug(VertexOut in [[stage_in]]) {
    // 直接返回原始颜色，但确保alpha为1
    float4 color = in.color;
    color.a = 1.0;
    return color;
}

// 基础方向光+环境光+简单高光 (Blinn-Phong) 着色器，用于玩家模型快速获得立体感
struct BasicLightingData {
    float3 ambientColor; float padding0;
    float3 cameraPosition; float padding1;
    float3 lightDirection; float lightIntensity;
    float3 lightColor; float padding2;
};

fragment float4 fragment_basic_lighting(VertexOut in [[stage_in]],
                                       constant BasicLightingData &lighting [[buffer(2)]]) {
    float3 N = normalize(in.normal);
    float3 V = normalize(lighting.cameraPosition - in.worldPosition);
    float3 L = normalize(-lighting.lightDirection);
    float NdotL = max(dot(N, L), 0.0);
    float3 H = normalize(L + V);
    float specularFactor = pow(max(dot(N, H), 0.0), 48.0);
    float3 baseColor = in.color.rgb;
    if (all(baseColor > float3(0.95))) baseColor = float3(0.78,0.76,0.74);
    float3 ambient = lighting.ambientColor * baseColor;
    float3 diffuse = baseColor * NdotL * lighting.lightColor * lighting.lightIntensity;
    float3 specular = lighting.lightColor * lighting.lightIntensity * specularFactor;
    float3 color = ambient + diffuse + specular;
    color = pow(clamp(color,0.0,1.0), float3(1.0/2.2));
    return float4(color,1.0);
}

// 调试：直接输出法线颜色，可用于验证 OBJ 法线是否正确
fragment float4 fragment_normals(VertexOut in [[stage_in]]) {
    float3 N = normalize(in.normal) * 0.5 + 0.5; // 映射到[0,1]
    return float4(N, 1.0);
}

// 新的调试着色器 - 基于位置测试颜色属性是否正确传递
fragment float4 fragment_attribute_debug(VertexOut in [[stage_in]]) {
    // 基于顶点位置返回预期颜色来测试属性传递
    if (in.worldPosition.y > 0.0) {
        // 顶部顶点应该是红色
        return float4(1.0, 0.0, 0.0, 1.0);
    } else if (in.worldPosition.x < 0.0) {
        // 左下顶点应该是绿色
        return float4(0.0, 1.0, 0.0, 1.0);
    } else {
        // 右下顶点应该是蓝色
        return float4(0.0, 0.0, 1.0, 1.0);
    }
}

// 颜色通道测试着色器
fragment float4 fragment_channel_test(VertexOut in [[stage_in]]) {
    // 分别测试每个颜色通道
    float4 color = in.color;
    
    // 仅显示红色通道
    if (in.texCoords.x < 0.33) {
        return float4(color.r, 0.0, 0.0, 1.0);
    }
    // 仅显示绿色通道
    else if (in.texCoords.x < 0.66) {
        return float4(0.0, color.g, 0.0, 1.0);
    }
    // 仅显示蓝色通道
    else {
        return float4(0.0, 0.0, color.b, 1.0);
    }
}

// 测试着色器 - 返回固定的彩色渐变
fragment float4 fragment_test(VertexOut in [[stage_in]]) {
    // 根据顶点位置返回不同颜色
    float2 pos = in.position.xy;
    if (pos.y > 0.0) {
        return float4(1.0, 0.0, 0.0, 1.0);  // 上方红色
    } else if (pos.x < 0.0) {
        return float4(0.0, 1.0, 0.0, 1.0);  // 左下绿色
    } else {
        return float4(0.0, 0.0, 1.0, 1.0);  // 右下蓝色
    }
}
