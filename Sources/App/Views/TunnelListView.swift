import SwiftUI

struct TunnelListView: View {
    @EnvironmentObject var vpnManager: VPNManager
    @State private var showAddTunnel = false

    var body: some View {
        tunnelContent
            .navigationBarItems(trailing: addButton)
            .sheet(isPresented: $showAddTunnel) {
                AddTunnelView()
            }
    }

    @ViewBuilder
    private var tunnelContent: some View {
        if vpnManager.tunnels.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "network.slash")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("No Tunnels")
                    .font(.title2.bold())
                Text("Import a WireGuard config to get started.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(vpnManager.tunnels) { tunnel in
                    NavigationLink(destination: TunnelDetailView(tunnel: tunnel)) {
                        TunnelRow(tunnel: tunnel)
                    }
                }
                .onDelete { indexSet in
                    Task {
                        for index in indexSet {
                            await vpnManager.removeTunnel(vpnManager.tunnels[index])
                        }
                    }
                }
            }
        }
    }

    private var addButton: some View {
        Button(action: { showAddTunnel = true }) {
            Image(systemName: "plus")
        }
    }
}

struct TunnelRow: View {
    let tunnel: TunnelInfo
    @EnvironmentObject var vpnManager: VPNManager

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(tunnel.name)
                    .font(.headline)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(statusColor)
            }
            Spacer()
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
        }
        .padding(.vertical, 4)
    }

    private var statusText: String {
        if vpnManager.activeTunnelId == tunnel.id {
            return vpnManager.connectionStatus.displayText
        }
        return "Disconnected"
    }

    private var statusColor: Color {
        if vpnManager.activeTunnelId == tunnel.id {
            return vpnManager.connectionStatus.color
        }
        return .secondary
    }
}
