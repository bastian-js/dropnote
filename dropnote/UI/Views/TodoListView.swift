import SwiftUI

// MARK: - TodoListView

struct TodoListView: View {
    @Binding var todos: [TodoItem]
    var compact: Bool = false
    var showBorder: Bool = true
    var hideCompleted: Bool = false
    let onSave: () -> Void

    @State private var quickAddTitle: String = ""
    @State private var showingAddSheet = false
    @State private var sheetInitialTitle: String = ""
    @FocusState private var isQuickAddFocused: Bool

    static let predefinedTags = ["Work", "Personal", "Urgent"]

    private var pendingTodos: [TodoItem]   { todos.filter { !$0.isCompleted } }
    private var completedTodos: [TodoItem] { todos.filter { $0.isCompleted } }

    var body: some View {
        VStack(spacing: 0) {
            if !compact { listHeader; Divider() }
            addArea
            Divider()
            todoList
        }
        .overlay(
            Group {
                if !compact && showBorder {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(ColorSchemeHelper.borderColor(), lineWidth: 1)
                }
            }
        )
        .sheet(isPresented: $showingAddSheet) {
            AddTodoSheet(initialTitle: sheetInitialTitle) { todo in
                withAnimation { todos.append(todo) }
                quickAddTitle = ""
                onSave()
                showingAddSheet = false
            } onCancel: {
                showingAddSheet = false
            }
            .frame(width: 400, height: 560)
        }
    }

    // MARK: Header (non-compact only)

    @ViewBuilder
    private var listHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.accentColor)
            Text("Todos")
                .font(.system(.callout, design: .rounded).weight(.semibold))
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: Add Area

    @ViewBuilder
    private var addArea: some View {
        if compact {
            // Compact: single row — text field + detail button
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.45))
                    .frame(width: 16)
                TextField("Quick add…", text: $quickAddTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .focused($isQuickAddFocused)
                    .onSubmit { commitQuickAdd() }
                Button {
                    sheetInitialTitle = quickAddTitle
                    showingAddSheet = true
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .help("Add with date & tags")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
        } else {
            // Full: two distinct rows
            VStack(spacing: 0) {
                // Row 1 – Quick add (press Return)
                HStack(spacing: 8) {
                    Image(systemName: "return")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.4))
                        .frame(width: 18)
                    TextField("Quick add…  press ↩", text: $quickAddTitle)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .focused($isQuickAddFocused)
                        .onSubmit { commitQuickAdd() }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)

                Divider().padding(.leading, 40)

                // Row 2 – Add with details (opens sheet)
                Button {
                    sheetInitialTitle = quickAddTitle
                    showingAddSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.accentColor)
                        Text("Add with date & tags…")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.accentColor)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: List

    @ViewBuilder
    private var todoList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(pendingTodos) { todo in
                    TodoRow(todo: todo, compact: compact, onToggle: toggleTodo, onDelete: deleteTodo)
                }
                if !hideCompleted && !completedTodos.isEmpty {
                    if !compact {
                        HStack {
                            Text("Completed")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                            Spacer()
                            Button {
                                withAnimation { todos.removeAll { $0.isCompleted } }
                                onSave()
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Delete all completed")
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                        .padding(.bottom, 2)
                    }
                    ForEach(completedTodos) { todo in
                        TodoRow(todo: todo, compact: compact, onToggle: toggleTodo, onDelete: deleteTodo)
                    }
                }
                if todos.isEmpty { emptyState }
            }
            .padding(.bottom, 6)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 26, weight: .thin))
                .foregroundColor(.secondary.opacity(0.35))
            Text("No todos yet")
                .font(.callout.weight(.medium))
                .foregroundColor(.secondary)
        }
        .padding(.top, 22)
        .padding(.horizontal, 20)
    }

    // MARK: Helpers

    private func commitQuickAdd() {
        let trimmed = quickAddTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        withAnimation { todos.append(TodoItem(title: trimmed)) }
        quickAddTitle = ""
        onSave()
    }

    private func toggleTodo(_ id: UUID) {
        guard let i = todos.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.easeInOut(duration: 0.18)) { todos[i].isCompleted.toggle() }
        onSave()
    }

    private func deleteTodo(_ id: UUID) {
        withAnimation { todos.removeAll { $0.id == id } }
        onSave()
    }
}

