import SwiftUI

struct ContentView: View {
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    @State private var totalFreed: Int64 = 0
    @State private var isScanning = false
    @State private var licenseValid = false
    
    var body: some View {
        NavigationSplitView {
            List {
                NavigationLink("Dashboard", destination: dashboardView)
                NavigationLink("Caches (Tier 1)", destination: Text("Caches"))
                NavigationLink("Review (Tier 2)", destination: Text("Review Required"))
                NavigationLink("License", destination: Text("License Management"))
            }
            .navigationTitle("DiskPrune")
        } detail: {
            dashboardView
        }
        .background(
            reduceTransparency ? 
            AnyView(Color(nsColor: .windowBackgroundColor)) : 
            AnyView(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
        )
    }
    
    private var dashboardView: some View {
        VStack(spacing: 20) {
            Text("DiskPrune Suite")
                .font(.largeTitle)
                .bold()
            
            VStack {
                Text("Space Freed")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text(ByteCountFormatter.string(fromByteCount: totalFreed, countStyle: .file))
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .monospacedDigit()
            }
            .padding()
            
            Button(action: {
                isScanning = true
                Task {
                    let scanner = ScannerActor()
                    let _ = await scanner.scanSafeTier()
                    // Simulation of scanning delay
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    isScanning = false
                }
            }) {
                Text(isScanning ? "Scanning..." : "Start Scan")
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
            }
            .disabled(isScanning)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
