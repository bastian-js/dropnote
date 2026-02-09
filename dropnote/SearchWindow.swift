import SwiftUI
import AppKit

// Custom window that can become key window
class SearchNSWindow: NSWindow {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }
}

class SearchWindowController: NSWindowController {
    static let shared = SearchWindowController()
    
    private init() {
        let window = SearchNSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 500),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.isMovableByWindowBackground = true
        window.hasShadow = true
        window.contentView = NSHostingView(rootView: SearchWindowView())
        
        super.init(window: window)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func show() {
        guard let window = window, let screen = NSScreen.main else { return }
        
        // Center window on screen
        let screenFrame = screen.visibleFrame
        let windowFrame = window.frame
        let x = screenFrame.midX - windowFrame.width / 2
        let y = screenFrame.midY - windowFrame.height / 2 + 100
        
        window.setFrame(NSRect(x: x, y: y, width: windowFrame.width, height: windowFrame.height), display: true)
        
        // Reset search state
        NotificationCenter.default.post(name: Notification.Name("ResetSearchWindow"), object: nil)
        
        window.orderFrontRegardless()
        window.makeKey()
        NSApp.activate(ignoringOtherApps: true)
        
        // Force focus on search field after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            window.makeFirstResponder(window.contentView)
        }
    }
    
    func hide() {
        window?.orderOut(nil)
    }
    
    func toggle() {
        if window?.isVisible == true {
            hide()
        } else {
            show()
        }
    }
}

struct SearchWindowView: View {
    @StateObject private var searchManager = SearchIndexManager.shared
    @State private var searchQuery: String = ""
    @State private var searchResults: [SearchResult] = []
    @State private var selectedIndex: Int = 0
    @FocusState private var isSearchFieldFocused: Bool
    @State private var debounceWorkItem: DispatchWorkItem?
    @State private var windowID = UUID()
    @State private var eventMonitor: Any?
    @State private var clickMonitor: Any?
    
