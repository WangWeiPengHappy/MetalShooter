//
//  FirstPersonShaders.metal
//  MetalShooter
//
//  Stage 4 - 第一人称视角专用着色器
//  为FPS武器和手臂提供专门的渲染效果
//

#include <metal_stdlib>
using namespace metal;

// MARK: - 数据结构

/// 第一人称顶点输入
struct FirstPersonVertexIn {
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
    float2 texCoord [[attribute(2)]];
    float3 tangent [[attribute(3)]];
    float3 bitangent [[attribute(4)]];
};

/// 第一人称顶点输出
struct FirstPersonVertexOut {
    float4 position [[position]];
    float3 worldPosition;
    float3 normal;
    float2 texCoord;
    float3 tangent;
    float3 bitangent;
    float4 viewPosition;
};

/// 第一人称Uniform数据
struct FirstPersonUniforms {
    float4x4 modelMatrix;
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
    float3x3 normalMatrix;
};

/// 光照参数
struct FirstPersonLighting {
    float3 lightDirection;      // 主光源方向
    float3 lightColor;          // 主光源颜色
    float3 ambientColor;        // 环境光颜色
    float lightIntensity;       // 光照强度
    float specularPower;        // 镜面反射强度
};

// MARK: - 顶点着色器

/// 第一人称顶点着色器
vertex FirstPersonVertexOut firstPersonVertexShader(FirstPersonVertexIn in [[stage_in]],
                                                   constant FirstPersonUniforms& uniforms [[buffer(1)]]) {
    FirstPersonVertexOut out;
    
    // 世界坐标位置
    float4 worldPosition = uniforms.modelMatrix * float4(in.position, 1.0);
    out.worldPosition = worldPosition.xyz;
    
    // 视图坐标位置
    out.viewPosition = uniforms.viewMatrix * worldPosition;
    
    // 投影坐标位置
    out.position = uniforms.projectionMatrix * out.viewPosition;
    
    // 变换法线
    out.normal = normalize(uniforms.normalMatrix * in.normal);
    
    // 变换切线和副切线 (用于法线贴图)
    out.tangent = normalize(uniforms.normalMatrix * in.tangent);
    out.bitangent = normalize(uniforms.normalMatrix * in.bitangent);
    
    // 传递纹理坐标
    out.texCoord = in.texCoord;
    
    return out;
}

// MARK: - 片段着色器

/// 第一人称片段着色器 (基础版本)
fragment float4 firstPersonFragmentShader(FirstPersonVertexOut in [[stage_in]],
                                         constant FirstPersonUniforms& uniforms [[buffer(1)]],
                                         constant FirstPersonLighting& lighting [[buffer(2)]],
                                         texture2d<float> diffuseTexture [[texture(0)]],
                                         texture2d<float> normalTexture [[texture(1)]],
                                         texture2d<float> specularTexture [[texture(2)]],
                                         sampler textureSampler [[sampler(0)]]) {
    
    // 采样漫反射纹理
    float4 diffuseColor = diffuseTexture.sample(textureSampler, in.texCoord);
    
    // 如果有透明度，则使用alpha测试
    if (diffuseColor.a < 0.1) {
        discard_fragment();
    }
    
    // 采样法线贴图
    float3 normalMap = normalTexture.sample(textureSampler, in.texCoord).xyz;
    normalMap = normalize(normalMap * 2.0 - 1.0);
    
    // 构建TBN矩阵
    float3x3 tbnMatrix = float3x3(in.tangent, in.bitangent, in.normal);
    float3 worldNormal = normalize(tbnMatrix * normalMap);
    
    // 计算光照
    float3 lightDir = normalize(-lighting.lightDirection);
    float3 viewDir = normalize(-in.viewPosition.xyz);
    
    // 兰伯特漫反射
    float diffuse = max(dot(worldNormal, lightDir), 0.0);
    
    // Blinn-Phong镜面反射
    float3 halfVector = normalize(lightDir + viewDir);
    float specular = pow(max(dot(worldNormal, halfVector), 0.0), lighting.specularPower);
    
    // 采样镜面反射贴图
    float3 specularMap = specularTexture.sample(textureSampler, in.texCoord).rgb;
    
    // 组合最终颜色
    float3 ambient = lighting.ambientColor * diffuseColor.rgb;
    float3 diffuseLight = lighting.lightColor * diffuse * diffuseColor.rgb * lighting.lightIntensity;
    float3 specularLight = lighting.lightColor * specular * specularMap * lighting.lightIntensity;
    
    float3 finalColor = ambient + diffuseLight + specularLight;
    
    return float4(finalColor, diffuseColor.a);
}

