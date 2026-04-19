import SwiftUI
import AppKit

struct AboutView: View {
    @Environment(\.colorScheme) var colorScheme

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.1"
    }

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 0) {
                Spacer().frame(height: 40)

                iconSection

                Spacer().frame(height: 18)

                nameBadgeSection

                Spacer().frame(height: 10)

                Text("Quick notes, clean focus, instant search.")
                    .font(.system(size: 13.5, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Spacer()

                featurePillsRow

                Spacer()

                copyrightBar
            }
            .padding(.horizontal, 40)
        }
        .frame(width: 460, height: 340)
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var backgroundLayer: some View {
        ZStack {
            (colorScheme == .dark
                ? Color(red: 0.08, green: 0.08, blue: 0.11)
                : Color(red: 0.96, green: 0.96, blue: 0.99))
                .ignoresSafeArea()

            // Decorative blobs
            Circle()
                .fill(Color.accentColor.opacity(colorScheme == .dark ? 0.12 : 0.09))
                .frame(width: 320, height: 320)
                .offset(x: 160, y: -120)
                .blur(radius: 80)

            Circle()
                .fill(Color.purple.opacity(colorScheme == .dark ? 0.08 : 0.06))
                .frame(width: 220, height: 220)
                .offset(x: -140, y: 100)
                .blur(radius: 60)
        }
    }

    @ViewBuilder
    private var iconSection: some View {
        ZStack {
            // Glow
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.accentColor.opacity(0.25))
                .frame(width: 90, height: 90)
                .blur(radius: 18)
                .offset(y: 6)

            // App icon
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.15), radius: 12, x: 0, y: 6)
        }
    }

    @ViewBuilder
    private var nameBadgeSection: some View {
        VStack(spacing: 8) {
            Text("DropNote")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Text("Version \(appVersion)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
                .padding(.horizontal, 13)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(colorScheme == .dark
                            ? Color.white.opacity(0.09)
                            : Color.black.opacity(0.07))
                        .overlay(
                            Capsule()
                                .stroke(colorScheme == .dark
                                    ? Color.white.opacity(0.12)
                                    : Color.black.opacity(0.09), lineWidth: 0.5)
                        )
                )
        }
    }

    @ViewBuilder
    private var featurePillsRow: some View {
        HStack(spacing: 8) {
            pill(icon: "bolt.fill",         label: "Fast Capture",    color: .orange)
            pill(icon: "magnifyingglass",   label: "Global Search",   color: .blue)
            pill(icon: "lock.fill",         label: "Private",         color: .green)
        }
    }

    @ViewBuilder
    private func pill(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(colorScheme == .dark
                    ? Color.white.opacity(0.07)
                    : Color.black.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(colorScheme == .dark
                            ? Color.white.opacity(0.1)
                            : Color.black.opacity(0.08), lineWidth: 0.75)
                )
        )
    }

    @ViewBuilder
    private var copyrightBar: some View {
        VStack(spacing: 3) {
            Divider()
                .opacity(colorScheme == .dark ? 0.15 : 0.2)
            Text("© 2026 bastian-js · All rights reserved.")
                .font(.system(size: 10.5))
                .foregroundColor(.secondary.opacity(0.65))
                .padding(.top, 8)
                .padding(.bottom, 16)
        }
    }
}
