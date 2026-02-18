import SwiftUI

struct TunnelDetailView: View {
    let tunnel: TunnelInfo
    @EnvironmentObject var vpnManager: VPNManager

    private var isActive: Bool {
        vpnManager.activeTunnelId == tunnel.id
    }

    private var isConnected: Bool {
        isActive && vpnManager.connectionStatus == .connected
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Status")
                    Spacer()
                    Text(isActive ? vpnManager.connectionStatus.displayText : "Disconnected")
                        .foregroundStyle(isActive ? vpnManager.connectionStatus.color : .secondary)
                }

                Toggle("Connect", isOn: Binding(
                    get: { isConnected },
                    set: { newValue in
                        Task {
                            if newValue {
                                await vpnManager.connect(tunnel)
                            } else {
                                await vpnManager.disconnect()
                            }
                        }
                    }
                ))
            }

            Section("Interface") {
                DetailRow(label: "Address", value: tunnel.config.interface.address.joined(separator: ", "))
                DetailRow(label: "DNS", value: tunnel.config.interface.dns.joined(separator: ", "))
                if let mtu = tunnel.config.interface.mtu {
                    DetailRow(label: "MTU", value: "\(mtu)")
                }
            }

            ForEach(Array(tunnel.config.peers.enumerated()), id: \.offset) { index, peer in
                Section("Peer \(index + 1)") {
                    DetailRow(label: "Public Key", value: String(peer.publicKey.prefix(20)) + "...")
                    if let endpoint = peer.endpoint {
                        DetailRow(label: "Endpoint", value: endpoint)
                    }
                    DetailRow(label: "Allowed IPs", value: peer.allowedIPs.joined(separator: ", "))
                    if let keepalive = peer.persistentKeepalive {
                        DetailRow(label: "Keepalive", value: "\(keepalive)s")
                    }
                }
            }
        }
        .navigationTitle(tunnel.name)
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }
}
