import Foundation
import NetworkExtension
import Combine

enum ConnectionStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case disconnecting
    case error(String)

    var displayText: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .disconnecting: return "Disconnecting..."
        case .error(let msg): return "Error: \(msg)"
        }
    }

    var color: SwiftUI.Color {
        switch self {
        case .connected: return .green
        case .connecting, .disconnecting: return .orange
        case .disconnected: return .secondary
        case .error: return .red
        }
    }
}

import SwiftUI

struct TunnelInfo: Identifiable {
    let id: UUID
    let name: String
    let config: TunnelConfig
    let manager: NETunnelProviderManager
}

@MainActor
class VPNManager: ObservableObject {
    @Published var tunnels: [TunnelInfo] = []
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var activeTunnelId: UUID?

    private var statusObserver: AnyCancellable?

    private static let bundleIdExtension = "com.vystech.vpn.network-extension"
    private static let appGroup = "group.com.vystech.vpn"

    init() {
        observeVPNStatus()
    }

    // MARK: - Load

    func loadTunnels() async {
        do {
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()
            tunnels = managers.compactMap { manager -> TunnelInfo? in
                guard let proto = manager.protocolConfiguration as? NETunnelProviderProtocol,
                      let wgConfig = proto.providerConfiguration?["wgQuickConfig"] as? String,
                      let config = try? WgQuickParser.parse(wgConfig, name: manager.localizedDescription ?? "Unnamed")
                else { return nil }

                return TunnelInfo(
                    id: UUID(),
                    name: manager.localizedDescription ?? "Unnamed",
                    config: config,
                    manager: manager
                )
            }
            updateActiveStatus()
        } catch {
            print("Failed to load tunnels: \(error)")
        }
    }

    // MARK: - Add

    func addTunnel(_ config: TunnelConfig) async throws {
        let manager = NETunnelProviderManager()
        manager.localizedDescription = config.name

        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = Self.bundleIdExtension
        proto.serverAddress = config.peers.first?.endpoint ?? "Unknown"
        proto.providerConfiguration = [
            "wgQuickConfig": config.toWgQuickConfig()
        ]

        manager.protocolConfiguration = proto
        manager.isEnabled = true

        try await manager.saveToPreferences()
        try await manager.loadFromPreferences()

        let info = TunnelInfo(
            id: UUID(),
            name: config.name,
            config: config,
            manager: manager
        )
        tunnels.append(info)
    }

    // MARK: - Remove

    func removeTunnel(_ tunnel: TunnelInfo) async {
        do {
            try await tunnel.manager.removeFromPreferences()
            tunnels.removeAll { $0.id == tunnel.id }
            if activeTunnelId == tunnel.id {
                activeTunnelId = nil
                connectionStatus = .disconnected
            }
        } catch {
            print("Failed to remove tunnel: \(error)")
        }
    }

    // MARK: - Connect / Disconnect

    func connect(_ tunnel: TunnelInfo) async {
        do {
            try await tunnel.manager.loadFromPreferences()
            tunnel.manager.isEnabled = true
            try await tunnel.manager.saveToPreferences()

            let session = tunnel.manager.connection as! NETunnelProviderSession
            try session.startVPNTunnel()
            activeTunnelId = tunnel.id
            connectionStatus = .connecting
        } catch {
            connectionStatus = .error(error.localizedDescription)
        }
    }

    func disconnect() async {
        guard let tunnel = tunnels.first(where: { $0.id == activeTunnelId }) else { return }
        tunnel.manager.connection.stopVPNTunnel()
        connectionStatus = .disconnecting
    }

    // MARK: - Status Observation

    private func observeVPNStatus() {
        statusObserver = NotificationCenter.default
            .publisher(for: .NEVPNStatusDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let connection = notification.object as? NEVPNConnection else { return }
                self?.handleStatusChange(connection.status)
            }
    }

    private func handleStatusChange(_ status: NEVPNStatus) {
        switch status {
        case .connected:
            connectionStatus = .connected
        case .connecting:
            connectionStatus = .connecting
        case .disconnecting:
            connectionStatus = .disconnecting
        case .disconnected:
            connectionStatus = .disconnected
            activeTunnelId = nil
        case .invalid:
            connectionStatus = .error("Invalid configuration")
        case .reasserting:
            connectionStatus = .connecting
        @unknown default:
            connectionStatus = .disconnected
        }
    }

    private func updateActiveStatus() {
        for tunnel in tunnels {
            let status = tunnel.manager.connection.status
            if status == .connected || status == .connecting {
                activeTunnelId = tunnel.id
                handleStatusChange(status)
                break
            }
        }
    }
}
