import SwiftUI
import AppKit

struct SearchWindowView: View {
    @StateObject private var searchService = NoteSearchService.shared
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
            searchField
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)
            
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
            setupEventMonitors()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFieldFocused = true
            }
            performSearch()
        }
        .onDisappear {
            removeEventMonitors()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ResetSearchWindow"))) { _ in
            resetSearchState()
        }
        .id(windowID)
    }
    
    // MARK: - View Components
    
    @ViewBuilder
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
    
    @ViewBuilder
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
    
    @ViewBuilder
    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(Array(searchResults.enumerated()), id: \.element.id) { index, result in
                        SearchResultRow(
                            result: result,
                            index: index,
                            isSelected: selectedIndex == index,
                            onTap: {
                                selectedIndex = index
                                openSelectedNote()
                            }
                        )
                        .id(index)
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
    
    // MARK: - Private Methods
    
    private func setupEventMonitors() {
        setupKeyboardMonitor()
        setupClickMonitor()
    }
    
    private func removeEventMonitors() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
    }
    
    private func setupKeyboardMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            return self.handleKeyEvent(event)
        }
    }
    
    private func setupClickMonitor() {
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { event in
            if let window = SearchWindowController.shared.window {
                let clickLocation = NSEvent.mouseLocation
                if !window.frame.contains(clickLocation) {
                    SearchWindowController.shared.hide()
                }
            }
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        switch Int(event.keyCode) {
        case 126: // Up arrow
            if !searchResults.isEmpty {
                selectedIndex = max(0, selectedIndex - 1)
            }
            return nil
            
        case 125: // Down arrow
            if !searchResults.isEmpty {
                selectedIndex = min(searchResults.count - 1, selectedIndex + 1)
            }
            return nil
            
        case 36: // Return/Enter
            if !searchResults.isEmpty {
                openSelectedNote()
            }
            return nil
            
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
            return event
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
        searchResults = searchService.search(query: searchQuery, limit: 10)
        selectedIndex = 0
    }
    
    private func resetSearchState() {
        searchQuery = ""
        selectedIndex = 0
        windowID = UUID()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isSearchFieldFocused = true
        }
        performSearch()
    }
    
    private func openSelectedNote() {
        guard selectedIndex < searchResults.count else {
            return
        }
        
        let result = searchResults[selectedIndex]
        SearchWindowController.shared.hide()
        SearchManager.shared.openNote(result.id)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if let appDelegate = AppDelegate.shared {
                if appDelegate.popover?.isShown == true {
                    appDelegate.popover.performClose(nil)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        appDelegate.togglePopover(nil)
                        NSApp.activate(ignoringOtherApps: true)
                    }
                } else {
                    appDelegate.togglePopover(nil)
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
    }
}
