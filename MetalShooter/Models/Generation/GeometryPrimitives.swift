import Foundation
import Metal
import simd

/// 几何图元生成工具类
/// 提供生成基本几何体（球体、圆柱体、立方体）的功能
class GeometryPrimitives {
    
    // MARK: - 球体生成
    
    /// 生成球体几何数据
    /// - Parameters:
    ///   - radius: 半径
    ///   - longitudeSegments: 经度分段数（水平分段）
    ///   - latitudeSegments: 纬度分段数（垂直分段）
    /// - Returns: 顶点数组和索引数组
    static func generateSphere(radius: Float = 1.0, longitudeSegments: Int = 16, latitudeSegments: Int = 16) -> ([Vertex], [UInt32]) {
        var vertices: [Vertex] = []
        var indices: [UInt32] = []
        
        let longitudeStep = 2.0 * Float.pi / Float(longitudeSegments)
        let latitudeStep = Float.pi / Float(latitudeSegments)
        
        // 生成顶点
        for lat in 0...latitudeSegments {
            let theta = Float(lat) * latitudeStep
            let sinTheta = sin(theta)
            let cosTheta = cos(theta)
            
            for lon in 0...longitudeSegments {
                let phi = Float(lon) * longitudeStep
                let sinPhi = sin(phi)
                let cosPhi = cos(phi)
                
                let x = cosPhi * sinTheta
                let y = cosTheta
                let z = sinPhi * sinTheta
                
                let position = SIMD3<Float>(x * radius, y * radius, z * radius)
                let normal = SIMD3<Float>(x, y, z)
                let texCoord = SIMD2<Float>(Float(lon) / Float(longitudeSegments), Float(lat) / Float(latitudeSegments))
                let color = SIMD4<Float>(0.8, 0.8, 0.8, 1.0)
                
                vertices.append(Vertex(
                    position: position,
                    normal: normalize(normal),
                    texCoords: texCoord,
                    color: color
                ))
            }
        }
        
        // 生成索引
        for lat in 0..<latitudeSegments {
            for lon in 0..<longitudeSegments {
                let first = UInt32(lat * (longitudeSegments + 1) + lon)
                let second = UInt32(first + UInt32(longitudeSegments + 1))
                
                // 三角形1
                indices.append(first)
                indices.append(second)
                indices.append(first + 1)
                
                // 三角形2
                indices.append(second)
                indices.append(second + 1)
                indices.append(first + 1)
            }
        }
        
        return (vertices, indices)
    }
    
    // MARK: - 圆柱体生成
    
    /// 生成圆柱体几何数据
    /// - Parameters:
    ///   - radius: 半径
    ///   - height: 高度
    ///   - radialSegments: 径向分段数
    ///   - heightSegments: 高度分段数
    /// - Returns: 顶点数组和索引数组
    static func generateCylinder(radius: Float = 1.0, height: Float = 2.0, radialSegments: Int = 12, heightSegments: Int = 8) -> ([Vertex], [UInt32]) {
        var vertices: [Vertex] = []
        var indices: [UInt32] = []
        
        let angleStep = 2.0 * Float.pi / Float(radialSegments)
        let heightStep = height / Float(heightSegments)
        
        // 生成侧面顶点
        for h in 0...heightSegments {
            let y = Float(h) * heightStep - height * 0.5
            
            for r in 0...radialSegments {
                let angle = Float(r) * angleStep
                let x = cos(angle) * radius
                let z = sin(angle) * radius
                
                let position = SIMD3<Float>(x, y, z)
                let normal = SIMD3<Float>(cos(angle), 0, sin(angle))
                let texCoord = SIMD2<Float>(Float(r) / Float(radialSegments), Float(h) / Float(heightSegments))
                let color = SIMD4<Float>(0.7, 0.7, 0.7, 1.0)
                
                vertices.append(Vertex(
                    position: position,
                    normal: normalize(normal),
                    texCoords: texCoord,
                    color: color
                ))
            }
        }
        
        // 生成侧面索引
        for h in 0..<heightSegments {
            for r in 0..<radialSegments {
                let first = UInt32(h * (radialSegments + 1) + r)
                let second = UInt32(first + UInt32(radialSegments + 1))
                
                // 三角形1
                indices.append(first)
                indices.append(second)
                indices.append(first + 1)
                
                // 三角形2
                indices.append(second)
                indices.append(second + 1)
                indices.append(first + 1)
            }
        }
        
        return (vertices, indices)
    }
    
    // MARK: - 立方体生成
    
