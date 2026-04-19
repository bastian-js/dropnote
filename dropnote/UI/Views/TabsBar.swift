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
        Button {
            selectedTab = index
        } label: {
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
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                editedTabTitle = notes[index].title
                isEditingTabTitle = true
                selectedTab = index
            }
        )
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