// MARK: - TodoRow

struct TodoRow: View {
    let todo: TodoItem
    var compact: Bool = false
    let onToggle: (UUID) -> Void
    let onDelete: (UUID) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: compact ? 8 : 10) {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: compact ? 14 : 16, weight: .medium))
                    .foregroundColor(todo.isCompleted ? .accentColor : Color.secondary.opacity(0.4))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
                    .onTapGesture { onToggle(todo.id) }

                VStack(alignment: .leading, spacing: 3) {
                    Text(todo.title)
                        .font(.system(size: compact ? 12 : 13, weight: .medium))
                        .strikethrough(todo.isCompleted, color: .secondary)
                        .foregroundColor(todo.isCompleted ? .secondary : .primary)
                        .lineLimit(compact ? 1 : 2)

                    if !compact, (todo.dueDate != nil || !todo.tags.isEmpty) {
                        metaBadges
                    }
                }

                Spacer()

                if compact, let d = todo.dueDate, isOverdue(d), !todo.isCompleted {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal, compact ? 8 : 12)
            .padding(.vertical, compact ? 6 : 8)
            .contentShape(Rectangle())
            .contextMenu {
                Button("Delete", role: .destructive) { onDelete(todo.id) }
            }

            Divider().padding(.leading, compact ? 30 : 38)
        }
    }

    @ViewBuilder
    private var metaBadges: some View {
        HStack(spacing: 6) {
            if let d = todo.dueDate {
                HStack(spacing: 3) {
                    Image(systemName: "calendar").font(.system(size: 9))
                    Text(formatDueDate(d)).font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(isOverdue(d) && !todo.isCompleted ? .red : .secondary)
            }
            ForEach(todo.tags, id: \.self) { tag in
                Text(tag)
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Capsule().fill(Self.tagColor(tag).opacity(0.12)))
                    .foregroundColor(Self.tagColor(tag))
            }
        }
    }

    private func formatDueDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date)    { return "Today" }
        if cal.isDateInTomorrow(date) { return "Tomorrow" }
        let f = DateFormatter(); f.dateFormat = "d MMM"
        return f.string(from: date)
    }

    private func isOverdue(_ date: Date) -> Bool {
        date < Calendar.current.startOfDay(for: Date())
    }

    static func tagColor(_ tag: String) -> Color {
        switch tag.lowercased() {
        case "work":     return .blue
        case "personal": return .green
        case "urgent":   return .red
        default:
            let palette: [Color] = [.orange, .purple, .pink, .teal, .indigo]
            return palette[abs(tag.hashValue) % palette.count]
        }
    }
}

// MARK: - AddTodoSheet