    var body: some View {
        VStack(spacing: 0) {
            // Search field
            searchField
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)
            
            // Results list or empty state
            if searchResults.isEmpty {
                emptyState
            } else {
                resultsList
            }
        }
        .frame(width: 640, height: 500)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.3), radius: 40, x: 0, y: 20)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            setupEventMonitor()
            setupClickMonitor()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFieldFocused = true
            }
            performSearch()
        }
        .onDisappear {
            removeEventMonitor()
            removeClickMonitor()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ResetSearchWindow"))) { _ in
            searchQuery = ""
            selectedIndex = 0
            windowID = UUID()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFieldFocused = true
            }
            performSearch()
        }
        .id(windowID)
    }
    
    private func setupEventMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            return self.handleKeyEvent(event)
        }
    }
    
    private func removeEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    private func setupClickMonitor() {
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { event in
            // Check if click is inside the search window
            if let window = SearchWindowController.shared.window {
                let clickLocation = NSEvent.mouseLocation
                if !window.frame.contains(clickLocation) {
                    // Click outside window
                    SearchWindowController.shared.hide()
                }
            }
        }
    }
    
    private func removeClickMonitor() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        switch Int(event.keyCode) {
        case 126: // Up arrow
            if !searchResults.isEmpty {
                selectedIndex = max(0, selectedIndex - 1)
                return nil
            }
        case 125: // Down arrow
            if !searchResults.isEmpty {
                selectedIndex = min(searchResults.count - 1, selectedIndex + 1)
                return nil
            }
        case 36: // Return/Enter
            if !searchResults.isEmpty {
                openSelectedNote()
                return nil
            }
        case 53: // Escape
            if searchQuery.isEmpty {
                SearchWindowController.shared.hide()
            } else {
                searchQuery = ""
                selectedIndex = 0
                performSearch()
            }
            return nil
        default:
            break
        }
        return event
    }
    
    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.secondary)
            
            TextField("search notes...", text: $searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 20))
                .focused($isSearchFieldFocused)
                .onChange(of: searchQuery) { oldValue, newValue in
                    print("Search query changed: '\(newValue)'")
                    scheduleSearch()
                }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: searchQuery.isEmpty ? "clock" : "magnifyingglass")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.secondary)
            
            Text(searchQuery.isEmpty ? "Recent Notes" : "No notes found")
                .font(.title3)
                .foregroundColor(.secondary)
            
            if !searchQuery.isEmpty {
                Text("Try a different search term")
                    .font(.subheadline)
                    .foregroundColor(.secondary.opacity(0.8))
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
    
    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(Array(searchResults.enumerated()), id: \.element.id) { index, result in
                        resultRow(result: result, index: index)
                            .id(index)
                            .onTapGesture {
                                selectedIndex = index
                                openSelectedNote()
                            }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .onChange(of: selectedIndex) { _, newValue in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }
        }
    }
    
    private func resultRow(result: SearchResult, index: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            Image(systemName: "doc.text.fill")
                .font(.system(size: 20))
                .foregroundColor(.accentColor)
                .frame(width: 32)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(result.note.title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                    .foregroundColor(.primary)
                
                // Preview with highlighting
                if !result.preview.isEmpty {
                    highlightedText(result.preview, ranges: result.highlightRanges)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Last edited date
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatDate(result.note.lastModified))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                if result.matchedInTitle {
                    Text("title match")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15))
                        .cornerRadius(4)
                }
            }
            .frame(width: 100)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(selectedIndex == index ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(selectedIndex == index ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
    }
    
    private func highlightedText(_ text: String, ranges: [Range<String.Index>]) -> Text {
        guard !ranges.isEmpty else {
            return Text(text)
        }
        
        var result = Text("")
        var currentIndex = text.startIndex
        
        for range in ranges {
            // Add text before highlight
            if currentIndex < range.lowerBound {
                result = result + Text(String(text[currentIndex..<range.lowerBound]))
            }
            
            // Add highlighted text
            result = result + Text(String(text[range]))
                .foregroundColor(.accentColor)
                .fontWeight(.semibold)
            
            currentIndex = range.upperBound
        }
        
        // Add remaining text
        if currentIndex < text.endIndex {
            result = result + Text(String(text[currentIndex..<text.endIndex]))
        }
        
        return result
    }
    
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return "today, " + formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "yesterday"
        } else if calendar.dateComponents([.day], from: date, to: now).day ?? 0 < 7 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd-MM-yyyy"
            return formatter.string(from: date)
        }
    }
    
    private func scheduleSearch() {
        debounceWorkItem?.cancel()
        
        let workItem = DispatchWorkItem {
            DispatchQueue.main.async {
                self.performSearch()
            }
        }
        
        debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: workItem)
    }
    
    private func performSearch() {
        print("Performing search for: '\(searchQuery)'")
        let results = searchManager.search(query: searchQuery, limit: 10)
        print("Found \(results.count) results")
        searchResults = results
        selectedIndex = 0
    }
    
    private func openSelectedNote() {
        guard selectedIndex < searchResults.count else { 
            print("No result selected or out of bounds")
            return 
        }
        let result = searchResults[selectedIndex]
        print("Opening note: \(result.note.title) with ID: \(result.id)")
        
        // Close search window first
        SearchWindowController.shared.hide()
        
        // Use SearchManager to tell ContentView which note to open
        SearchManager.shared.openNote(result.id)
        
        // Then show popover
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            print("About to show popover...")
            
            if let appDelegate = AppDelegate.shared {
                print("Got AppDelegate.shared, popover: \(appDelegate.popover)")
                print("Showing popover...")
                
                // Close popover first if open
                if appDelegate.popover?.isShown == true {
                    appDelegate.popover.performClose(nil)
                    
                    // Reopen after short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        appDelegate.togglePopover(nil)
                        NSApp.activate(ignoringOtherApps: true)
                    }
                } else {
                    // Just open it
                    appDelegate.togglePopover(nil)
                    NSApp.activate(ignoringOtherApps: true)
                }
            } else {
                print("ERROR: AppDelegate.shared is nil!")
            }
        }
    }
}
