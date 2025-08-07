//
//  ShaderTypes.h
//  MetalShooter
//
//  Metal4 着色器类型定义 - Phase 3 高级渲染特性
//  定义Swift和Metal着色器之间共享的数据结构
//

#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

#ifdef __METAL_VERSION__
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
typedef metal::int32_t EnumBackingType;
#else
#import <Foundation/Foundation.h>
typedef NSInteger EnumBackingType;
#endif

// MARK: - 常量定义

#define MAX_POINT_LIGHTS 8
#define MAX_SPOT_LIGHTS 8
#define MAX_DIRECTIONAL_LIGHTS 4
#define MAX_CASCADE_COUNT 4

// MARK: - 顶点数据结构

/// 顶点输入结构 - 用于着色器顶点输入
typedef struct {
    simd_float3 position [[attribute(0)]];    // 顶点位置
    simd_float3 normal [[attribute(1)]];      // 法线
    simd_float2 texCoords [[attribute(2)]];   // 纹理坐标
    simd_float4 color [[attribute(3)]];       // 顶点颜色
    simd_float3 tangent [[attribute(4)]];     // 切线（用于法线贴图）
} VertexIn;

// MARK: - Uniform数据结构

/// Uniform数据 - 用于MVP变换矩阵
typedef struct {
    simd_float4x4 modelMatrix;      // 模型矩阵
    simd_float4x4 viewMatrix;       // 视图矩阵
    simd_float4x4 projectionMatrix; // 投影矩阵
} Uniforms;

// MARK: - 光照数据结构

/// 方向光数据
typedef struct {
    simd_float3 direction;   // 光源方向
    float intensity;         // 光源强度
    simd_float3 color;       // 光源颜色
    float padding;           // 对齐填充
} DirectionalLightData;

/// 点光源数据
typedef struct {
    simd_float3 position;    // 光源位置
    float intensity;         // 光源强度
    simd_float3 color;       // 光源颜色
    float range;            // 光源范围
} PointLightData;

/// 聚光灯数据
typedef struct {
    simd_float3 position;        // 光源位置
    float intensity;             // 光源强度
    simd_float3 direction;       // 光源方向
    float range;                // 光源范围
    simd_float3 color;          // 光源颜色
    float innerConeAngle;       // 内锥角余弦值
    float outerConeAngle;       // 外锥角余弦值
    float padding1;             // 对齐填充
    simd_float2 padding2;       // 对齐填充
} SpotLightData;

/// 综合光照数据
typedef struct {
    simd_float3 ambientColor;                      // 环境光颜色
    float padding0;                                // 对齐填充
    simd_float3 cameraPosition;                    // 相机位置
    float padding1;                                // 对齐填充
    
    DirectionalLightData directionalLight;         // 主方向光
    
    int pointLightCount;                           // 点光源数量
    int spotLightCount;                            // 聚光灯数量
    simd_float2 padding2;                          // 对齐填充
    
    PointLightData pointLights[MAX_POINT_LIGHTS];  // 点光源数组
    SpotLightData spotLights[MAX_SPOT_LIGHTS];     // 聚光灯数组
    
    simd_float4 cascadeDistances;                  // CSM级联距离
    simd_float4x4 shadowMatrices[MAX_CASCADE_COUNT]; // 阴影变换矩阵
} LightingData;

// MARK: - 材质数据结构

/// PBR材质数据
typedef struct {
    simd_float4 baseColor;       // 基础颜色 (RGB + Alpha)
    float metallic;              // 金属度
    float roughness;             // 粗糙度
    float ao;                    // 环境光遮蔽
    float padding0;              // 对齐填充
    simd_float3 emissive;        // 自发光颜色
    float padding1;              // 对齐填充
} MaterialData;

// MARK: - 阴影映射数据结构

/// 标准阴影Uniform
typedef struct {
    simd_float4x4 mvpMatrix;     // MVP矩阵
    float bias;                  // 阴影偏移
    simd_float3 padding;         // 对齐填充
} ShadowUniforms;

/// 点光源阴影Uniform
typedef struct {
    simd_float4x4 mvpMatrix;     // MVP矩阵
    simd_float3 lightPosition;   // 光源位置
    float lightRange;            // 光源范围
} PointShadowUniforms;

// MARK: - 传统数据结构（向后兼容）

/// 传统光源数据（Phase 1/2 兼容）
typedef struct {
    simd_float3 position;    // 光源位置
    simd_float3 direction;   // 光源方向
    simd_float3 color;       // 光源颜色
    float intensity;         // 光源强度
    float range;            // 光源范围
    float spotAngle;        // 聚光灯角度
} Light;

/// 传统材质数据（Phase 1/2 兼容）
typedef struct {
    simd_float4 albedo;      // 反照率颜色
    float metallic;          // 金属度
    float roughness;         // 粗糙度
    float ao;                // 环境光遮蔽
    float emission;          // 自发光强度
} Material;

// MARK: - 缓冲区索引枚举

typedef NS_ENUM(EnumBackingType, BufferIndex) {
    BufferIndexVertices     = 0,    // 顶点缓冲区
    BufferIndexUniforms     = 1,    // Uniform缓冲区
    BufferIndexLightingData = 2,    // 光照数据缓冲区
    BufferIndexMaterialData = 3,    // 材质数据缓冲区
    BufferIndexShadowData   = 4,    // 阴影数据缓冲区
    
    // 传统索引（向后兼容）
    BufferIndexLights       = 2,    // 光照缓冲区（别名）
    BufferIndexMaterial     = 3     // 材质缓冲区（别名）
};

// MARK: - 顶点属性枚举

typedef NS_ENUM(EnumBackingType, VertexAttribute) {
    VertexAttributePosition  = 0,  // 位置属性
    VertexAttributeNormal    = 1,  // 法线属性
    VertexAttributeTexCoord  = 2,  // 纹理坐标属性
    VertexAttributeColor     = 3,  // 颜色属性
    VertexAttributeTangent   = 4   // 切线属性（Phase 3）
};

// MARK: - 纹理索引枚举

typedef NS_ENUM(EnumBackingType, TextureIndex) {
    TextureIndexAlbedo           = 0,  // 反照率纹理
    TextureIndexNormal           = 1,  // 法线纹理
    TextureIndexMetallicRoughness = 2, // 金属度粗糙度纹理 (B通道=金属度, G通道=粗糙度)
    TextureIndexAO               = 3,  // 环境光遮蔽纹理
    TextureIndexEmissive         = 4,  // 自发光纹理
    
    // 阴影贴图纹理索引
    TextureIndexShadowMap0       = 5,  // 级联阴影贴图 0
    TextureIndexShadowMap1       = 6,  // 级联阴影贴图 1
    TextureIndexShadowMap2       = 7,  // 级联阴影贴图 2
    TextureIndexShadowMap3       = 8,  // 级联阴影贴图 3
    
    // 传统纹理索引（向后兼容）
    TextureIndexMetallic         = 2,  // 金属度纹理（别名）
    TextureIndexRoughness        = 3,  // 粗糙度纹理（别名）
    TextureIndexEmission         = 5   // 自发光纹理（别名）
};

// MARK: - 采样器索引枚举

typedef NS_ENUM(EnumBackingType, SamplerIndex) {
    SamplerIndexTexture = 0,    // 纹理采样器
    SamplerIndexShadow  = 1     // 阴影采样器
};

#endif /* ShaderTypes_h */

