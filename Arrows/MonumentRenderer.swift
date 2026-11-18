import MetalKit

private struct MonumentVertex {
    var position: SIMD2<Float>
    var color: SIMD4<Float>
}

private struct MonumentUniforms {
    var viewportSize: SIMD2<Float>
    var boardSize: SIMD2<Float>
    var pan: SIMD2<Float>
    var zoom: Float
    var padding: Float = 0
}

final class MonumentRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private var vertexBuffer: MTLBuffer?
    private var vertexCount = 0
    private var vertexRanges: [UInt32: Range<Int>] = [:]
    private var activeIDs: Set<UInt32> = []
    private let boardSize: SIMD2<Float>

    var zoom: Float = 1
    var pan: SIMD2<Float> = .zero

    init?(view: MTKView, level: MonumentLevel) {
        guard let device = view.device ?? MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue(),
              let library = try? device.makeLibrary(source: Self.shaderSource, options: nil),
              let vertexFunction = library.makeFunction(name: "monumentVertex"),
              let fragmentFunction = library.makeFunction(name: "monumentFragment") else { return nil }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha

        guard let pipeline = try? device.makeRenderPipelineState(descriptor: descriptor) else { return nil }
        self.device = device
        commandQueue = queue
        self.pipeline = pipeline
        boardSize = SIMD2(level.width, level.height)
        super.init()

        let geometry = Self.makeGeometry(for: level.arrows)
        vertexCount = geometry.vertices.count
        vertexRanges = geometry.ranges
        activeIDs = Set(level.arrows.map(\.id))
        vertexBuffer = device.makeBuffer(
            bytes: geometry.vertices,
            length: MemoryLayout<MonumentVertex>.stride * geometry.vertices.count,
            options: .storageModeShared
        )

        view.device = device
        view.delegate = self
        view.clearColor = MTLClearColor(red: 0.975, green: 0.98, blue: 0.965, alpha: 1)
        view.preferredFramesPerSecond = 60
        view.enableSetNeedsDisplay = false
        view.isPaused = false
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let pass = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return }

        var uniforms = MonumentUniforms(
            viewportSize: SIMD2(Float(view.drawableSize.width), Float(view.drawableSize.height)),
            boardSize: boardSize,
            pan: pan,
            zoom: zoom
        )
        encoder.setRenderPipelineState(pipeline)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<MonumentUniforms>.stride, index: 1)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexCount)
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    func update(activeIDs newActiveIDs: Set<UInt32>) {
        guard newActiveIDs != activeIDs, let vertexBuffer else { return }
        let removed = activeIDs.subtracting(newActiveIDs)
        let restored = newActiveIDs.subtracting(activeIDs)
        let vertices = vertexBuffer.contents().bindMemory(
            to: MonumentVertex.self,
            capacity: vertexCount
        )

        for id in removed {
            guard let range = vertexRanges[id] else { continue }
            for index in range { vertices[index].color.w = 0 }
        }
        for id in restored {
            guard let range = vertexRanges[id] else { continue }
            for index in range { vertices[index].color.w = 1 }
        }
        activeIDs = newActiveIDs
    }

    func worldPoint(for point: CGPoint, in view: MTKView) -> (point: SIMD2<Float>, tolerance: Float) {
        let scale = Float(view.contentScaleFactor)
        let viewport = SIMD2(Float(view.drawableSize.width), Float(view.drawableSize.height))
        let screen = SIMD2(Float(point.x) * scale, Float(point.y) * scale)
        let fit = min(viewport.x / boardSize.x, viewport.y / boardSize.y) * 0.94
        let world = (screen - viewport * 0.5 - pan) / (fit * zoom) + boardSize * 0.5
        return (world, 18 * scale / (fit * zoom))
    }

    private static func makeGeometry(
        for arrows: [MonumentArrow]
    ) -> (vertices: [MonumentVertex], ranges: [UInt32: Range<Int>]) {
        var vertices: [MonumentVertex] = []
        var ranges: [UInt32: Range<Int>] = [:]
        vertices.reserveCapacity(arrows.count * 24)
        let lineWidth: Float = 2.4

        for arrow in arrows where arrow.points.count >= 2 {
            let startIndex = vertices.count
            let color = SIMD4(arrow.color.red, arrow.color.green, arrow.color.blue, arrow.color.alpha)
            for index in 0..<(arrow.points.count - 1) {
                let start = SIMD2(arrow.points[index].x, arrow.points[index].y)
                let end = SIMD2(arrow.points[index + 1].x, arrow.points[index + 1].y)
                appendLine(from: start, to: end, width: lineWidth, color: color, into: &vertices)
            }

            let tip = SIMD2(arrow.points.last!.x, arrow.points.last!.y)
            let previous = SIMD2(arrow.points[arrow.points.count - 2].x, arrow.points[arrow.points.count - 2].y)
            let direction = simd_normalize(tip - previous)
            let perpendicular = SIMD2(-direction.y, direction.x)
            let segmentLength = simd_distance(tip, previous)
            let headLength = min(6, segmentLength * 0.48)
            let headWidth = min(4.2, segmentLength * 0.34)
            let base = tip - direction * headLength
            vertices.append(contentsOf: [
                .init(position: tip + direction, color: color),
                .init(position: base + perpendicular * headWidth, color: color),
                .init(position: base - perpendicular * headWidth, color: color)
            ])
            ranges[arrow.id] = startIndex..<vertices.count
        }
        return (vertices, ranges)
    }

    private static func appendLine(
        from start: SIMD2<Float>,
        to end: SIMD2<Float>,
        width: Float,
        color: SIMD4<Float>,
        into vertices: inout [MonumentVertex]
    ) {
        let perpendicular = simd_normalize(SIMD2(-(end - start).y, (end - start).x)) * (width / 2)
        let a = start + perpendicular
        let b = start - perpendicular
        let c = end + perpendicular
        let d = end - perpendicular
        vertices.append(contentsOf: [
            .init(position: a, color: color), .init(position: b, color: color), .init(position: c, color: color),
            .init(position: c, color: color), .init(position: b, color: color), .init(position: d, color: color)
        ])
    }

    private static let shaderSource = #"""
    #include <metal_stdlib>
    using namespace metal;

    struct MonumentVertexInput {
        float2 position;
        float4 color;
    };

    struct MonumentUniforms {
        float2 viewportSize;
        float2 boardSize;
        float2 pan;
        float zoom;
        float padding;
    };

    struct MonumentVertexOutput {
        float4 position [[position]];
        float4 color;
    };

    vertex MonumentVertexOutput monumentVertex(
        const device MonumentVertexInput *vertices [[buffer(0)]],
        constant MonumentUniforms &uniforms [[buffer(1)]],
        uint vertexID [[vertex_id]]
    ) {
        MonumentVertexOutput output;
        float fit = min(uniforms.viewportSize.x / uniforms.boardSize.x,
                        uniforms.viewportSize.y / uniforms.boardSize.y) * 0.94;
        float2 centered = vertices[vertexID].position - uniforms.boardSize * 0.5;
        float2 screen = centered * fit * uniforms.zoom + uniforms.viewportSize * 0.5 + uniforms.pan;
        float2 clip = float2(screen.x / uniforms.viewportSize.x * 2.0 - 1.0,
                             1.0 - screen.y / uniforms.viewportSize.y * 2.0);
        output.position = float4(clip, 0.0, 1.0);
        output.color = vertices[vertexID].color;
        return output;
    }

    fragment float4 monumentFragment(MonumentVertexOutput input [[stage_in]]) {
        return input.color;
    }
    """#
}
