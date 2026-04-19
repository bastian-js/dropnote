import SwiftUI

// MARK: - TodoListView

struct TodoListView: View {
    @Binding var todos: [TodoItem]
    var compact: Bool = false
    var showBorder: Bool = true
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
            .frame(width: 380, height: 340)
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
            LazyVStack(spacing: 0) {
                ForEach(pendingTodos) { todo in
                    TodoRow(todo: todo, compact: compact, onToggle: toggleTodo, onDelete: deleteTodo)
                }
                if !completedTodos.isEmpty {
                    if !compact {
                        HStack {
                            Text("Completed")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                            Spacer()
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
            HStack(alignment: .top, spacing: compact ? 8 : 10) {
                Button { onToggle(todo.id) } label: {
                    Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: compact ? 14 : 16, weight: .medium))
                        .foregroundColor(todo.isCompleted ? .accentColor : Color.secondary.opacity(0.4))
                }
                .buttonStyle(.plain)
                .padding(.top, 1)

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
                        .padding(.top, 2)
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
        default:         return .orange
        }
    }
}

// MARK: - AddTodoSheet

struct AddTodoSheet: View {
    @State private var title: String
    @State private var hasDueDate = false
    @State private var dueDate: Date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var selectedTags: Set<String> = []
    @FocusState private var isTitleFocused: Bool

    let onAdd: (TodoItem) -> Void
    let onCancel: () -> Void
    static let predefinedTags = ["Work", "Personal", "Urgent"]

    init(initialTitle: String = "", onAdd: @escaping (TodoItem) -> Void, onCancel: @escaping () -> Void) {
        _title = State(initialValue: initialTitle)
        self.onAdd = onAdd
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("New Todo")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                Spacer()
                Button { onCancel() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18).padding(.top, 16).padding(.bottom, 12)

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                // Title
                VStack(alignment: .leading, spacing: 6) {
                    Label("TITLE", systemImage: "text.cursor")
                        .font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                        .labelStyle(.titleOnly)
                    TextField("What needs to be done?", text: $title)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.primary.opacity(0.05))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                        )
                        .focused($isTitleFocused)
                        .onSubmit { commitAdd() }
                }

                // Due Date
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("DUE DATE")
                            .font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                        Spacer()
                        Toggle("", isOn: $hasDueDate).labelsHidden().toggleStyle(.switch).scaleEffect(0.78)
                    }
                    if hasDueDate {
                        DatePicker("", selection: $dueDate, displayedComponents: .date)
                            .labelsHidden().datePickerStyle(.compact)
                    }
                }

                // Tags
                VStack(alignment: .leading, spacing: 8) {
                    Text("TAGS").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                    HStack(spacing: 8) {
                        ForEach(Self.predefinedTags, id: \.self) { tag in tagChip(tag) }
                    }
                }
            }
            .padding(18)

            Spacer()
            Divider()

            HStack(spacing: 12) {
                Button("Cancel") { onCancel() }
                    .buttonStyle(.plain).foregroundColor(.secondary)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button("Add Todo") { commitAdd() }
                    .buttonStyle(.borderedProminent)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { isTitleFocused = true }
        }
    }

    @ViewBuilder
    private func tagChip(_ tag: String) -> some View {
        let selected = selectedTags.contains(tag)
        Button {
            if selected { selectedTags.remove(tag) } else { selectedTags.insert(tag) }
        } label: {
            Text(tag)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(selected ? TodoRow.tagColor(tag) : Color.primary.opacity(0.06)))
                .foregroundColor(selected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    private func commitAdd() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onAdd(TodoItem(title: trimmed, dueDate: hasDueDate ? dueDate : nil, tags: Array(selectedTags).sorted()))
    }
}
