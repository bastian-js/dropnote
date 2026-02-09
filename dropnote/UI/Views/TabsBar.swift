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
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(filteredIndices, id: \.self) { index in
                    tabItem(index: index)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 2)
        }
    }
    
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
        .background(Color.gray.opacity(0.2))
        .cornerRadius(6)
        .fixedSize(horizontal: true, vertical: false)
        .onChange(of: isTextFieldFocused) { _, focused in
            guard !focused, isEditingTabTitle, selectedTab == index else {
                return
            }
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
        .padding(6)
        .background(selectedTab == index ? Color.accentColor.opacity(0.3) : Color.clear)
        .cornerRadius(6)
        .fixedSize(horizontal: true, vertical: false)
        .contextMenu {
            Button(notes[index].isPinned ? "Unpin" : "Pin") {
                onRequestTogglePin(index)
            }
            Button("Edit Title") {
                editedTabTitle = notes[index].title
                isEditingTabTitle = true
                selectedTab = index
            }
            Button(notes[index].isLocked ? "Remove Lock" : "Lock") {
                onRequestToggleLock(index)
            }
            Button("Delete Note", role: .destructive) {
                onRequestDelete(index)
            }
        }
        .onTapGesture(count: 2) {
            editedTabTitle = notes[index].title
            isEditingTabTitle = true
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedTab = index
            }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedTab = index
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func commitTabTitleEdit(index: Int) {
        let trimmed = editedTabTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            notes[index].title = trimmed
            onPersist()
        }
        isEditingTabTitle = false
    }
}
