//
//  ContentView.swift
//  AsaPapaARCube
//  
//  Created on 2025/04/30
//


import SwiftUI
import RealityKit
import ARKit

struct ContentView: View {
    @State private var isPlacementEnabled = false
    @State private var showAlert = false
    
    var body: some View {
        ZStack {
            ARViewContainer(isPlacementEnabled: $isPlacementEnabled, showAlert: $showAlert)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                Text("AsaPapa AR Cube")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                
                Spacer()
                
                Button(action: { isPlacementEnabled.toggle() }) {
                    Text(isPlacementEnabled ? "配置停止" : "キューブを置く")
                        .font(.system(size: 18, design: .rounded))
                        .padding()
                        .background(isPlacementEnabled ? Color.red : Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                .padding()
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("エラー"), message: Text("テーブルを見つけてね！"), dismissButton: .default(Text("OK")))
        }
        .background(Color.blue.opacity(0.1))
    }
}

struct ARViewContainer: UIViewRepresentable {
    @Binding var isPlacementEnabled: Bool
    @Binding var showAlert: Bool
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        arView.session.run(config)
        arView.debugOptions = [.showAnchorGeometry]
        
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(isPlacementEnabled: $isPlacementEnabled, showAlert: $showAlert)
    }
    
    class Coordinator {
        @Binding var isPlacementEnabled: Bool
        @Binding var showAlert: Bool
        
        init(isPlacementEnabled: Binding<Bool>, showAlert: Binding<Bool>) {
            _isPlacementEnabled = isPlacementEnabled
            _showAlert = showAlert
        }
        
        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard isPlacementEnabled, let arView = recognizer.view as? ARView else { return }
            let location = recognizer.location(in: arView)
            let results = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .horizontal)
            
            if let firstResult = results.first {
                let anchor = AnchorEntity(world: firstResult.worldTransform)
                let cube = ModelEntity(mesh: .generateBox(size: 0.1), materials: [SimpleMaterial(color: .red, isMetallic: false)])
                anchor.addChild(cube)
                arView.scene.addAnchor(anchor)
            } else {
                showAlert = true
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
