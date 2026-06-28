import SwiftUI

/// Local, offline version history for a single note. Lists the most recent
/// snapshots with a relative timestamp and lets the user restore one.
struct NoteHistoryView: View {
    @Binding var note: Note
    var onRestore: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var restoredID: UUID?

    private var versionsNewestFirst: [NoteVersion] {
        note.versions.reversed()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            if versionsNewestFirst.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(versionsNewestFirst) { version in
                            versionRow(version)
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: 280)
            }
        }
        .frame(width: 300)
    }

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.accentColor)
            Text("Version History")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Text("\(note.versions.count)/\(Note.maxVersions)")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "clock")
                .font(.system(size: 22))
                .foregroundColor(.secondary.opacity(0.5))
            Text("No earlier versions yet")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            Text("Snapshots are saved automatically as you edit.")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
    }

    @ViewBuilder
    private func versionRow(_ version: NoteVersion) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(timestampLabel(version.timestamp))
                    .font(.system(size: 12, weight: .semibold))
                Text(preview(version.text))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 4)
            Button(restoredID == version.id ? "Restored" : "Restore") {
                restore(version)
            }
            .font(.system(size: 11, weight: .semibold))
            .buttonStyle(.plain)
            .foregroundColor(restoredID == version.id ? .secondary : .accentColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.04))
        )
    }

    private func restore(_ version: NoteVersion) {
        // Keep the current content as a fresh snapshot before overwriting,
        // so a restore is itself reversible.
        note.captureVersionIfNeeded(minInterval: 0)
        note.text = version.text
        note.attributedTextRTF = version.attributedTextRTF
        note.updateModifiedDate()
        restoredID = version.id
        onRestore()
    }

    private func preview(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "(empty)" : trimmed
    }

    private func timestampLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
            return "Today, " + formatter.string(from: date)
        }
        formatter.dateFormat = "dd MMM, HH:mm"
        return formatter.string(from: date)
    }
}