struct AddTodoSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var title: String
    @State private var datePreset: DatePreset = .none
    @State private var customDate: Date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var selectedTags: Set<String> = []
    @State private var userTags: [String]
    @State private var addingTag = false
    @State private var newTagText = ""
    @State private var renamingTag: String? = nil
    @State private var renameText = ""
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isNewTagFocused: Bool
    @FocusState private var isRenameFocused: Bool

    let onAdd: (TodoItem) -> Void
    let onCancel: () -> Void

    enum DatePreset: CaseIterable, Equatable {
        case none, today, tomorrow, nextWeek, custom

        var label: String {
            switch self {
            case .none:     return "No Date"
            case .today:    return "Today"
            case .tomorrow: return "Tomorrow"
            case .nextWeek: return "Next Week"
            case .custom:   return "Custom"
            }
        }

        var icon: String {
            switch self {
            case .none:     return "xmark"
            case .today:    return "sun.max"
            case .tomorrow: return "sunrise.fill"
            case .nextWeek: return "calendar"
            case .custom:   return "calendar.badge.clock"
            }
        }

        func resolvedDate(custom: Date) -> Date? {
            let cal = Calendar.current
            let today = cal.startOfDay(for: Date())
            switch self {
            case .none:     return nil
            case .today:    return today
            case .tomorrow: return cal.date(byAdding: .day, value: 1, to: today)
            case .nextWeek: return cal.date(byAdding: .weekOfYear, value: 1, to: today)
            case .custom:   return custom
            }
        }
    }

    init(initialTitle: String = "", onAdd: @escaping (TodoItem) -> Void, onCancel: @escaping () -> Void) {
        _title = State(initialValue: initialTitle)
        _userTags = State(initialValue: SettingsService.shared.settings.userTags)
        self.onAdd = onAdd
        self.onCancel = onCancel
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color.black.opacity(0.15), Color.gray.opacity(0.07)]
                    : [Color.white, Color.gray.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("New Todo")
                        .font(.system(.title2, design: .rounded).weight(.semibold))
                    Spacer()
                    Button { onCancel() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary.opacity(0.45))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 14)

                Divider()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        // Title card
                        card {
                            VStack(alignment: .leading, spacing: 8) {
                                fieldLabel("TITLE", icon: "text.cursor")
                                TextField("What needs to be done?", text: $title)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 14))
                                    .focused($isTitleFocused)
                                    .onSubmit { commitAdd() }
                            }
                        }

                        // Due date card
                        card {
                            VStack(alignment: .leading, spacing: 10) {
                                fieldLabel("DUE DATE", icon: "calendar")

                                // Quick presets: 2-column grid (none/today/tomorrow/nextWeek)
                                let quickPresets: [DatePreset] = [.none, .today, .tomorrow, .nextWeek]
                                let columns = [GridItem(.flexible()), GridItem(.flexible())]
                                LazyVGrid(columns: columns, spacing: 8) {
                                    ForEach(quickPresets, id: \.label) { preset in
                                        presetButton(preset)
                                    }
                                }

                                // Custom full-width
                                presetButton(.custom)

                                if datePreset == .custom {
                                    Divider().padding(.vertical, 4)
                                    CalendarPicker(date: $customDate)
                                }
                            }
                        }

                        // Tags card
                        card {
                            VStack(alignment: .leading, spacing: 10) {
                                fieldLabel("TAGS", icon: "tag")

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(userTags, id: \.self) { tag in
                                            tagChip(tag)
                                        }
                                        // Inline add input OR + button
                                        if addingTag {
                                            HStack(spacing: 6) {
                                                TextField("Tag name…", text: $newTagText)
                                                    .textFieldStyle(.plain)
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .frame(minWidth: 60, maxWidth: 110)
                                                    .focused($isNewTagFocused)
                                                    .onSubmit { commitNewTag() }
                                                Button { commitNewTag() } label: {
                                                    Image(systemName: "checkmark")
                                                        .font(.system(size: 10, weight: .bold))
                                                        .foregroundColor(.accentColor)
                                                }
                                                .buttonStyle(.plain)
                                                Button { addingTag = false; newTagText = "" } label: {
                                                    Image(systemName: "xmark")
                                                        .font(.system(size: 10))
                                                        .foregroundColor(.secondary)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                            .padding(.horizontal, 10).padding(.vertical, 6)
                                            .background(
                                                Capsule().fill(Color.primary.opacity(0.06))
                                                    .overlay(Capsule().stroke(Color.accentColor.opacity(0.45), lineWidth: 1))
                                            )
                                            .onAppear {
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                                    isNewTagFocused = true
                                                }
                                            }
                                        } else {
                                            Button { addingTag = true } label: {
                                                HStack(spacing: 4) {
                                                    Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                                                    Text("New Tag").font(.system(size: 12, weight: .semibold))
                                                }
                                                .padding(.horizontal, 10).padding(.vertical, 6)
                                                .background(Capsule().fill(Color.primary.opacity(0.06)))
                                                .foregroundColor(.secondary)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }

                                // Inline rename row
                                if let tag = renamingTag {
                                    HStack(spacing: 8) {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 11))
                                            .foregroundColor(.accentColor)
                                        TextField(tag, text: $renameText)
                                            .textFieldStyle(.plain)
                                            .font(.system(size: 12, weight: .semibold))
                                            .focused($isRenameFocused)
                                            .onSubmit { commitRename(tag) }
                                        Spacer()
                                        Button { commitRename(tag) } label: {
                                            Text("Save").font(.system(size: 12, weight: .semibold)).foregroundColor(.accentColor)
                                        }
                                        .buttonStyle(.plain)
                                        Button { renamingTag = nil } label: {
                                            Image(systemName: "xmark").font(.system(size: 11)).foregroundColor(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 8)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.07)))
                                    .onAppear {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { isRenameFocused = true }
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                }

                Divider()

                HStack(spacing: 12) {
                    Button("Cancel") { onCancel() }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Button("Add Todo") { commitAdd() }
                        .buttonStyle(.borderedProminent)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .font(.system(size: 13, weight: .semibold))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { isTitleFocused = true }
        }
    }

    // MARK: Sub-views

    @ViewBuilder
    private func card<C: View>(@ViewBuilder content: () -> C) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.07),
                        lineWidth: 0.5
                    )
            )
    }

    @ViewBuilder
    private func fieldLabel(_ text: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 9, weight: .bold))
            Text(text).font(.system(size: 10, weight: .bold)).tracking(0.4)
        }
        .foregroundColor(.secondary)
    }

    @ViewBuilder
    private func presetButton(_ preset: DatePreset) -> some View {
        let selected = datePreset == preset
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { datePreset = preset }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: preset.icon).font(.system(size: 11, weight: .semibold))
                Text(preset.label).font(.system(size: 12, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 9).fill(selected ? Color.accentColor : Color.primary.opacity(0.06)))
            .foregroundColor(selected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func tagChip(_ tag: String) -> some View {
        let selected = selectedTags.contains(tag)
        Button {
            if selected { selectedTags.remove(tag) } else { selectedTags.insert(tag) }
        } label: {
            Text(tag)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().fill(selected ? TodoRow.tagColor(tag) : Color.primary.opacity(0.06)))
                .foregroundColor(selected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Rename") {
                renamingTag = tag
                renameText = tag
                addingTag = false
            }
            Divider()
            Button("Delete", role: .destructive) { deleteTag(tag) }
        }
    }

    // MARK: Tag management

    private func commitNewTag() {
        let trimmed = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !userTags.contains(trimmed) else {
            addingTag = false; newTagText = ""; return
        }
        withAnimation { userTags.append(trimmed) }
        selectedTags.insert(trimmed)
        addingTag = false
        newTagText = ""
        saveUserTags()
    }

    private func commitRename(_ oldTag: String) {
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != oldTag, !userTags.contains(trimmed) else {
            renamingTag = nil; return
        }
        if let i = userTags.firstIndex(of: oldTag) { userTags[i] = trimmed }
        if selectedTags.contains(oldTag) { selectedTags.remove(oldTag); selectedTags.insert(trimmed) }
        renamingTag = nil
        saveUserTags()
    }

    private func deleteTag(_ tag: String) {
        withAnimation { userTags.removeAll { $0 == tag } }
        selectedTags.remove(tag)
        if renamingTag == tag { renamingTag = nil }
        saveUserTags()
    }

    private func saveUserTags() {
        var s = SettingsService.shared.settings
        s.userTags = userTags
        SettingsService.shared.updateSetting(s)
    }

    private func commitAdd() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onAdd(TodoItem(title: trimmed, dueDate: datePreset.resolvedDate(custom: customDate), tags: Array(selectedTags).sorted()))
    }
}

