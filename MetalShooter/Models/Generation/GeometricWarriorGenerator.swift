import Foundation
import Metal
import simd

/// 几何战士生成器 - 使用基础几何图形生成3D战士模型
class GeometricWarriorGenerator {
    
    /// 静态方法 - 生成完整的几何战士模型
    static func generateModel() -> PlayerModel {
        let generator = GeometricWarriorGenerator()
        return generator.generateModel()
    }
    
    /// 实例方法 - 生成完整的几何战士模型
    func generateModel() -> PlayerModel {
        var components: [ModelComponent] = []
        
        // 生成头部 - 球体
        let head = generateHead()
        components.append(head)
        
        // 生成躯干 - 立方体
        let torso = generateTorso()
        components.append(torso)
        
        // 生成四肢 - 圆柱体
        let limbs = generateLimbs()
        components.append(contentsOf: limbs)
        
        return PlayerModel(
            name: "GeometricWarrior",
            components: components
        )
    }
    
    /// 生成头部
    private func generateHead() -> ModelComponent {
        let (vertices, indices) = GeometryPrimitives.generateSphere(radius: 0.25, longitudeSegments: 16, latitudeSegments: 12)
        let transform = Transform(
            position: simd_float3(0, 1.4, 0),
            rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1), // 无旋转
            scale: simd_float3(1, 1, 1)
        )
        
        return ModelComponent(
            vertices: vertices,
            indices: indices,
            materialId: "head_material",
            transform: transform,
            name: "Head"
        )
    }
    
    /// 生成躯干
    private func generateTorso() -> ModelComponent {
        let (vertices, indices) = GeometryPrimitives.generateBox(width: 1.0, height: 1.4, depth: 0.7)
        let transform = Transform(
            position: simd_float3(0, 0.3, 0),
            rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
            scale: simd_float3(1, 1, 1)
        )
        
        return ModelComponent(
            vertices: vertices,
            indices: indices,
            materialId: "body_material",
            transform: transform,
            name: "Torso"
        )
    }
    
    /// 生成四肢
    private func generateLimbs() -> [ModelComponent] {
        var limbs: [ModelComponent] = []
        
        // 左臂
        let (leftArmVertices, leftArmIndices) = GeometryPrimitives.generateCylinder(radius: 0.12, height: 0.9)
        let leftArm = ModelComponent(
            vertices: leftArmVertices,
            indices: leftArmIndices,
            materialId: "limb_material",
            transform: Transform(
                position: simd_float3(-0.65, 0.5, 0),
                rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
                scale: simd_float3(1, 1, 1)
            ),
            name: "LeftArm"
        )
        
        // 右臂
        let (rightArmVertices, rightArmIndices) = GeometryPrimitives.generateCylinder(radius: 0.12, height: 0.9)
        let rightArm = ModelComponent(
            vertices: rightArmVertices,
            indices: rightArmIndices,
            materialId: "limb_material",
            transform: Transform(
                position: simd_float3(0.65, 0.5, 0),
                rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
                scale: simd_float3(1, 1, 1)
            ),
            name: "RightArm"
        )
        
        // 左腿
        let (leftLegVertices, leftLegIndices) = GeometryPrimitives.generateCylinder(radius: 0.2, height: 1.0)
        let leftLeg = ModelComponent(
            vertices: leftLegVertices,
            indices: leftLegIndices,
            materialId: "limb_material",
            transform: Transform(
                position: simd_float3(-0.3, -0.7, 0),
                rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
                scale: simd_float3(1, 1, 1)
            ),
            name: "LeftLeg"
        )
        
        // 右腿
        let (rightLegVertices, rightLegIndices) = GeometryPrimitives.generateCylinder(radius: 0.2, height: 1.0)
        let rightLeg = ModelComponent(
            vertices: rightLegVertices,
            indices: rightLegIndices,
            materialId: "limb_material",
            transform: Transform(
                position: simd_float3(0.3, -0.7, 0),
                rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
                scale: simd_float3(1, 1, 1)
            ),
            name: "RightLeg"
        )
        
        limbs.append(leftArm)
        limbs.append(rightArm)
        limbs.append(leftLeg)
        limbs.append(rightLeg)
        
        return limbs
    }
}
