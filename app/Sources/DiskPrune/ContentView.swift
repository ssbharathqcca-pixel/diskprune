import SwiftUI

struct ContentView: View {
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    @State private var totalFreed: Int64 = 0
    @State private var isScanning = false
    @State private var isPurging = false
    @State private var scannedURLs: [URL] = []
    @State private var showLicenseSheet = false
    @State private var licenseKey = ""
    @State private var activationError = false
    
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
        .sheet(isPresented: $showLicenseSheet) {
            VStack(spacing: 20) {
                Text("License Required")
                    .font(.title)
                    .bold()
                Text("Scanning is free, but purging requires a valid license.")
                    .multilineTextAlignment(.center)
                
                TextField("Enter License Key", text: $licenseKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 300)
                
                if activationError {
                    Text("Invalid license key.")
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                HStack {
                    Button("Cancel") {
                        showLicenseSheet = false
                        activationError = false
                    }
                    Button("Activate") {
                        Task {
                            let valid = try? await LicenseManager.shared.activate(licenseKey: licenseKey)
                            if valid == true {
                                showLicenseSheet = false
                                activationError = false
                                // proceed with purge if needed
                            } else {
                                activationError = true
                            }
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                }
                
                Divider().frame(width: 200)
                
                Button("Buy License ($19)") {
                    if let url = URL(string: "https://buy.stripe.com/eVqeVc8nd9wx39efNdaR200") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(LinkButtonStyle())
            }
            .padding(40)
            .frame(width: 400)
        }
    }
    
    private var dashboardView: some View {
        VStack(spacing: 20) {
            Text("DiskPrune Suite")
                .font(.largeTitle)
                .bold()
            
            VStack {
                Text("Space Found to Free")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text(ByteCountFormatter.string(fromByteCount: totalFreed, countStyle: .file))
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .monospacedDigit()
            }
            .padding()
            
            HStack(spacing: 16) {
                Button(action: {
                    isScanning = true
                    Task {
                        let scanner = ScannerActor()
                        scannedURLs = await scanner.scanSafeTier()
                        totalFreed = 0 // would calculate size here in reality
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        isScanning = false
                    }
                }) {
                    Text(isScanning ? "Scanning..." : "Start Scan")
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                }
                .disabled(isScanning || isPurging)
                
                Button(action: {
                    if LicenseManager.shared.isActivated {
                        isPurging = true
                        Task {
                            let scanner = ScannerActor()
                            try? await scanner.trash(urls: scannedURLs)
                            scanner.flushAPFSSnapshots()
                            scannedURLs.removeAll()
                            totalFreed = 0
                            isPurging = false
                        }
                    } else {
                        showLicenseSheet = true
                    }
                }) {
                    Text(isPurging ? "Purging..." : "Purge")
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                }
                .disabled(isScanning || isPurging || scannedURLs.isEmpty)
            }
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
