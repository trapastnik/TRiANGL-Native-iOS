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

    func render(depthMap: CVPixelBuffer, to drawable: CAMetalDrawable) {
        guard let pipelineState = pipelineState,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let depthTexture = createTexture(from: depthMap) else {
            return
        }

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
        renderEncoder.setFragmentTexture(depthTexture, index: 0)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        renderEncoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
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
