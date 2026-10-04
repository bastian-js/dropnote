import SwiftUI

/// The horizontal note tab strip in the popover.
///
/// Tabs are addressed by `Note.id`, never by position. On top of that it solves
/// the "where am I?" problem of a narrow popover: the active tab is always
/// scrolled into view, the strip fades at whichever edge still has hidden tabs,
/// and a counter chip shows the active note's position plus a jump-to menu.
struct TabsBar: View {
    /// The notes to show, already filtered by the search field.
    let notes: [Note]
    @Binding var selectedNoteID: UUID?
    @Binding var isEditingTabTitle: Bool
    @Binding var editedTabTitle: String
    @FocusState.Binding var isTextFieldFocused: Bool

    let onRequestDelete: (UUID) -> Void
    let onRename: (UUID, String) -> Void
    let onRequestTogglePin: (UUID) -> Void
    let onRequestToggleLock: (UUID) -> Void

    // Todo tab support
    var showTodoTab: Bool = false
    var showTodoTabTitle: Bool = true
    var isTodoTabSelected: Bool = false
    var onSelectTodoTab: (() -> Void)? = nil
    var onSelectNoteTab: ((UUID) -> Void)? = nil

    // Transcription tab support
    var showTranscriptionTab: Bool = false
    var showTranscriptionTabTitle: Bool = false
    var isTranscriptionTabSelected: Bool = false
    var onSelectTranscriptionTab: (() -> Void)? = nil

    // Float note action
    var onRequestFloat: ((UUID) -> Void)? = nil

    // Self-destruct / expiry
    var onSetExpiry: ((UUID, Date?) -> Void)? = nil
    var onRequestCustomExpiry: ((UUID) -> Void)? = nil

    // Drag-to-reorder
    var onMove: ((UUID, UUID) -> Void)? = nil
    @State private var draggingNoteID: UUID?

    // Overflow tracking
    @State private var contentWidth: CGFloat = 0
    @State private var viewportWidth: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0

    // Horizontal scrollbar
    @State private var scrollPosition = ScrollPosition(idType: UUID.self)
    @State private var dragStartOffset: CGFloat?

    private static let scrollSpace = "TabsBarScroll"
    private static let fadeWidth: CGFloat = 16
    private static let scrollBarHeight: CGFloat = 6
    private static let minThumbWidth: CGFloat = 32

    private var isNoteTabActive: Bool { !isTodoTabSelected && !isTranscriptionTabSelected }

    private var selectedPosition: Int? {
        guard isNoteTabActive, let id = selectedNoteID else { return nil }
        return notes.firstIndex { $0.id == id }.map { $0 + 1 }
    }

    private var isOverflowing: Bool { contentWidth - viewportWidth > 1 }
    private var canScrollLeft: Bool { isOverflowing && scrollOffset > 1 }
    private var canScrollRight: Bool { isOverflowing && (contentWidth - viewportWidth - scrollOffset) > 1 }

