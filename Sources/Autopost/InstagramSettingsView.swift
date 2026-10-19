import SwiftUI

private let setupGuideURL = URL(string: "https://developers.facebook.com/docs/instagram-platform/instagram-api-with-instagram-login")!

/// Settings tab where the user pastes a token so the phone preview shows their real profile.
struct InstagramSettingsView: View {
    @Environment(InstagramAccount.self) private var account
    @State private var token = ""

    var body: some View {
        Form {
            Section {
                status
                if let message = account.failureMessage {
                    Text(message).foregroundStyle(.red)
                }
            }

            Section {
                SecureField("Access token", text: $token)
                HStack {
                    Button("Connect") {
                        Task {
                            await account.connect(token: token)
                            if account.failureMessage == nil { token = "" }
                        }
                    }
                    .disabled(token.isEmpty || account.isLoading)

                    if account.isConnected {
                        Button("Refresh") { Task { await account.reload() } }
                            .disabled(account.isLoading)
                        Button("Disconnect", role: .destructive) { account.disconnect() }
                            .disabled(account.isLoading)
                    }
                }
            }

            Section {
                Text("This only works for a Business or Creator account. Create an app in the Meta developer dashboard, add the Instagram product, add your account as an Instagram tester and accept the invite, then click Generate token next to your account and paste it here. The token stays in your Keychain and renews itself while you use the app.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Link("Instagram API with Instagram Login", destination: setupGuideURL)
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private var status: some View {
        if account.isLoading {
            HStack {
                ProgressView().controlSize(.small)
                Text("Loading from Instagram…")
            }
        } else if let profile = account.profile {
            Text("Connected as @\(profile.username), \(account.media.count) recent posts loaded.")
        } else {
            Text("Not connected. The phone preview uses the handle you type there.")
        }
    }
}
