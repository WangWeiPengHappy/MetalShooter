// PlayerTransform 位于同target可直接使用
import Foundation
import simd

// 基础OBJ文件解析器，将OBJ文件解析为PlayerModel
class OBJParser {
	/// 解析OBJ文件，返回PlayerModel
	/// 支持 v / vt / vn / f 三元组，执行去重以避免无谓重复顶点。
	static func parseOBJ(atPath path: String, modelName: String = "PlayerModel") -> PlayerModel? {
		// 解析前基础文件信息
		let fm = FileManager.default
		var fileSizeDesc = "?"
		if let attrs = try? fm.attributesOfItem(atPath: path), let size = attrs[.size] as? NSNumber {
			fileSizeDesc = "\(size.intValue) bytes"
		}
		let exists = fm.fileExists(atPath: path)
		print("📥 OBJParser: 准备解析 path=\(path) exists=\(exists) size=\(fileSizeDesc) modelName=\(modelName)")
		guard let content = try? String(contentsOfFile: path) else {
			print("❌ OBJParser: 无法读取OBJ文件: \(path)")
			return nil
		}

		// 抽取第一条有效（非注释/空）行用于调试
		if let firstLine = content.split(separator: "\n").map({ String($0.trimmingCharacters(in: .whitespaces)) }).first(where: { !$0.isEmpty && !$0.hasPrefix("#") }) {
			let preview = firstLine.count > 80 ? String(firstLine.prefix(80)) + "…" : firstLine
			print("🔎 OBJParser: 首个有效行预览 -> \(preview)")
		} else {
			print("⚠️ OBJParser: 文件中没有有效顶点/面描述行 (可能为空或全是注释)")
		}

		var positions: [SIMD3<Float>] = []
		var normals: [SIMD3<Float>] = []
		var texcoords: [SIMD2<Float>] = []

		struct Key: Hashable { let p: Int; let t: Int; let n: Int }
		var vertexMap: [Key: UInt32] = [:]
		var vertices: [Vertex] = []
		var indices: [UInt32] = []

		var faceRawTriplets: [[Key]] = []

		let lines = content.components(separatedBy: .newlines)
		for raw in lines {
			let line = raw.trimmingCharacters(in: .whitespaces)
			if line.isEmpty || line.hasPrefix("#") { continue }
			if line.hasPrefix("v ") { // position
				let comps = line.split(separator: " ").compactMap { Float($0) }
				if comps.count >= 3 { positions.append(SIMD3<Float>(comps[0], comps[1], comps[2])) }
			} else if line.hasPrefix("vn ") { // normal
				let comps = line.split(separator: " ").compactMap { Float($0) }
				if comps.count >= 3 { normals.append(simd_normalize(SIMD3<Float>(comps[0], comps[1], comps[2]))) }
			} else if line.hasPrefix("vt ") { // texcoord
				let comps = line.split(separator: " ").compactMap { Float($0) }
				if comps.count >= 2 { texcoords.append(SIMD2<Float>(comps[0], comps[1])) }
			} else if line.hasPrefix("f ") {
				let comps = line.dropFirst(2).split(separator: " ")
				var triplets: [Key] = []
				for c in comps {
					// 可能形式: v / v/t / v//n / v/t/n
					let parts = c.split(separator: "/", omittingEmptySubsequences: false)
					let p = (parts.count > 0 && !parts[0].isEmpty) ? (Int(parts[0]) ?? 0) - 1 : -1
					let t = (parts.count > 1 && !parts[1].isEmpty) ? (Int(parts[1]) ?? 0) - 1 : -1
					let n = (parts.count > 2 && !parts[2].isEmpty) ? (Int(parts[2]) ?? 0) - 1 : -1
					if p >= 0 { triplets.append(Key(p: p, t: t, n: n)) }
				}
				if triplets.count >= 3 { faceRawTriplets.append(triplets) }
			}
		}

		// 组装顶点（带去重）
		for triplets in faceRawTriplets {
			// 扇形三角化
			for i in 1..<(triplets.count - 1) {
				let tri = [triplets[0], triplets[i], triplets[i+1]]
				for k in tri {
					if let existing = vertexMap[k] {
						indices.append(existing)
					} else {
						let pos = (k.p >= 0 && k.p < positions.count) ? positions[k.p] : SIMD3<Float>(0,0,0)
						let nor = (k.n >= 0 && k.n < normals.count) ? normals[k.n] : SIMD3<Float>(0,1,0)
						let uv  = (k.t >= 0 && k.t < texcoords.count) ? texcoords[k.t] : SIMD2<Float>(0,0)
						let vtx = Vertex(position: pos, normal: nor, texCoords: uv, color: SIMD4<Float>(1,1,1,1))
						let newIndex = UInt32(vertices.count)
						vertices.append(vtx)
						vertexMap[k] = newIndex
						indices.append(newIndex)
					}
				}
			}
		}

		if positions.isEmpty {
			print("⚠️ OBJParser: 未解析到任何位置(v) 数据 — 模型将为空或退化")
		}
		if vertices.isEmpty {
			print("⚠️ OBJParser: 生成顶点数量为0 — 渲染时将不可见 (请检查 f 面定义是否正确)")
		}
		print("🧾 OBJ解析统计: 位置=\(positions.count) 法线=\(normals.count) UV=\(texcoords.count) 生成顶点=\(vertices.count) 索引=\(indices.count)")

		let component = ModelComponent(
			vertices: vertices,
			indices: indices,
			materialId: "default",
			transform: PlayerTransform.identity,
			name: "OBJComponent")
		let model = PlayerModel(name: modelName, components: [component])
		return model
	}
}
