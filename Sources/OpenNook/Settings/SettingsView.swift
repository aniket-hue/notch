import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: Settings
    let registry: WidgetRegistry
    let clipboard: ClipboardService

    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("General", systemImage: "gearshape") }
            AppearanceTab(settings: settings)
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
            WidgetsTab(settings: settings, registry: registry)
                .tabItem { Label("Widgets", systemImage: "square.grid.2x2") }
            ClipboardTab(settings: settings, clipboard: clipboard)
                .tabItem { Label("Clipboard", systemImage: "doc.on.clipboard") }
            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 480, height: 360)
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
                    Slider(value: $settings.glassTint, in: 0...0.5) {
                        Text("Tint")
                    } minimumValueLabel: {
                        Text("Clear").font(.caption2).foregroundStyle(.secondary)
                    } maximumValueLabel: {
                        Text("Dark").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }

            Section("Accent") {
                HStack(spacing: 12) {
                    ForEach(AccentChoice.allCases) { choice in
                        Button {
                            settings.accent = choice
                        } label: {
                            Circle()
                                .fill(choice.color)
                                .frame(width: 26, height: 26)
                                .overlay(
                                    Circle()
                                        .strokeBorder(.primary.opacity(settings.accent == choice ? 0.9 : 0), lineWidth: 2)
                                        .padding(-3)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
    }
}

private struct WidgetsTab: View {
    @ObservedObject var settings: Settings
    let registry: WidgetRegistry

    var body: some View {
        Form {
            Section {
                ForEach(registry.availableIDs, id: \.self) { id in
                    Toggle(registry.title(for: id), isOn: Binding(
                        get: { settings.isWidgetEnabled(id) },
                        set: { settings.setWidget(id, enabled: $0) }
                    ))
                }
            } header: {
                Text("Shown in the notch")
            } footer: {
                Text("Turn widgets on or off. The panel resizes to fit what's enabled.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
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
                            set: { settings.clipboardLimit = Int($0) }
                        ),
                        in: 10...100, step: 5
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
            Image(systemName: "rectangle.topthird.inset.filled")
                .font(.system(size: 46))
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
