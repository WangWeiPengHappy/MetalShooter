import simd

/// 通用变换结构体，包含位置、旋转、缩放
struct PlayerTransform {
    var position: SIMD3<Float>
    var rotation: simd_quatf
    var scale: SIMD3<Float>
    /// 单位变换（无位移、无旋转、单位缩放）
    static var identity: PlayerTransform {
        PlayerTransform(position: SIMD3<Float>(0,0,0), rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1), scale: SIMD3<Float>(1,1,1))
    }
}