    /// 生成立方体几何数据
    /// - Parameters:
    ///   - width: 宽度
    ///   - height: 高度
    ///   - depth: 深度
    /// - Returns: 顶点数组和索引数组
    static func generateBox(width: Float = 1.0, height: Float = 1.0, depth: Float = 1.0) -> ([Vertex], [UInt32]) {
        let w = width * 0.5
        let h = height * 0.5
        let d = depth * 0.5
        
        let vertices: [Vertex] = [
            // 前面 (Z+)
            Vertex(position: SIMD3<Float>(-w, -h,  d), normal: SIMD3<Float>(0, 0, 1), texCoords: SIMD2<Float>(0, 0), color: SIMD4<Float>(0.6, 0.6, 0.6, 1.0)),
            Vertex(position: SIMD3<Float>( w, -h,  d), normal: SIMD3<Float>(0, 0, 1), texCoords: SIMD2<Float>(1, 0), color: SIMD4<Float>(0.6, 0.6, 0.6, 1.0)),
            Vertex(position: SIMD3<Float>( w,  h,  d), normal: SIMD3<Float>(0, 0, 1), texCoords: SIMD2<Float>(1, 1), color: SIMD4<Float>(0.6, 0.6, 0.6, 1.0)),
            Vertex(position: SIMD3<Float>(-w,  h,  d), normal: SIMD3<Float>(0, 0, 1), texCoords: SIMD2<Float>(0, 1), color: SIMD4<Float>(0.6, 0.6, 0.6, 1.0)),
            
            // 后面 (Z-)
            Vertex(position: SIMD3<Float>( w, -h, -d), normal: SIMD3<Float>(0, 0, -1), texCoords: SIMD2<Float>(0, 0), color: SIMD4<Float>(0.6, 0.6, 0.6, 1.0)),
            Vertex(position: SIMD3<Float>(-w, -h, -d), normal: SIMD3<Float>(0, 0, -1), texCoords: SIMD2<Float>(1, 0), color: SIMD4<Float>(0.6, 0.6, 0.6, 1.0)),
            Vertex(position: SIMD3<Float>(-w,  h, -d), normal: SIMD3<Float>(0, 0, -1), texCoords: SIMD2<Float>(1, 1), color: SIMD4<Float>(0.6, 0.6, 0.6, 1.0)),
            Vertex(position: SIMD3<Float>( w,  h, -d), normal: SIMD3<Float>(0, 0, -1), texCoords: SIMD2<Float>(0, 1), color: SIMD4<Float>(0.6, 0.6, 0.6, 1.0)),
            
            // 左面 (X-)
            Vertex(position: SIMD3<Float>(-w, -h, -d), normal: SIMD3<Float>(-1, 0, 0), texCoords: SIMD2<Float>(0, 0), color: SIMD4<Float>(0.6, 0.6, 0.6, 1.0)),
            Vertex(position: SIMD3<Float>(-w, -h,  d), normal: SIMD3<Float>(-1, 0, 0), texCoords: SIMD2<Float>(1, 0), color: SIMD4<Float>(0.6, 0.6, 0.6, 1.0)),
            Vertex(position: SIMD3<Float>(-w,  h,  d), normal: SIMD3<Float>(-1, 0, 0), texCoords: SIMD2<Float>(1, 1), color: SIMD4<Float>(0.6, 0.6, 0.6, 1.0)),
            Vertex(position: SIMD3<Float>(-w,  h, -d), normal: SIMD3<Float>(-1, 0, 0), texCoords: SIMD2<Float>(0, 1), color: SIMD4<Float>(0.6, 0.6, 0.6, 1.0)),
            
            // 右面 (X+)
            Vertex(position: SIMD3<Float>( w, -h,  d), normal: SIMD3<Float>(1, 0, 0), texCoords: SIMD2<Float>(0, 0), color: SIMD4<Float>(0.6, 0.6, 0.6, 1.0)),
            Vertex(position: SIMD3<Float>( w, -h, -d), normal: SIMD3<Float>(1, 0, 0), texCoords: SIMD2<Float>(1, 0), color: SIMD4<Float>(0.6, 0.6, 0.6, 1.0)),
            Vertex(position: SIMD3<Float>( w,  h, -d), normal: SIMD3<Float>(1, 0, 0), texCoords: SIMD2<Float>(1, 1), color: SIMD4<Float>(0.6, 0.6, 0.6, 1.0)),
            Vertex(position: SIMD3<Float>( w,  h,  d), normal: SIMD3<Float>(1, 0, 0), texCoords: SIMD2<Float>(0, 1), color: SIMD4<Float>(0.6, 0.6, 0.6, 1.0)),
            
            // 底面 (Y-)
            Vertex(position: SIMD3<Float>(-w, -h, -d), normal: SIMD3<Float>(0, -1, 0), texCoords: SIMD2<Float>(0, 0), color: SIMD4<Float>(0.6, 0.6, 0.6, 1.0)),
            Vertex(position: SIMD3<Float>( w, -h, -d), normal: SIMD3<Float>(0, -1, 0), texCoords: SIMD2<Float>(1, 0), color: SIMD4<Float>(0.6, 0.6, 0.6, 1.0)),
            Vertex(position: SIMD3<Float>( w, -h,  d), normal: SIMD3<Float>(0, -1, 0), texCoords: SIMD2<Float>(1, 1), color: SIMD4<Float>(0.6, 0.6, 0.6, 1.0)),
            Vertex(position: SIMD3<Float>(-w, -h,  d), normal: SIMD3<Float>(0, -1, 0), texCoords: SIMD2<Float>(0, 1), color: SIMD4<Float>(0.6, 0.6, 0.6, 1.0)),
            
            // 顶面 (Y+)
            Vertex(position: SIMD3<Float>(-w,  h,  d), normal: SIMD3<Float>(0, 1, 0), texCoords: SIMD2<Float>(0, 0), color: SIMD4<Float>(0.6, 0.6, 0.6, 1.0)),
            Vertex(position: SIMD3<Float>( w,  h,  d), normal: SIMD3<Float>(0, 1, 0), texCoords: SIMD2<Float>(1, 0), color: SIMD4<Float>(0.6, 0.6, 0.6, 1.0)),
            Vertex(position: SIMD3<Float>( w,  h, -d), normal: SIMD3<Float>(0, 1, 0), texCoords: SIMD2<Float>(1, 1), color: SIMD4<Float>(0.6, 0.6, 0.6, 1.0)),
            Vertex(position: SIMD3<Float>(-w,  h, -d), normal: SIMD3<Float>(0, 1, 0), texCoords: SIMD2<Float>(0, 1), color: SIMD4<Float>(0.6, 0.6, 0.6, 1.0))
        ]
        
        let indices: [UInt32] = [
            // 前面
            0, 1, 2, 2, 3, 0,
            // 后面
            4, 5, 6, 6, 7, 4,
            // 左面
            8, 9, 10, 10, 11, 8,
            // 右面
            12, 13, 14, 14, 15, 12,
            // 底面
            16, 17, 18, 18, 19, 16,
            // 顶面
            20, 21, 22, 22, 23, 20
        ]
        
        return (vertices, indices)
    }
    