/// 第一人称简单片段着色器 (无纹理)
fragment float4 firstPersonSimpleFragmentShader(FirstPersonVertexOut in [[stage_in]],
                                               constant FirstPersonUniforms& uniforms [[buffer(1)]],
                                               constant FirstPersonLighting& lighting [[buffer(2)]]) {
    
    // 使用顶点法线计算简单光照
    float3 lightDir = normalize(-lighting.lightDirection);
    float diffuse = max(dot(in.normal, lightDir), 0.0);
    
    // 基础颜色 (武器为深灰色，手臂为肤色)
    float3 baseColor = float3(0.4, 0.4, 0.4); // 深灰色
    
    // 检查是否为手臂 (通过纹理坐标判断)
    if (in.texCoord.x > 0.8) {
        baseColor = float3(0.8, 0.6, 0.5); // 肤色
    }
    
    // 简单光照计算
    float3 ambient = lighting.ambientColor * baseColor * 0.3;
    float3 diffuseLight = lighting.lightColor * diffuse * baseColor * lighting.lightIntensity;
    
    float3 finalColor = ambient + diffuseLight;
    
    return float4(finalColor, 1.0);
}

/// 第一人称武器轮廓着色器
fragment float4 firstPersonOutlineFragmentShader(FirstPersonVertexOut in [[stage_in]],
                                                constant FirstPersonUniforms& uniforms [[buffer(1)]]) {
    
    // 计算到相机的距离
    float distance = length(in.viewPosition.xyz);
    
    // 根据距离调整轮廓强度
    float outlineIntensity = smoothstep(0.5, 2.0, distance);
    
    // 基础轮廓颜色
    float3 outlineColor = float3(0.1, 0.1, 0.1);
    
    return float4(outlineColor, outlineIntensity);
}

/// 第一人称深度着色器 (用于调试)
fragment float4 firstPersonDepthFragmentShader(FirstPersonVertexOut in [[stage_in]],
                                              constant FirstPersonUniforms& uniforms [[buffer(1)]]) {
    
    // 将深度值可视化
    float depth = in.position.z / in.position.w;
    float3 depthColor = float3(depth, depth, depth);
    
    return float4(depthColor, 1.0);
}

// MARK: - 工具函数

/// 计算菲涅尔反射
float fresnel(float3 viewDirection, float3 normal, float f0) {
    float cosTheta = max(dot(viewDirection, normal), 0.0);
    return f0 + (1.0 - f0) * pow(1.0 - cosTheta, 5.0);
}

/// 计算屏幕空间环境遮挡 (SSAO简化版)
float calculateSSAO(float2 texCoord, float depth, texture2d<float> depthTexture, sampler depthSampler) {
    const int sampleCount = 8;
    const float radius = 0.02;
    
    float occlusion = 0.0;
    
    for (int i = 0; i < sampleCount; i++) {
        float angle = float(i) * 2.0 * M_PI_F / float(sampleCount);
        float2 offset = float2(cos(angle), sin(angle)) * radius;
        float2 sampleCoord = texCoord + offset;
        
        float sampleDepth = depthTexture.sample(depthSampler, sampleCoord).r;
        
        if (sampleDepth < depth) {
            occlusion += 1.0;
        }
    }
    
    return 1.0 - (occlusion / float(sampleCount));
}

/// 计算雾效
float3 applyFog(float3 color, float distance, float3 fogColor, float fogDensity) {
    float fogFactor = exp(-distance * fogDensity);
    return mix(fogColor, color, fogFactor);
}

// MARK: - 特效着色器

/// 第一人称消音器闪光效果
fragment float4 firstPersonMuzzleFlashShader(FirstPersonVertexOut in [[stage_in]],
                                            constant float& flashIntensity [[buffer(1)]],
                                            constant float& time [[buffer(2)]]) {
    
    // 动态闪光效果
    float flash = sin(time * 20.0) * 0.5 + 0.5;
    flash *= flashIntensity;
    
    // 闪光颜色 (黄橙色)
    float3 flashColor = float3(1.0, 0.8, 0.3) * flash;
    
    // 添加一些噪声
    float noise = fract(sin(dot(in.texCoord, float2(12.9898, 78.233))) * 43758.5453);
    flashColor *= (0.8 + noise * 0.4);
    
    return float4(flashColor, flash * 0.8);
}

/// 第一人称武器热辉光效果
fragment float4 firstPersonHeatGlowShader(FirstPersonVertexOut in [[stage_in]],
                                         constant float& heatLevel [[buffer(1)]],
                                         constant float& time [[buffer(2)]]) {
    
    // 热量效果强度
    float heatIntensity = smoothstep(0.3, 1.0, heatLevel);
    
    // 热辉光颜色 (红橙色)
    float3 heatColor = mix(float3(0.0), float3(1.0, 0.3, 0.1), heatIntensity);
    
    // 添加脉动效果
    float pulse = sin(time * 3.0) * 0.2 + 0.8;
    heatColor *= pulse;
    
    return float4(heatColor, heatIntensity * 0.6);
}
