import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vpnManager: VPNManager

    var body: some View {
        NavigationStack {
            TunnelListView()
                .navigationTitle("ВЫСТЕХ.VPN")
        }
        .task {
            await vpnManager.loadTunnels()
        }
    }
}
