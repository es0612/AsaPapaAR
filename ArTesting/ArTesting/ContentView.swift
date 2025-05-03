import SwiftUI
import ARKit
import MetalKit

struct ContentView: View {
    @StateObject private var arViewModel = ARViewModel()

    var body: some View {
        ZStack {
            ARViewRepresentable(viewModel: arViewModel)
                .ignoresSafeArea()
            
            VStack {
                Text("LiDAR Depth Map")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding()
                
                Button(action: {
                    arViewModel.toggleSession()
                }) {
                    Text(arViewModel.isRunning ? "Stop AR" : "Start AR")
                        .font(.headline)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
    }
}

struct ARViewRepresentable: UIViewRepresentable {
    let viewModel: ARViewModel
    
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.delegate = context.coordinator
        viewModel.setupMetal(mtkView: mtkView)
        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        let viewModel: ARViewModel
        
        init(viewModel: ARViewModel) {
            self.viewModel = viewModel
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
        
        func draw(in view: MTKView) {
            viewModel.draw(in: view)
        }
    }
}
