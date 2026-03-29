// Symfony CLI Menu Bar
// Copyright © 2026 Simon André <smn.andre@gmail.com>
// Open source software — MIT License
//
// "Symfony" is a registered trademark of Symfony SAS, used with kind permission.
// This app is not affiliated with or endorsed by Symfony SAS or SensioLabs.

import SwiftUI
import ServiceManagement

struct PreferencesView: View {
    @ObservedObject var serverManager: SymfonyServerManager
    @State private var startAtLogin: Bool = false
    @AppStorage("RefreshInterval")         private var refreshInterval:    Double = 10.0
    @AppStorage("MaxStoppedServersToShow") private var maxStoppedServers: Double = 3.0
    @AppStorage("MaxProxiesToShow")        private var maxProxies:        Double = 2.0
    @AppStorage("ShowPHPVersions")         private var showPHPVersions:    Bool   = true
    @AppStorage("ShowProxies")             private var showProxies:        Bool   = true
    @AppStorage("ShowServers")             private var showServers:        Bool   = true

    // MARK: - Layout constants

    private let hPad:          CGFloat = 20
    private let sectionGap:    CGFloat = 20
    private let switchScale:   CGFloat = 0.72
    private let sliderLabel:   CGFloat = 100   // fixed: all sliders start at same x
    private let sliderValue:   CGFloat = 46    // fixed: all values end at same x

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // MARK: PHP Versions

                sectionRow("PHP Versions", isOn: $showPHPVersions)

                Spacer().frame(height: sectionGap)

                // MARK: Proxies

                sectionRow("Proxies", isOn: $showProxies)
                sliderRow("Max Visible", value: $maxProxies, in: 1...10)
                    .disabled(!showProxies)
                    .opacity(showProxies ? 1 : 0.4)

                Spacer().frame(height: sectionGap)

                // MARK: Servers

                sectionRow("Servers", isOn: $showServers)
                sliderRow("Max Visible", value: $maxStoppedServers, in: 1...10)
                    .disabled(!showServers)
                    .opacity(showServers ? 1 : 0.4)

                Spacer().frame(height: sectionGap)

                // MARK: System

                sectionLabel("System")
                toggleRow("Start at Login", isOn: $startAtLogin)
                    .onChange(of: startAtLogin) { _, newValue in
                        toggleStartAtLogin(newValue)
                    }
                sliderRow("Refresh Interval", value: $refreshInterval, in: 5...60, step: 5, unit: "sec")
            }
            .padding(.horizontal, hPad)
            .padding(.vertical, 14)
        }
        .onAppear {
            startAtLogin = SMAppService.mainApp.status == .enabled
        }
        .onChange(of: refreshInterval)    { _, _ in NotificationCenter.default.post(name: Prefs.didChange, object: nil) }
        .onChange(of: maxStoppedServers)  { _, _ in NotificationCenter.default.post(name: Prefs.didChange, object: nil) }
        .onChange(of: maxProxies)         { _, _ in NotificationCenter.default.post(name: Prefs.didChange, object: nil) }
        .onChange(of: showPHPVersions)    { _, _ in NotificationCenter.default.post(name: Prefs.didChange, object: nil) }
        .onChange(of: showProxies)        { _, _ in NotificationCenter.default.post(name: Prefs.didChange, object: nil) }
        .onChange(of: showServers)        { _, _ in NotificationCenter.default.post(name: Prefs.didChange, object: nil) }
    }

    // MARK: - Row Builders

    @ViewBuilder
    private func sectionRow(_ label: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .scaleEffect(switchScale)
                .frame(width: 38 * switchScale, height: 22 * switchScale)
        }
        .padding(.vertical, 9)
    }

    @ViewBuilder
    private func sectionLabel(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 13, weight: .semibold))
            .padding(.vertical, 9)
    }

    @ViewBuilder
    private func toggleRow(_ label: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .scaleEffect(switchScale)
                .frame(width: 38 * switchScale, height: 22 * switchScale)
        }
        .padding(.vertical, 7)
    }

    @ViewBuilder
    private func sliderRow(_ label: String, value: Binding<Double>, in range: ClosedRange<Double>, step: Double = 1, unit: String = "") -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: sliderLabel, alignment: .leading)
            Slider(value: value, in: range, step: step)
            Text(unit.isEmpty ? "\(Int(value.wrappedValue))" : "\(Int(value.wrappedValue)) \(unit)")
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(.tertiary)
                .frame(width: sliderValue, alignment: .trailing)
        }
        .padding(.vertical, 7)
    }

    // MARK: - Actions

    private func toggleStartAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            startAtLogin = !enabled
        }
    }
}

#Preview {
    PreferencesView(serverManager: SymfonyServerManager())
}
