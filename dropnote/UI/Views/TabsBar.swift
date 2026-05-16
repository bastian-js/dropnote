import SwiftUI

struct TabsBar: View {
    @Binding var notes: [Note]
    let filteredIndices: [Int]
    @Binding var selectedTab: Int
    @Binding var isEditingTabTitle: Bool
    @Binding var editedTabTitle: String
    @FocusState.Binding var isTextFieldFocused: Bool

    let onRequestDelete: (Int) -> Void
    let onPersist: () -> Void
    let onRequestTogglePin: (Int) -> Void
    let onRequestToggleLock: (Int) -> Void

    // Todo tab support
    var showTodoTab: Bool = false
    var isTodoTabSelected: Bool = false
    var onSelectTodoTab: (() -> Void)? = nil
    var onSelectNoteTab: (() -> Void)? = nil

    // Drag-to-reorder
    var onMove: ((Int, Int) -> Void)? = nil
    @State private var draggingIndex: Int?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if showTodoTab {
                    todoTabButton
                }
                ForEach(filteredIndices, id: \.self) { index in
                    tabItem(index: index)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 2)
        }
    }

    // MARK: - Todo Tab

    @ViewBuilder
    private var todoTabButton: some View {
        Button {
            onSelectTodoTab?()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "checkmark.circle\(isTodoTabSelected ? ".fill" : "")")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(isTodoTabSelected ? .accentColor : .secondary)
                Text("Todos")
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isTodoTabSelected ? ColorSchemeHelper.selectedTabBackground() : Color.clear)
            .cornerRadius(6)
            .contentShape(RoundedRectangle(cornerRadius: 6))
            .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Note Tabs

    @ViewBuilder
    private func tabItem(index: Int) -> some View {
        if isEditingTabTitle && selectedTab == index {
            editingTabTextField(index: index)
        } else {
            selectableTabButton(index: index)
        }
    }

    @ViewBuilder
    private func editingTabTextField(index: Int) -> some View {
        TextField("", text: $editedTabTitle, onCommit: {
            notes[index].title = editedTabTitle
            isEditingTabTitle = false
            onPersist()
        })
        .focused($isTextFieldFocused)
        .textFieldStyle(PlainTextFieldStyle())
        .padding(6)
        .background(ColorSchemeHelper.inputBackground())
        .cornerRadius(6)
        .fixedSize(horizontal: true, vertical: false)
        .onChange(of: isTextFieldFocused) { _, focused in
            guard !focused, isEditingTabTitle, selectedTab == index else { return }
            commitTabTitleEdit(index: index)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
            }
        }
    }

    @ViewBuilder
    private func selectableTabButton(index: Int) -> some View {
        HStack(spacing: 6) {
            if notes[index].isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            Text(notes[index].title)
                .lineLimit(1)
        }
        .frame(minWidth: 72, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(!isTodoTabSelected && selectedTab == index ? ColorSchemeHelper.selectedTabBackground() : Color.clear)
        .cornerRadius(6)
        .contentShape(RoundedRectangle(cornerRadius: 6))
        .fixedSize(horizontal: true, vertical: false)
        // Double-tap first so SwiftUI disambiguates before single-tap fires
        .onTapGesture(count: 2) {
            editedTabTitle = notes[index].title
            isEditingTabTitle = true
            selectedTab = index
        }
        .onTapGesture(count: 1) {
            onSelectNoteTab?()
            selectedTab = index
        }
        .contextMenu {
            Button(notes[index].isPinned ? "Unpin" : "Pin") { onRequestTogglePin(index) }
            Button("Edit Title") {
                editedTabTitle = notes[index].title
                isEditingTabTitle = true
                selectedTab = index
            }
            Button(notes[index].isLocked ? "Remove Lock" : "Lock") { onRequestToggleLock(index) }
            Button("Delete Note", role: .destructive) { onRequestDelete(index) }
        }
        .opacity(draggingIndex == index ? 0.45 : 1.0)
        .onDrag {
            guard onMove != nil, filteredIndices.count == notes.count else { return NSItemProvider() }
            draggingIndex = index
            return NSItemProvider(object: "\(index)" as NSString)
        }
        .onDrop(of: ["public.text"], delegate: TabDropDelegate(
            targetIndex: index,
            draggingIndex: $draggingIndex,
            canDrop: onMove != nil && filteredIndices.count == notes.count,
            onMove: onMove
        ))
    }

    // MARK: - Helpers

    private func commitTabTitleEdit(index: Int) {
        let trimmed = editedTabTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            notes[index].title = trimmed
            onPersist()
        }
        isEditingTabTitle = false
    }
}

// MARK: - TabDropDelegate

private struct TabDropDelegate: DropDelegate {
    let targetIndex: Int
    @Binding var draggingIndex: Int?
    let canDrop: Bool
    let onMove: ((Int, Int) -> Void)?

    func dropEntered(info: DropInfo) {
        guard canDrop, let from = draggingIndex, from != targetIndex else { return }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            onMove?(from, targetIndex)
        }
        draggingIndex = targetIndex
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingIndex = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        canDrop ? DropProposal(operation: .move) : DropProposal(operation: .forbidden)
    }
}