// MARK: - CalendarPicker

struct CalendarPicker: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var date: Date
    @State private var displayedMonth: Date

    private let cal = Calendar.current
    private let weekdays = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

    init(date: Binding<Date>) {
        _date = date
        let comps = Calendar.current.dateComponents([.year, .month], from: date.wrappedValue)
        _displayedMonth = State(initialValue: Calendar.current.date(from: comps) ?? date.wrappedValue)
    }

    var body: some View {
        VStack(spacing: 10) {
            // Month navigation
            HStack {
                navButton(icon: "chevron.left") { navigate(-1) }
                Spacer()
                Text(monthTitle)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Spacer()
                navButton(icon: "chevron.right") { navigate(1) }
            }

            // Weekday headers
            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { d in
                    Text(d)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.5))
                        .frame(maxWidth: .infinity)
                }
            }

            // Day grid
            let cells = computeCells()
            VStack(spacing: 2) {
                ForEach(0..<(cells.count / 7), id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { col in
                            dayCell(cells[row * 7 + col])
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func navButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.primary.opacity(0.07)))
                .foregroundColor(.primary)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func dayCell(_ cell: DayCell) -> some View {
        let isSelected = cal.isDate(cell.date, inSameDayAs: date)
        let isToday    = cal.isDateInToday(cell.date)

        Button {
            withAnimation(.easeInOut(duration: 0.1)) { date = cell.date }
        } label: {
            ZStack {
                Circle()
                    .fill(
                        isSelected ? Color.accentColor :
                        isToday    ? Color.accentColor.opacity(0.14) :
                                     Color.clear
                    )
                    .frame(width: 27, height: 27)

                Text("\(cell.day)")
                    .font(.system(size: 12, weight: isSelected ? .bold : isToday ? .semibold : .regular,
                                  design: .rounded))
                    .foregroundColor(
                        isSelected          ? .white :
                        isToday             ? .accentColor :
                        cell.isCurrentMonth ? .primary :
                                              .secondary.opacity(0.28)
                    )
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, minHeight: 32)
        }
        .buttonStyle(.plain)
    }

    // MARK: Helpers

    private var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: displayedMonth)
    }

    private func navigate(_ delta: Int) {
        guard let next = cal.date(byAdding: .month, value: delta, to: displayedMonth) else { return }
        withAnimation(.easeInOut(duration: 0.18)) { displayedMonth = next }
    }

    private struct DayCell {
        let date: Date
        let day: Int
        let isCurrentMonth: Bool
    }

    private func computeCells() -> [DayCell] {
        let comps = cal.dateComponents([.year, .month], from: displayedMonth)
        guard let monthStart = cal.date(from: comps),
              let dayRange   = cal.range(of: .day, in: .month, for: monthStart) else { return [] }

        // Column offset: convert Sunday=1…Saturday=7 → Monday=0…Sunday=6
        let rawWeekday = cal.component(.weekday, from: monthStart)
        let firstCol   = (rawWeekday - 2 + 7) % 7

        var cells: [DayCell] = []

        // Trailing days from previous month
        for i in stride(from: firstCol - 1, through: 0, by: -1) {
            if let d = cal.date(byAdding: .day, value: -(i + 1), to: monthStart) {
                cells.append(DayCell(date: d, day: cal.component(.day, from: d), isCurrentMonth: false))
            }
        }

        // Current month
        for day in dayRange {
            if let d = cal.date(byAdding: .day, value: day - 1, to: monthStart) {
                cells.append(DayCell(date: d, day: day, isCurrentMonth: true))
            }
        }

        // Leading days from next month to complete the last row
        let trailing = (7 - cells.count % 7) % 7
        if trailing > 0, let last = cells.last?.date {
            for i in 1...trailing {
                if let d = cal.date(byAdding: .day, value: i, to: last) {
                    cells.append(DayCell(date: d, day: cal.component(.day, from: d), isCurrentMonth: false))
                }
            }
        }

        return cells
    }
}
