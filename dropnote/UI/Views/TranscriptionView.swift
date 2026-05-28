import SwiftUI

private struct SupportedLocale: Identifiable, Equatable {
    let id: String
    let label: String
    var locale: Locale { Locale(identifier: id) }
}

private let supportedLocales: [SupportedLocale] = [
    SupportedLocale(id: "de-DE", label: "DE"),
    SupportedLocale(id: "en-US", label: "EN"),
    SupportedLocale(id: "en-GB", label: "EN-GB"),
    SupportedLocale(id: "fr-FR", label: "FR"),
    SupportedLocale(id: "es-ES", label: "ES"),
    SupportedLocale(id: "it-IT", label: "IT"),
]

struct TranscriptionView: View {
    @ObservedObject private var service = TranscriptionService.shared
    var onSaveAsNote: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            textArea
            Divider()
            controlBar
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ColorSchemeHelper.borderColor(), lineWidth: 1)
        )
        .frame(maxHeight: .infinity)
    }

    // MARK: - Text Area

    @ViewBuilder
    private var textArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Group {
                    if service.fullText.isEmpty {
                        placeholderText
                    } else {
                        Text(service.fullText)
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .id("bottom")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .frame(maxHeight: .infinity)
            .onChange(of: service.fullText) { _, _ in
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
        }

        if let error = service.errorMessage {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                Text(error)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button { service.errorMessage = nil } label: {
                    Image(systemName: "xmark").font(.caption2).foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.orange.opacity(0.08))
        }
    }

    @ViewBuilder
    private var placeholderText: some View {
        Text("Start speaking...")
            .font(.system(size: 13))
            .foregroundColor(.secondary.opacity(0.5))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Control Bar

    @ViewBuilder
    private var controlBar: some View {
        HStack(spacing: 10) {
            languagePicker

            Spacer()

            if !service.fullText.isEmpty {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(service.fullText, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc").font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .help("Copy to clipboard")

                Button {
                    onSaveAsNote(service.fullText)
                    service.clearAll()
                } label: {
                    Image(systemName: "square.and.arrow.down").font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .help("Save as note")

                Button {
                    service.clearAll()
                } label: {
                    Image(systemName: "trash").font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .help("Clear")
            }

            micButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var languagePicker: some View {
        Menu {
            ForEach(supportedLocales) { loc in
                Button {
                    service.setLocale(loc.locale)
                } label: {
                    HStack {
                        Text(loc.label)
                        if service.locale.identifier == loc.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "globe")
                    .font(.system(size: 10))
                Text(currentLocaleLabel)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.primary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .help("Select language")
    }

    private var currentLocaleLabel: String {
        supportedLocales.first { $0.id == service.locale.identifier }?.label ?? "DE"
    }

    @ViewBuilder
    private var micButton: some View {
        Button { handleMicTap() } label: {
            ZStack {
                Circle()
                    .fill(service.isRecording ? Color.red.opacity(0.15) : Color.accentColor.opacity(0.12))
                    .frame(width: 34, height: 34)
                Image(systemName: service.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(service.isRecording ? .red : .accentColor)
            }
        }
        .buttonStyle(.plain)
        .overlay(recordingRing)
        .help(service.isRecording ? "Stop recording" : "Start recording")
    }

    @ViewBuilder
    private var recordingRing: some View {
        if service.isRecording {
            Circle()
                .stroke(Color.red.opacity(0.35), lineWidth: 1.5)
                .frame(width: 44, height: 44)
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: service.isRecording)
        }
    }

    // MARK: - Actions

    private func handleMicTap() {
        switch service.permissionStatus {
        case .notDetermined:
            service.requestSpeechPermission {
                if self.service.permissionStatus == .authorized {
                    self.service.startRecording()
                }
            }
        case .authorized:
            service.isRecording ? service.stopRecording() : service.startRecording()
        case .denied, .restricted:
            service.errorMessage = "Access denied. Enable speech recognition in System Settings → Privacy & Security → Speech Recognition."
        @unknown default:
            break
        }
    }
}
