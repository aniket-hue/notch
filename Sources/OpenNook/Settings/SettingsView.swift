import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: Settings
    let registry: WidgetRegistry
    let clipboard: ClipboardService
    let github: GitHubService

    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label { Text("General") } icon: { Icon(.settings, size: 15) } }
            AppearanceTab(settings: settings)
                .tabItem { Label { Text("Appearance") } icon: { Icon(.appearance, size: 15) } }
            WidgetsTab(settings: settings, registry: registry)
                .tabItem { Label { Text("Widgets") } icon: { Icon(.widgets, size: 15) } }
            ClipboardTab(settings: settings, clipboard: clipboard)
                .tabItem { Label { Text("Clipboard") } icon: { Icon(.clipboard, size: 15) } }
            GitHubTab(github: github)
                .tabItem { Label { Text("GitHub") } icon: { Icon(.git, size: 15) } }
            AboutTab()
                .tabItem { Label { Text("About") } icon: { Icon(.info, size: 15) } }
        }
        .frame(width: 500, height: 380)
    }
}

private struct GitHubTab: View {
    @ObservedObject var github: GitHubService
    @State private var token = ""
    @State private var reveal = false

    var body: some View {
        Form {
            Section {
                HStack(spacing: 8) {
                    Group {
                        if reveal {
                            TextField("ghp_…", text: $token)
                        } else {
                            SecureField("ghp_…", text: $token)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    Button {
                        reveal.toggle()
                    } label: {
                        Icon(reveal ? .eyeSlash : .eye, size: 15)
                            .foregroundStyle(.secondary)
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.borderless)
                    .help(reveal ? "Hide token" : "Show token")
                }

                HStack {
                    Button("Save") { github.setToken(token) }
                        .keyboardShortcut(.defaultAction)
                        .disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if github.hasToken {
                        Button("Remove", role: .destructive) {
                            github.setToken("")
                            token = ""
                        }
                    }
                    Spacer()
                    status
                }
            } header: {
                Text("Personal access token")
            } footer: {
                Text("Stored in your macOS keychain, sent only to api.github.com. Use a classic token with “repo”, or a fine-grained token with Pull requests: read.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Link("Create a token on GitHub", destination: URL(string: "https://github.com/settings/tokens")!)
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private var status: some View {
        switch github.status {
        case .ready:
            HStack(spacing: 5) {
                Circle().fill(.green).frame(width: 7, height: 7)
                Text("Connected").font(.caption).foregroundStyle(.secondary)
            }
        case .loading:
            HStack(spacing: 5) {
                ProgressView().controlSize(.small).scaleEffect(0.7)
                Text("Checking…").font(.caption).foregroundStyle(.secondary)
            }
        case let .error(message):
            Text(message).font(.caption).foregroundStyle(.red).lineLimit(1)
        case .needsToken:
            EmptyView()
        }
    }
}

private struct GeneralTab: View {
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        Form {
            Section {
                Toggle("Launch OpenNook at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        LaunchAtLogin.set(newValue)
                        launchAtLogin = LaunchAtLogin.isEnabled
                    }
            } footer: {
                Text("OpenNook starts automatically and lives in the menu bar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct AppearanceTab: View {
    @ObservedObject var settings: Settings

    var body: some View {
        Form {
            Section("Style") {
                Picker("Surface", selection: $settings.appearance) {
                    ForEach(Appearance.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)

                if settings.appearance == .glass {
                    Slider(value: $settings.glassTint, in: 0 ... 0.5) {
                        Text("Tint")
                    } minimumValueLabel: {
                        Text("Clear").font(.caption2).foregroundStyle(.secondary)
                    } maximumValueLabel: {
                        Text("Dark").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }

            Section("Accent") {
                HStack(spacing: 10) {
                    ForEach(AccentChoice.allCases) { choice in
                        Button {
                            settings.accent = choice
                        } label: {
                            Circle()
                                .fill(choice.color)
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Circle()
                                        .strokeBorder(.white.opacity(settings.accent == choice ? 0.95 : 0), lineWidth: 2)
                                        .padding(-3),
                                )
                                .shadow(color: choice.color.opacity(settings.accent == choice ? 0.6 : 0), radius: 5)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(.black))
                .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
            }
        }
        .formStyle(.grouped)
    }
}

private struct WidgetsTab: View {
    @ObservedObject var settings: Settings
    let registry: WidgetRegistry

    private var available: [String] {
        registry.availableIDs
    }

    private var pages: [[String]] {
        settings.reconciled(available: available)
    }

    private var hidden: [String] {
        settings.hiddenChips(available: available)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Drag a widget between pages to regroup. Wider pages widen the notch.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    pageCard(index: index, ids: page)
                }

                addPageZone(newIndex: pages.count)
                hiddenTray
            }
            .padding(16)
        }
    }

    private func chip(_ id: String) -> some View {
        HStack(spacing: 6) {
            Icon(.grip, size: 11).foregroundStyle(.tertiary)
            Text(registry.title(for: id)).font(.system(size: 13))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(.quaternary, lineWidth: 0.5))
        .draggable(id)
    }

    private func pageCard(index: Int, ids: [String]) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text("Page \(index + 1)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)
            HStack(spacing: 8) {
                ForEach(ids, id: \.self) { chip($0) }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.035)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.quaternary, lineWidth: 0.5))
        .dropDestination(for: String.self) { items, _ in
            guard let id = items.first else { return false }
            settings.moveToPage(id, page: index, available: available)
            return true
        }
    }

    private func addPageZone(newIndex: Int) -> some View {
        Text("＋ Add page")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(.quaternary),
            )
            .dropDestination(for: String.self) { items, _ in
                guard let id = items.first else { return false }
                settings.moveToPage(id, page: newIndex, available: available)
                return true
            }
    }

    private var hiddenTray: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HIDDEN")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(.tertiary)
            if hidden.isEmpty {
                Text("Drag a widget here to hide it.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                HStack(spacing: 8) {
                    ForEach(hidden, id: \.self) { chip($0).opacity(0.6) }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.02)))
        .dropDestination(for: String.self) { items, _ in
            guard let id = items.first else { return false }
            settings.moveToHidden(id, available: available)
            return true
        }
    }
}

private struct ClipboardTab: View {
    @ObservedObject var settings: Settings
    let clipboard: ClipboardService

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("History size")
                        Spacer()
                        Text("\(settings.clipboardLimit) items")
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: Binding(
                            get: { Double(settings.clipboardLimit) },
                            set: { settings.clipboardLimit = Int($0) },
                        ),
                        in: 10 ... 100, step: 5,
                    )
                }
            } footer: {
                Text("How many recent copies OpenNook keeps.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button(role: .destructive) {
                    clipboard.clear()
                } label: {
                    Text("Clear Clipboard History")
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct AboutTab: View {
    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(v) (\(b))"
    }

    var body: some View {
        VStack(spacing: 10) {
            Icon(.logo, size: 46)
                .foregroundStyle(.secondary)
            Text("OpenNook")
                .font(.title2.weight(.semibold))
            Text(version)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("A free, open notch companion.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
