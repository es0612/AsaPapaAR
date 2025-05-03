import ARKit
import MetalKit
import Combine

class ARViewModel: NSObject, ObservableObject, ARSessionDelegate {
    @Published var isRunning = false
    private var session = ARSession()
    private var device: MTLDevice!
    private var renderPipelineState: MTLRenderPipelineState!
    private var depthTexture: MTLTexture?
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        session.delegate = self
    }
    
    func setupMetal(mtkView: MTKView) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal device creation failed")
        }
        self.device = device
        mtkView.device = device
        mtkView.colorPixelFormat = .bgra8Unorm
        
        guard let library = device.makeDefaultLibrary(),
              let vertexFunction = library.makeFunction(name: "vertexShader"),
              let fragmentFunction = library.makeFunction(name: "fragmentShader") else {
            fatalError("Failed to load Metal library or functions")
        }
        
        // 頂点記述子の作成
        let vertexDescriptor = MTLVertexDescriptor()
        
        // 属性0: position (float4)
        vertexDescriptor.attributes[0].format = .float4
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        
        // 属性1: texCoord (float2)
        vertexDescriptor.attributes[1].format = .float2
        vertexDescriptor.attributes[1].offset = MemoryLayout<Float>.size * 4 // float4の後
        vertexDescriptor.attributes[1].bufferIndex = 0
        
        // レイアウト: 頂点バッファのストライド
        vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.size * 6 // float4 + float2
        vertexDescriptor.layouts[0].stepFunction = .perVertex
        vertexDescriptor.layouts[0].stepRate = 1
        
        // パイプラインデスクリプタの設定
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        pipelineDescriptor.vertexDescriptor = vertexDescriptor // 頂点記述子を設定
        
        do {
            renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError("Render pipeline creation failed: \(error.localizedDescription)")
        }
    }
    
    func toggleSession() {
        if isRunning {
            session.pause()
            isRunning = false
        } else {
            let configuration = ARWorldTrackingConfiguration()
            if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
                configuration.frameSemantics = .sceneDepth
            }
            session.run(configuration)
            isRunning = true
        }
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard let depthData = frame.sceneDepth?.depthMap else { return }
        
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r32Float,
            width: CVPixelBufferGetWidth(depthData),
            height: CVPixelBufferGetHeight(depthData),
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead]
        
        guard let texture = device.makeTexture(descriptor: textureDescriptor) else { return }
        
        let region = MTLRegionMake2D(0, 0, textureDescriptor.width, textureDescriptor.height)
        CVPixelBufferLockBaseAddress(depthData, .readOnly)
        if let baseAddress = CVPixelBufferGetBaseAddress(depthData) {
            texture.replace(region: region, mipmapLevel: 0, withBytes: baseAddress, bytesPerRow: CVPixelBufferGetBytesPerRow(depthData))
        }
        CVPixelBufferUnlockBaseAddress(depthData, .readOnly)
        
        self.depthTexture = texture
    }
    
    func draw(in view: MTKView) {
        // 必須リソースの確認
        guard let drawable = view.currentDrawable,
              let commandBuffer = device.makeCommandQueue()?.makeCommandBuffer(),
              let renderPassDescriptor = view.currentRenderPassDescriptor else {
            return
        }
        
        // エンコーダの作成
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        // 深度テクスチャの確認
        guard let depthTexture = depthTexture else {
            encoder.endEncoding() // エンコーダを終了
            return
        }
        
        // レンダリングパイプラインとテクスチャの設定
        encoder.setRenderPipelineState(renderPipelineState)
        encoder.setFragmentTexture(depthTexture, index: 0)
        
        // 頂点データの設定
        let vertices: [Float] = [
            -1, -1, 0, 1, 0, 1,
             1, -1, 0, 1, 1, 1,
            -1,  1, 0, 1, 0, 0,
             1,  1, 0, 1, 1, 0
        ]
        let vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Float>.size, options: [])
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        // 描画コマンド
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        
        // 描画のコミット
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
