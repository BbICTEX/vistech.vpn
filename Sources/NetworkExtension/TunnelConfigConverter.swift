import Foundation
import Network
import WireGuardKit

extension TunnelConfig {
    func toWireGuardKitConfig() throws -> TunnelConfiguration {
        guard let privateKey = PrivateKey(base64Key: interface.privateKey) else {
            throw PacketTunnelError.invalidKey("Invalid private key")
        }

        var wgInterface = InterfaceConfiguration(privateKey: privateKey)
        wgInterface.addresses = interface.address.compactMap { IPAddressRange(from: $0) }
        wgInterface.dns = interface.dns.compactMap { DNSServer(from: $0) }
        wgInterface.mtu = interface.mtu.map { UInt16($0) }
        wgInterface.listenPort = interface.listenPort.map { UInt16($0) }

        let wgPeers: [PeerConfiguration] = try peers.map { peer in
            guard let pubKey = PublicKey(base64Key: peer.publicKey) else {
                throw PacketTunnelError.invalidKey("Invalid public key: \(peer.publicKey.prefix(8))...")
            }

            var wgPeer = PeerConfiguration(publicKey: pubKey)
            wgPeer.allowedIPs = peer.allowedIPs.compactMap { IPAddressRange(from: $0) }

            if let endpointStr = peer.endpoint {
                wgPeer.endpoint = Endpoint(from: endpointStr)
            }
            if let psk = peer.presharedKey {
                wgPeer.preSharedKey = PreSharedKey(base64Key: psk)
            }
            if let keepalive = peer.persistentKeepalive {
                wgPeer.persistentKeepAlive = UInt16(keepalive)
            }
            return wgPeer
        }

        return TunnelConfiguration(name: name, interface: wgInterface, peers: wgPeers)
    }
}