    // MARK: - 变换工具
    
    /// 对顶点数组应用变换
    /// - Parameters:
    ///   - vertices: 原始顶点数组
    ///   - position: 位置偏移
    ///   - rotation: 旋转角度（弧度）
    ///   - scale: 缩放比例
    /// - Returns: 变换后的顶点数组
    static func transformVertices(_ vertices: [Vertex], 
                                position: SIMD3<Float> = SIMD3<Float>(0, 0, 0),
                                rotation: SIMD3<Float> = SIMD3<Float>(0, 0, 0),
                                scale: SIMD3<Float> = SIMD3<Float>(1, 1, 1)) -> [Vertex] {
        
        // 创建变换矩阵
        let translationMatrix = matrix_float4x4(translation: position)
        let rotationXMatrix = matrix_float4x4(rotationX: rotation.x)
        let rotationYMatrix = matrix_float4x4(rotationY: rotation.y)
        let rotationZMatrix = matrix_float4x4(rotationZ: rotation.z)
        let scaleMatrix = matrix_float4x4(scaling: scale)
        
        let transform = translationMatrix * rotationZMatrix * rotationYMatrix * rotationXMatrix * scaleMatrix
        
        // 对每个顶点应用变换
        return vertices.map { vertex in
            let position4 = SIMD4<Float>(vertex.position.x, vertex.position.y, vertex.position.z, 1.0)
            let transformedPosition4 = transform * position4
            let transformedPosition = SIMD3<Float>(transformedPosition4.x, transformedPosition4.y, transformedPosition4.z)
            
            // 对法线也应用旋转（但不包括缩放和平移）
            let rotationMatrix = rotationZMatrix * rotationYMatrix * rotationXMatrix
            let normal4 = SIMD4<Float>(vertex.normal.x, vertex.normal.y, vertex.normal.z, 0.0)
            let transformedNormal4 = rotationMatrix * normal4
            let transformedNormal = normalize(SIMD3<Float>(transformedNormal4.x, transformedNormal4.y, transformedNormal4.z))
            
            return Vertex(
                position: transformedPosition,
                normal: transformedNormal,
                texCoords: vertex.texCoords,
                color: vertex.color,
                tangent: vertex.tangent
            )
        }
    }
}
