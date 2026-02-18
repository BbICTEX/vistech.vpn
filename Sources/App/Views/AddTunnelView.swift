import SwiftUI
import UniformTypeIdentifiers

struct AddTunnelView: View {
    @EnvironmentObject var vpnManager: VPNManager
    @Environment(\.dismiss) private var dismiss

    @State private var tunnelName = ""
    @State private var configText = ""
    @State private var showFilePicker = false
    @State private var showQRScanner = false
    @State private var errorMessage: String?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Tunnel Name") {
                    TextField("My VPN", text: $tunnelName)
                        .autocorrectionDisabled()
                }

                Section("Configuration") {
                    TextEditor(text: $configText)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 200)
                }

                Section {
                    Button {
                        showFilePicker = true
                    } label: {
                        Label("Import from File", systemImage: "doc")
                    }

                    Button {
                        showQRScanner = true
                    } label: {
                        Label("Scan QR Code", systemImage: "qrcode.viewfinder")
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Add Tunnel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTunnel()
                    }
                    .disabled(configText.isEmpty || isSaving)
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [UTType(filenameExtension: "conf") ?? .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .sheet(isPresented: $showQRScanner) {
                QRScannerView { scannedText in
                    configText = scannedText
                    showQRScanner = false
                }
            }
        }
    }

    private func saveTunnel() {
        isSaving = true
        errorMessage = nil

        let name = tunnelName.isEmpty ? "Tunnel \(vpnManager.tunnels.count + 1)" : tunnelName

        do {
            let config = try WgQuickParser.parse(configText, name: name)
            Task {
                do {
                    try await vpnManager.addTunnel(config)
                    dismiss()
                } catch {
                    errorMessage = error.localizedDescription
                    isSaving = false
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Cannot access file"
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                configText = try String(contentsOf: url, encoding: .utf8)
                if tunnelName.isEmpty {
                    tunnelName = url.deletingPathExtension().lastPathComponent
                }
            } catch {
                errorMessage = "Failed to read file: \(error.localizedDescription)"
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}
