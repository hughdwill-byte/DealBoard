import SwiftUI

/// Create or join a shared board so friends with the code see the same deals.
/// Everything here is optional — the app works fully offline without it.
struct SharingView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var cloud = CloudSharing.shared
    @State private var joinCode = ""
    @State private var busy = false

    var body: some View {
        NavigationStack {
            Form {
                if !CloudConfig.isConfigured {
                    Section {
                        Label("Cloud sharing isn't set up yet.", systemImage: "icloud.slash")
                            .foregroundStyle(Theme.text)
                        Text("Add your Supabase details in Supabase.plist (see the README) to enable it. The app works fully offline without it.")
                            .font(.footnote).foregroundStyle(Theme.secondaryText)
                    }
                } else if let code = cloud.groupCode {
                    sharedSection(code: code)
                } else {
                    joinOrCreateSection
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Shared Board")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .tint(Theme.accent)
        }
    }

    private var joinOrCreateSection: some View {
        Group {
            Section {
                Button {
                    run { await cloud.createGroup() }
                } label: {
                    Label("Create a shared board", systemImage: "person.2.badge.plus")
                }
                .disabled(busy)
            } footer: {
                Text("Generates a code. Your current deals become the shared board; share the code with friends so they see the same deals.")
            }

            Section {
                TextField("Enter a code", text: $joinCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                Button {
                    run { await cloud.join(code: joinCode) }
                } label: {
                    Label("Join with code", systemImage: "arrow.right.circle")
                }
                .disabled(busy || joinCode.trimmingCharacters(in: .whitespaces).count < 4)
            } footer: {
                Text("Joining merges the board's deals with yours; from then on your changes sync to everyone with the code.")
            }
            statusRow
        }
    }

    private func sharedSection(code: String) -> some View {
        Group {
            Section("Your board code") {
                HStack {
                    Text(code)
                        .font(.system(.title, design: .monospaced).weight(.bold))
                        .foregroundStyle(Theme.accent)
                    Spacer()
                    ShareLink(item: "Join my DealBoard with code \(code)") {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                Text("Anyone who enters this code sees and syncs the same deals.")
                    .font(.footnote).foregroundStyle(Theme.secondaryText)
            }
            Section {
                Button {
                    run { await cloud.syncNow() }
                } label: {
                    Label("Sync now", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(busy)
                Button(role: .destructive) { cloud.leave() } label: {
                    Label("Leave board", systemImage: "person.2.slash")
                }
            } footer: {
                Text("Leaving keeps the deals on this phone but stops syncing. Photos stay on each device — they aren't shared yet.")
            }
            statusRow
        }
    }

    private var statusRow: some View {
        Section {
            switch cloud.status {
            case .idle: EmptyView()
            case .syncing:
                Label("Syncing…", systemImage: "arrow.triangle.2.circlepath")
                    .foregroundStyle(Theme.secondaryText)
            case .synced(let date):
                Label("Last synced \(date.formatted(date: .omitted, time: .shortened))",
                      systemImage: "checkmark.circle")
                    .foregroundStyle(Theme.secondaryText)
            case .error(let message):
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.footnote).foregroundStyle(.red)
            }
        }
    }

    private func run(_ work: @escaping () async -> Void) {
        busy = true
        Task { await work(); busy = false }
    }
}
