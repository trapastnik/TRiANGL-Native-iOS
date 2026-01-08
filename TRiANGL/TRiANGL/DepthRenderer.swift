import Metal
import MetalKit
import ARKit
import UIKit

class DepthRenderer {
    private var device: MTLDevice
    private var commandQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState?
    private var textureCache: CVMetalTextureCache?
    private var vertexBuffer: MTLBuffer?

    // Full-screen quad vertices (position + texCoord)
    private let quadVertices: [Float] = [
        // Positions       // TexCoords
        -1.0,  1.0,        0.0, 0.0,  // Top left
        -1.0, -1.0,        0.0, 1.0,  // Bottom left
         1.0, -1.0,        1.0, 1.0,  // Bottom right
        -1.0,  1.0,        0.0, 0.0,  // Top left
         1.0, -1.0,        1.0, 1.0,  // Bottom right
         1.0,  1.0,        1.0, 0.0   // Top right
    ]

    init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            print("Metal not supported on this device")
            return nil
        }

        self.device = device
        self.commandQueue = commandQueue

        // Create texture cache for efficient CVPixelBuffer -> MTLTexture conversion
        var cache: CVMetalTextureCache?
        guard CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &cache) == kCVReturnSuccess,
              let textureCache = cache else {
            print("Failed to create texture cache")
            return nil
        }
        self.textureCache = textureCache

        // Create vertex buffer
        let vertexBufferSize = quadVertices.count * MemoryLayout<Float>.stride
        guard let vertexBuffer = device.makeBuffer(bytes: quadVertices,
                                                   length: vertexBufferSize,
                                                   options: []) else {
            print("Failed to create vertex buffer")
            return nil
        }
        self.vertexBuffer = vertexBuffer

        // Setup render pipeline
        setupPipeline()
    }

    private func setupPipeline() {
        guard let library = device.makeDefaultLibrary() else {
            print("Failed to create Metal library")
            return
        }

        let vertexFunction = library.makeFunction(name: "depthVertexShader")
        let fragmentFunction = library.makeFunction(name: "depthFragmentShader")

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        // Enable blending for transparency
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add

        // Setup vertex descriptor
        let vertexDescriptor = MTLVertexDescriptor()
        // Position attribute
        vertexDescriptor.attributes[0].format = .float2
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        // TexCoord attribute
        vertexDescriptor.attributes[1].format = .float2
        vertexDescriptor.attributes[1].offset = MemoryLayout<Float>.stride * 2
        vertexDescriptor.attributes[1].bufferIndex = 0
        // Layout
        vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.stride * 4
        vertexDescriptor.layouts[0].stepFunction = .perVertex

        pipelineDescriptor.vertexDescriptor = vertexDescriptor

        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Failed to create pipeline state: \(error)")
        }
    }

    func render(
        depthMap: CVPixelBuffer,
        to drawable: CAMetalDrawable,
        interfaceOrientation: UIInterfaceOrientation = .portrait,
        minDepth: Float = 1.0,
        maxDepth: Float = 4.0,
        alpha: Float = 0.7,
        displayTransform: CGAffineTransform? = nil
    ) {
        guard let pipelineState = pipelineState,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let depthTexture = createTexture(from: depthMap) else {
            return
        }

        // Calculate transform matrix for proper orientation and alignment
        // Priority: displayTransform (if provided) > orientation transform
        let transformMatrix: simd_float3x3
        if let displayTransform = displayTransform {
            // Use ARFrame's displayTransform for perfect alignment
            transformMatrix = convertCGAffineToSimd(displayTransform)
        } else {
            // Fallback to orientation-based transform
            transformMatrix = getTransformMatrix(for: interfaceOrientation)
        }

        var transform = transformMatrix
        let transformSize = MemoryLayout<simd_float3x3>.stride

        // Depth range parameters
        var depthParams = simd_float4(minDepth, maxDepth, alpha, 0)
        let depthParamsSize = MemoryLayout<simd_float4>.stride

        // Note: Camera intrinsics removed from pipeline
        // displayTransform already provides accurate alignment including camera properties

        // Create render pass
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }

        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBytes(&transform, length: transformSize, index: 1)
        // Intrinsics buffer removed - not needed with displayTransform
        renderEncoder.setFragmentTexture(depthTexture, index: 0)
        renderEncoder.setFragmentBytes(&depthParams, length: depthParamsSize, index: 0)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        renderEncoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func convertCGAffineToSimd(_ transform: CGAffineTransform) -> simd_float3x3 {
        // Convert CGAffineTransform (2D) to simd_float3x3 (3D homogeneous)
        //
        // CGAffineTransform represents matrix:
        // | a  c  tx |
        // | b  d  ty |
        // | 0  0  1  |
        //
        // simd_float3x3 is column-major, so we need to transpose:
        // Column 0: (a, b, 0)
        // Column 1: (c, d, 0)
        // Column 2: (tx, ty, 1)
        return simd_float3x3(
            simd_float3(Float(transform.a), Float(transform.b), 0),
            simd_float3(Float(transform.c), Float(transform.d), 0),
            simd_float3(Float(transform.tx), Float(transform.ty), 1)
        )
    }

    private func getTransformMatrix(for orientation: UIInterfaceOrientation) -> simd_float3x3 {
        // Transform texture coordinates to match interface orientation
        // Portrait: rotate 90° clockwise (sensor is landscape left)
        // LandscapeRight: rotate 180° (sensor upside down)
        // PortraitUpsideDown: rotate 90° counter-clockwise
        // LandscapeLeft: no rotation

        switch orientation {
        case .portrait:
            // Rotate 90° clockwise: (x,y) -> (1-y, x)
            return simd_float3x3(
                simd_float3(0, 1, 0),   // new x = old y
                simd_float3(-1, 0, 1),  // new y = 1 - old x
                simd_float3(0, 0, 1)
            )
        case .portraitUpsideDown:
            // Rotate 90° counter-clockwise: (x,y) -> (y, 1-x)
            return simd_float3x3(
                simd_float3(0, -1, 1),  // new x = 1 - old y
                simd_float3(1, 0, 0),   // new y = old x
                simd_float3(0, 0, 1)
            )
        case .landscapeLeft:
            // Rotate 180°: (x,y) -> (1-x, 1-y)
            return simd_float3x3(
                simd_float3(-1, 0, 1),  // new x = 1 - old x
                simd_float3(0, -1, 1),  // new y = 1 - old y
                simd_float3(0, 0, 1)
            )
        case .landscapeRight:
            // No rotation (identity)
            return simd_float3x3(
                simd_float3(1, 0, 0),
                simd_float3(0, 1, 0),
                simd_float3(0, 0, 1)
            )
        default:
            // Default to portrait
            return simd_float3x3(
                simd_float3(0, 1, 0),
                simd_float3(-1, 0, 1),
                simd_float3(0, 0, 1)
            )
        }
    }

    private func createTexture(from pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        var cvMetalTexture: CVMetalTexture?
        guard let textureCache = textureCache,
              CVMetalTextureCacheCreateTextureFromImage(
                kCFAllocatorDefault,
                textureCache,
                pixelBuffer,
                nil,
                .r32Float,  // Depth is single-channel 32-bit float
                width,
                height,
                0,
                &cvMetalTexture
              ) == kCVReturnSuccess,
              let metalTexture = cvMetalTexture else {
            return nil
        }

        return CVMetalTextureGetTexture(metalTexture)
    }
}
