import Foundation

struct TunnelConfig: Identifiable, Codable {
    let id: UUID
    var name: String
    var interface: InterfaceConfig
    var peers: [PeerConfig]

    init(name: String, interface: InterfaceConfig, peers: [PeerConfig]) {
        self.id = UUID()
        self.name = name
        self.interface = interface
        self.peers = peers
    }
}

struct InterfaceConfig: Codable {
    var privateKey: String
    var address: [String]
    var dns: [String]
    var mtu: Int?
    var listenPort: Int?
}

struct PeerConfig: Codable {
    var publicKey: String
    var presharedKey: String?
    var endpoint: String?
    var allowedIPs: [String]
    var persistentKeepalive: Int?
}

extension TunnelConfig {
    /// Serialize back to wg-quick .conf format
    func toWgQuickConfig() -> String {
        var lines = [String]()

        lines.append("[Interface]")
        lines.append("PrivateKey = \(interface.privateKey)")
        lines.append("Address = \(interface.address.joined(separator: ", "))")
        if !interface.dns.isEmpty {
            lines.append("DNS = \(interface.dns.joined(separator: ", "))")
        }
        if let mtu = interface.mtu {
            lines.append("MTU = \(mtu)")
        }
        if let listenPort = interface.listenPort {
            lines.append("ListenPort = \(listenPort)")
        }

        for peer in peers {
            lines.append("")
            lines.append("[Peer]")
            lines.append("PublicKey = \(peer.publicKey)")
            if let psk = peer.presharedKey {
                lines.append("PresharedKey = \(psk)")
            }
            if let endpoint = peer.endpoint {
                lines.append("Endpoint = \(endpoint)")
            }
            lines.append("AllowedIPs = \(peer.allowedIPs.joined(separator: ", "))")
            if let keepalive = peer.persistentKeepalive {
                lines.append("PersistentKeepalive = \(keepalive)")
            }
        }

        return lines.joined(separator: "\n") + "\n"
    }
}
