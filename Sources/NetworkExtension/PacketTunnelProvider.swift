import NetworkExtension
import Network
import WireGuardKit

class PacketTunnelProvider: NEPacketTunnelProvider {

    private lazy var adapter: WireGuardAdapter = {
        WireGuardAdapter(with: self) { logLevel, message in
            NSLog("WireGuard: [\(logLevel)] \(message)")
        }
    }()

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        guard let protocolConfig = protocolConfiguration as? NETunnelProviderProtocol,
              let wgConfig = protocolConfig.providerConfiguration?["wgQuickConfig"] as? String else {
            completionHandler(PacketTunnelError.missingConfig)
            return
        }

        let tunnelConfig: TunnelConfiguration
        do {
            let parsed = try WgQuickParser.parse(wgConfig, name: "tunnel")
            tunnelConfig = try parsed.toWireGuardKitConfig()
        } catch {
            NSLog("WireGuard: Failed to parse config: \(error)")
            completionHandler(error)
            return
        }

        adapter.start(tunnelConfiguration: tunnelConfig) { adapterError in
            if let adapterError = adapterError {
                NSLog("WireGuard: Failed to start adapter: \(adapterError)")
                completionHandler(adapterError)
            } else {
                completionHandler(nil)
            }
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        adapter.stop { error in
            if let error = error {
                NSLog("WireGuard: Failed to stop adapter: \(error)")
            }
            completionHandler()
        }
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        if let handler = completionHandler {
            adapter.getRuntimeConfiguration { config in
                handler(config?.data(using: .utf8))
            }
        }
    }
}

enum PacketTunnelError: LocalizedError {
    case missingConfig
    case invalidKey(String)

    var errorDescription: String? {
        switch self {
        case .missingConfig: return "WireGuard config not found in provider configuration"
        case .invalidKey(let detail): return "Invalid key: \(detail)"
        }
    }
}
