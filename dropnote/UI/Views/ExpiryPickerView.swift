import SwiftUI

/// Reusable self-destruct menu entries, used in both the popover tab context menu
/// and the full-window sidebar context menu.
struct ExpiryMenuItems: View {
    let hasExpiry: Bool
    let onPreset: (TimeInterval) -> Void
    let onCustom: () -> Void
    let onRemove: () -> Void

    var body: some View {
        Button("In 5 minutes")  { onPreset(5 * 60) }
        Button("In 10 minutes") { onPreset(10 * 60) }
        Button("In 30 minutes") { onPreset(30 * 60) }
        Button("In 24 hours")   { onPreset(24 * 60 * 60) }
        Divider()
        Button("Custom…")       { onCustom() }
        if hasExpiry {
            Divider()
            Button("Remove Expiry", role: .destructive) { onRemove() }
        }
    }
}

/// Clean sheet for choosing a custom expiry date + time.
struct ExpiryPickerView: View {
    let noteTitle: String
    let initialDate: Date?
    let onSet: (Date) -> Void
    let onCancel: () -> Void

    @State private var date: Date

    init(noteTitle: String, initialDate: Date?, onSet: @escaping (Date) -> Void, onCancel: @escaping () -> Void) {
        self.noteTitle = noteTitle
        self.initialDate = initialDate
        self.onSet = onSet
        self.onCancel = onCancel
        _date = State(initialValue: initialDate ?? Date().addingTimeInterval(60 * 60))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 9) {
                Image(systemName: "timer")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Self-Destruct")
                        .font(.system(size: 15, weight: .semibold))
                    Text(noteTitle.isEmpty ? "Untitled note" : noteTitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            DatePicker("Expires on", selection: $date, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.compact)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(relativeLabel)
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Set Expiry") { onSet(date) }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 320)
    }

    private var relativeLabel: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Deletes " + formatter.localizedString(for: date, relativeTo: Date())
    }
}