    /// How far the strip can be scrolled. Never zero, so it's safe to divide by.
    private var maxScroll: CGFloat { max(contentWidth - viewportWidth, 1) }

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                tabStrip
                if isOverflowing {
                    overflowIndicator
                        .padding(.trailing, 10)
                }
            }
            if isOverflowing {
                horizontalScrollBar
                    .padding(.horizontal, 10)
            }
        }
    }

    // MARK: - Horizontal Scrollbar

    /// A always-visible, draggable scrollbar for the tab strip. macOS hides its own
    /// overlay scroller as soon as you stop scrolling, which is exactly when you
    /// need to know that there are more tabs.
    @ViewBuilder
    private var horizontalScrollBar: some View {
        GeometryReader { geo in
            let trackWidth = geo.size.width
            let visibleRatio = min(1, viewportWidth / max(contentWidth, 1))
            let thumbWidth = max(Self.minThumbWidth, trackWidth * visibleRatio)
            let travel = max(trackWidth - thumbWidth, 0)
            let progress = min(1, max(0, scrollOffset / maxScroll))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.10))
                    .frame(height: Self.scrollBarHeight)

                Capsule()
                    .fill(Color.primary.opacity(isDraggingScrollBar ? 0.55 : 0.34))
                    .frame(width: thumbWidth, height: Self.scrollBarHeight)
                    .offset(x: travel * progress)
                    .animation(.easeOut(duration: 0.12), value: isDraggingScrollBar)
            }
            .frame(height: Self.scrollBarHeight)
            .frame(maxHeight: .infinity, alignment: .center)
            // The gesture sits on the whole track, so grabbing slightly above or
            // below the 6pt thumb still works.
            .contentShape(Rectangle())
            .gesture(scrollBarDrag(travel: travel))
        }
        .frame(height: 11)
    }

    private var isDraggingScrollBar: Bool { dragStartOffset != nil }

    private func scrollBarDrag(travel: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard travel > 0 else { return }
                let start = dragStartOffset ?? scrollOffset
                if dragStartOffset == nil { dragStartOffset = start }
                let delta = value.translation.width / travel * maxScroll
                scrollPosition.scrollTo(x: min(maxScroll, max(0, start + delta)))
            }
            .onEnded { _ in dragStartOffset = nil }
    }

    // MARK: - Tab Strip

    @ViewBuilder
    private var tabsRow: some View {
        HStack(spacing: 6) {
            if showTranscriptionTab {
                transcriptionTabButton.id(Self.transcriptionTabID)
            }
            if showTodoTab {
                todoTabButton.id(Self.todoTabID)
            }
            ForEach(notes) { note in
                tabItem(note: note).id(note.id)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 2)
        // Measure the strip itself rather than bubbling a PreferenceKey out of the
        // scroll view: `onGeometryChange` reports the view it is attached to and
        // writes the state directly, so there is nothing in between that can
        // swallow the value.
        .onGeometryChange(for: TabStripMetrics.self) { proxy in
            TabStripMetrics(
                contentWidth: proxy.size.width,
                offset: -proxy.frame(in: .named(Self.scrollSpace)).minX
            )
        } action: { metrics in
            contentWidth = metrics.contentWidth
            scrollOffset = max(0, metrics.offset)
        }
    }

    @ViewBuilder
    private var tabStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                tabsRow
            }
            .scrollPosition($scrollPosition)
            .coordinateSpace(.named(Self.scrollSpace))
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
                viewportWidth = width
            }
            // Keep the active tab visible — when it's selected, when a new note is
            // created, and when notes are added or removed around it.
            .onChange(of: selectedNoteID) { _, _ in scrollToActiveTab(proxy) }
            .onChange(of: notes.count) { _, _ in scrollToActiveTab(proxy) }
            .onChange(of: isTodoTabSelected) { _, _ in scrollToActiveTab(proxy) }
            .onChange(of: isTranscriptionTabSelected) { _, _ in scrollToActiveTab(proxy) }
            .onAppear { scrollToActiveTab(proxy, animated: false) }
        }
        .mask(edgeFadeMask)
    }

    /// Fades out whichever edge still hides tabs, so an overflowing strip looks
    /// cut off on purpose instead of ending abruptly.
    @ViewBuilder
    private var edgeFadeMask: some View {
        HStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                .frame(width: canScrollLeft ? Self.fadeWidth : 0)
            Rectangle().fill(Color.black)
            LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: canScrollRight ? Self.fadeWidth : 0)
        }
        .animation(.easeInOut(duration: 0.15), value: canScrollLeft)
        .animation(.easeInOut(duration: 0.15), value: canScrollRight)
    }

    private func scrollToActiveTab(_ proxy: ScrollViewProxy, animated: Bool = true) {
        let target: UUID?
        if isTranscriptionTabSelected {
            target = showTranscriptionTab ? Self.transcriptionTabID : nil
        } else if isTodoTabSelected {
            target = showTodoTab ? Self.todoTabID : nil
        } else if let id = selectedNoteID, notes.contains(where: { $0.id == id }) {
            target = id
        } else {
            target = nil
        }
        guard let target else { return }

        // One runloop hop so the strip has laid out the tab we're scrolling to
        // (it may have just been inserted).
        DispatchQueue.main.async {
            if animated {
                withAnimation(.easeInOut(duration: 0.2)) { proxy.scrollTo(target, anchor: .center) }
            } else {
                proxy.scrollTo(target, anchor: .center)
            }
        }
    }

    // MARK: - Overflow Indicator

    /// "3/12" — the active note's position and how many tabs there are, doubling
    /// as a jump-to menu for the tabs that are scrolled out of sight.
    @ViewBuilder
    private var overflowIndicator: some View {
        Menu {
            ForEach(notes) { note in
                Button {
                    onSelectNoteTab?(note.id)
                    selectedNoteID = note.id
                } label: {
                    if isNoteTabActive && note.id == selectedNoteID {
                        Label(note.title.isEmpty ? "Untitled" : note.title, systemImage: "checkmark")
                    } else {
                        Text(note.title.isEmpty ? "Untitled" : note.title)
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Text(selectedPosition.map { "\($0)/\(notes.count)" } ?? "\(notes.count)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .bold))
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(Color.primary.opacity(0.07))
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("\(notes.count) notes — jump to a note")
    }

    // MARK: - Todo Tab

    // Fixed ids so every tab in the strip is identified the same way (UUID), which
    // is what both the scroll reader and `ScrollPosition` expect.
    private static let todoTabID = UUID(uuidString: "00000000-0000-0000-0000-00000000D0D0")!
    private static let transcriptionTabID = UUID(uuidString: "00000000-0000-0000-0000-000000007A1C")!

    @ViewBuilder
    private var todoTabButton: some View {
        Button {
            onSelectTodoTab?()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "checkmark.circle\(isTodoTabSelected ? ".fill" : "")")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(isTodoTabSelected ? .accentColor : .secondary)
                if showTodoTabTitle {
                    Text("Todos")
                        .lineLimit(1)
                }
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

    // MARK: - Transcription Tab

    @ViewBuilder
    private var transcriptionTabButton: some View {
        Button {
            onSelectTranscriptionTab?()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "mic\(isTranscriptionTabSelected ? ".fill" : "")")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isTranscriptionTabSelected ? .accentColor : .secondary)
                if showTranscriptionTabTitle {
                    Text("Transcribe")
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isTranscriptionTabSelected ? ColorSchemeHelper.selectedTabBackground() : Color.clear)
            .cornerRadius(6)
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help("Transcribe")
    }

    // MARK: - Note Tabs

    @ViewBuilder
    private func tabItem(note: Note) -> some View {
        if isEditingTabTitle && selectedNoteID == note.id {
            editingTabTextField(note: note)
        } else {
            selectableTabButton(note: note)
        }
    }

    @ViewBuilder
    private func editingTabTextField(note: Note) -> some View {
        TextField("", text: $editedTabTitle, onCommit: {
            commitTabTitleEdit(noteID: note.id)
        })
        .focused($isTextFieldFocused)
        .textFieldStyle(PlainTextFieldStyle())
        .padding(6)
        .background(ColorSchemeHelper.inputBackground())
        .cornerRadius(6)
        .fixedSize(horizontal: true, vertical: false)
        .onChange(of: isTextFieldFocused) { _, focused in
            guard !focused, isEditingTabTitle, selectedNoteID == note.id else { return }
            commitTabTitleEdit(noteID: note.id)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
            }
        }
    }

    @ViewBuilder
    private func selectableTabButton(note: Note) -> some View {
        let isSelected = isNoteTabActive && selectedNoteID == note.id

        HStack(spacing: 6) {
            if note.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            if note.isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            if note.expiryDate != nil {
                Image(systemName: "timer")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.orange)
            }
            Text(note.title)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .accentColor : .primary)
                .lineLimit(1)
        }
        .frame(minWidth: 72, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isSelected ? ColorSchemeHelper.selectedTabBackground() : Color.clear)
        .cornerRadius(6)
        .overlay(alignment: .bottom) {
            // A clear marker for the active tab that survives any accent/theme.
            Capsule()
                .fill(Color.accentColor)
                .frame(height: 2)
                .padding(.horizontal, 8)
                .opacity(isSelected ? 1 : 0)
        }
        .contentShape(RoundedRectangle(cornerRadius: 6))
        .fixedSize(horizontal: true, vertical: false)
        // Double-tap first so SwiftUI disambiguates before single-tap fires
        .onTapGesture(count: 2) {
            editedTabTitle = note.title
            selectedNoteID = note.id
            isEditingTabTitle = true
        }
        .onTapGesture(count: 1) {
            onSelectNoteTab?(note.id)
            selectedNoteID = note.id
        }
        .contextMenu {
            Button(note.isPinned ? "Unpin" : "Pin") { onRequestTogglePin(note.id) }
            Button("Edit Title") {
                editedTabTitle = note.title
                selectedNoteID = note.id
                isEditingTabTitle = true
            }
            Button(note.isLocked ? "Remove Lock" : "Lock") { onRequestToggleLock(note.id) }
            Divider()
            Button("Float Note") { onRequestFloat?(note.id) }
            Menu("Self-Destruct") {
                ExpiryMenuItems(
                    hasExpiry: note.expiryDate != nil,
                    onPreset: { onSetExpiry?(note.id, Date().addingTimeInterval($0)) },
                    onCustom: { onRequestCustomExpiry?(note.id) },
                    onRemove: { onSetExpiry?(note.id, nil) }
                )
            }
            Divider()
            Button("Delete Note", role: .destructive) { onRequestDelete(note.id) }
        }
        .opacity(draggingNoteID == note.id ? 0.45 : 1.0)
        .onDrag {
            guard onMove != nil else { return NSItemProvider() }
            draggingNoteID = note.id
            return NSItemProvider(object: note.id.uuidString as NSString)
        }
        .onDrop(of: ["public.text"], delegate: TabDropDelegate(
            targetNoteID: note.id,
            draggingNoteID: $draggingNoteID,
            canDrop: onMove != nil,
            onMove: onMove
        ))
    }

    // MARK: - Helpers

    private func commitTabTitleEdit(noteID: UUID) {
        let trimmed = editedTabTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            onRename(noteID, trimmed)
        }
        isEditingTabTitle = false
    }
}

// MARK: - Scroll metrics

private struct TabStripMetrics: Equatable {
    var contentWidth: CGFloat = 0
    var offset: CGFloat = 0
}

// MARK: - TabDropDelegate

private struct TabDropDelegate: DropDelegate {
    let targetNoteID: UUID
    @Binding var draggingNoteID: UUID?
    let canDrop: Bool
    let onMove: ((UUID, UUID) -> Void)?

    func dropEntered(info: DropInfo) {
        guard canDrop, let from = draggingNoteID, from != targetNoteID else { return }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            onMove?(from, targetNoteID)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingNoteID = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        canDrop ? DropProposal(operation: .move) : DropProposal(operation: .forbidden)
    }
}
