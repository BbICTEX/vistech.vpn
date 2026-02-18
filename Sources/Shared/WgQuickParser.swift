import Foundation

enum WgQuickParserError: LocalizedError {
    case invalidFormat(String)
    case missingPrivateKey
    case missingPublicKey
    case missingAddress

    var errorDescription: String? {
        switch self {
        case .invalidFormat(let detail): return "Invalid config: \(detail)"
        case .missingPrivateKey: return "Missing PrivateKey in [Interface]"
        case .missingPublicKey: return "Missing PublicKey in [Peer]"
        case .missingAddress: return "Missing Address in [Interface]"
        }
    }
}

struct WgQuickParser {
    static func parse(_ config: String, name: String = "Unnamed") throws -> TunnelConfig {
        var interfaceConfig: InterfaceConfig?
        var peers = [PeerConfig]()

        var currentSection: String?
        var currentDict = [String: String]()

        let lines = config.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }

            if trimmed.lowercased() == "[interface]" {
                if let section = currentSection {
                    try commitSection(section, dict: currentDict, interface: &interfaceConfig, peers: &peers)
                }
                currentSection = "interface"
                currentDict = [:]
                continue
            }

            if trimmed.lowercased() == "[peer]" {
                if let section = currentSection {
                    try commitSection(section, dict: currentDict, interface: &interfaceConfig, peers: &peers)
                }
                currentSection = "peer"
                currentDict = [:]
                continue
            }

            guard let eqIndex = trimmed.firstIndex(of: "=") else { continue }
            let key = trimmed[trimmed.startIndex..<eqIndex].trimmingCharacters(in: .whitespaces).lowercased()
            let value = trimmed[trimmed.index(after: eqIndex)...].trimmingCharacters(in: .whitespaces)
            currentDict[key] = value
        }

        if let section = currentSection {
            try commitSection(section, dict: currentDict, interface: &interfaceConfig, peers: &peers)
        }

        guard let iface = interfaceConfig else {
            throw WgQuickParserError.invalidFormat("No [Interface] section")
        }

        return TunnelConfig(name: name, interface: iface, peers: peers)
    }

    private static func commitSection(
        _ section: String,
        dict: [String: String],
        interface: inout InterfaceConfig?,
        peers: inout [PeerConfig]
    ) throws {
        if section == "interface" {
            guard let privateKey = dict["privatekey"], !privateKey.isEmpty else {
                throw WgQuickParserError.missingPrivateKey
            }
            guard let address = dict["address"], !address.isEmpty else {
                throw WgQuickParserError.missingAddress
            }

            interface = InterfaceConfig(
                privateKey: privateKey,
                address: splitCSV(address),
                dns: splitCSV(dict["dns"] ?? ""),
                mtu: dict["mtu"].flatMap(Int.init),
                listenPort: dict["listenport"].flatMap(Int.init)
            )
        } else if section == "peer" {
            guard let publicKey = dict["publickey"], !publicKey.isEmpty else {
                throw WgQuickParserError.missingPublicKey
            }

            let peer = PeerConfig(
                publicKey: publicKey,
                presharedKey: dict["presharedkey"],
                endpoint: dict["endpoint"],
                allowedIPs: splitCSV(dict["allowedips"] ?? "0.0.0.0/0"),
                persistentKeepalive: dict["persistentkeepalive"].flatMap(Int.init)
            )
            peers.append(peer)
        }
    }

    private static func splitCSV(_ value: String) -> [String] {
        value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}
