// Symfony CLI Menu Bar
// Copyright © 2026 Simon André <smn.andre@gmail.com>
// Open source software — MIT License
//
// "Symfony" is a registered trademark of Symfony SAS, used with kind permission.
// This app is not affiliated with or endorsed by Symfony SAS or SensioLabs.

import SwiftUI

struct AboutView: View {
    @Environment(\.openURL) private var openURL

    private let bodyFont  = Font.system(size: 12)
    private let labelFont = Font.system(size: 12, weight: .semibold)

    var body: some View {
        VStack(spacing: 0) {

            // MARK: Icon + Identity

            VStack(spacing: 6) {
                Group {
                    if let icon = NSImage(named: "symfony-cli-menubar") {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Image(systemName: "s.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .foregroundStyle(.primary)
                    }
                }
                .frame(width: 56, height: 56)

                Text(AppInfo.name)
                    .font(.system(size: 17, weight: .bold))

                Text("Version \(AppInfo.version)")
                    .font(bodyFont)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 8)

            // MARK: Links

            HStack(spacing: 16) {
                Link("Website", destination: URL(string: AppInfo.websiteURL)!)
                Link("GitHub",  destination: URL(string: AppInfo.githubURL)!)
                if let licenseURL = URL(string: "\(AppInfo.githubURL)/blob/main/LICENSE") {
                    Link("License", destination: licenseURL)
                }
            }
            .font(bodyFont)
            .padding(.bottom, 24)

            // MARK: Section: Author

            VStack(spacing: 4) {
                Text("Created by Simon André")
                    .font(labelFont)
                HStack(spacing: 8) {
                    Link("@smnandre",    destination: URL(string: "https://github.com/smnandre")!)
                    Text("·").foregroundStyle(.tertiary)
                    Link("smnandre.dev", destination: URL(string: AppInfo.websiteURL)!)
                }
                .font(bodyFont)
            }
            .padding(.bottom, 20)

            // MARK: Section: Symfony CLI

            VStack(spacing: 4) {
                Text("Symfony CLI")
                    .font(labelFont)
                HStack(spacing: 8) {
                    Link("Fabien Potencier", destination: URL(string: "https://github.com/fabpot")!)
                    Text("·").foregroundStyle(.tertiary)
                    Link("Tugdual Saunier", destination: URL(string: "https://github.com/tucksaun")!)
                }
                .font(bodyFont)
            }
            .padding(.bottom, 20)

            // MARK: Section: Symfony

            VStack(spacing: 4) {
                Text("Symfony")
                    .font(labelFont)
                Text("\"Symfony\" and the Symfony logo are registered trademarks of Symfony SAS.")
                    .font(bodyFont)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 24)
        .padding(.bottom, 24)
        .frame(width: 360)
    }
}

#Preview {
    AboutView()
}
