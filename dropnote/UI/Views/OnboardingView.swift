import SwiftUI
import AppKit

struct OnboardingView: View {
    @State private var currentScreen = 0
    @State private var isExitingViaEscape = false
    @State private var isCompletionInProgress = false
    @State private var eventMonitor: Any?
    
    var body: some View {
        ZStack {
            VisualEffectView(material: .menu, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.08),
                    Color.black.opacity(0.02)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Group {
                    if currentScreen == 0 {
                        Screen1View {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                currentScreen = 1
                            }
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    } else if currentScreen == 1 {
                        Screen2View(
                            onContinue: {
                                withAnimation(.easeInOut(duration: 0.4)) {
                                    currentScreen = 2
                                }
                            },
                            onBack: {
                                withAnimation(.easeInOut(duration: 0.4)) {
                                    currentScreen = 0
                                }
                            }
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    } else if currentScreen == 2 {
                        Screen3View(
                            onStartUsing: completeOnboarding,
                            onBack: {
                                withAnimation(.easeInOut(duration: 0.4)) {
                                    currentScreen = 1
                                }
                            }
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
                .id(currentScreen)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            KeyboardOverlayView(handleKeyPress: handleKeyboard)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { _ in
            if !isExitingViaEscape && !isCompletionInProgress {
                resetOnboarding()
            }
        }
        .onAppear {
            setupWindow()
            setupGlobalKeyMonitor()
        }
    }
    
    private func setupGlobalKeyMonitor() {
        if let window = NSApplication.shared.windows.first(where: { $0.title == "DropNote Onboarding" }) {
            var mutableSelf = self
            let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if window.isKeyWindow || window.isVisible {
                    if mutableSelf.handleKeyboard(event: event) == true {
                        return nil
                    }
                }
                return event
            }
            mutableSelf.eventMonitor = monitor
        }
    }
    
    private func handleKeyboard(event: NSEvent) -> Bool {
        guard event.type == .keyDown else { return false }
        switch Int(event.keyCode) {
        case 123: goToPreviousScreen(); return true
        case 124: advanceToNextScreen(); return true
        case 36: handleReturn(); return true
        case 53: exitViaEscape(); return true
        default: return false
        }
    }
    
    private func advanceToNextScreen() {
        if currentScreen < 2 {
            withAnimation(.easeInOut(duration: 0.4)) {
                currentScreen += 1
            }
        }
    }
    
    private func goToPreviousScreen() {
        if currentScreen > 0 {
            withAnimation(.easeInOut(duration: 0.4)) {
                currentScreen -= 1
            }
        }
    }
    
    private func handleReturn() {
        if currentScreen == 0 {
            advanceToNextScreen()
        } else if currentScreen == 1 {
            SearchWindowController.shared.show()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeInOut(duration: 0.4)) {
                    currentScreen = 2
                }
            }
        } else {
            completeOnboarding()
        }
    }
    
    private func completeOnboarding() {
        isCompletionInProgress = true
        var settings = SettingsService.shared.settings
        settings.hasCompletedOnboarding = true
        SettingsService.shared.updateSetting(settings)
        
        if let window = NSApplication.shared.windows.first(where: { $0.title == "DropNote Onboarding" }) {
            window.close()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            AppDelegate.shared.togglePopover(nil)
        }
    }
    
    private func resetOnboarding() {
        var settings = SettingsService.shared.settings
        settings.hasCompletedOnboarding = false
        SettingsService.shared.updateSetting(settings)
    }
    
    private func exitViaEscape() {
        isExitingViaEscape = true
        resetOnboarding()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApplication.shared.terminate(nil)
        }
    }
    
    private func setupWindow() {
        if let window = NSApplication.shared.windows.first(
            where: { $0.title == "DropNote Onboarding" }
        ) {
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces]
            window.isMovableByWindowBackground = true

            window.setContentSize(NSSize(width: 520, height: 680))
            window.minSize = NSSize(width: 480, height: 640)
            window.maxSize = NSSize(width: 600, height: 760)

            window.center()
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
}

// MARK: - Visual Effect View (Glassmorphism)
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Keyboard Handling View
struct KeyboardOverlayView: NSViewRepresentable {
    let handleKeyPress: (NSEvent) -> Bool
    
    func makeNSView(context: Context) -> NSView {
        let view = KeyboardCapturingView()
        view.onKeyPress = handleKeyPress
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

class KeyboardCapturingView: NSView {
    var onKeyPress: ((NSEvent) -> Bool)?
    
    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        let handled = onKeyPress?(event) ?? false
        if !handled {
            super.keyDown(with: event)
        }
    }
    
    override func becomeFirstResponder() -> Bool {
        return true
    }
}

// MARK: - Screen 1: Welcome
struct Screen1View: View {
    var onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 20) {
                Image(systemName: "note.text")
                    .font(.system(size: 56, weight: .thin))
                    .foregroundColor(.blue)
                    .opacity(0.9)
                
                VStack(spacing: 12) {
                    Text("DropNote")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                    
                    Text("Instant notes. Global search.")
                        .font(.system(size: 20, weight: .semibold))
                    
                    Text("Access your notes from anywhere on macOS.")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.secondary)
                }
                .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            VStack(spacing: 14) {
                Button(action: onContinue) {
                    Text("Continue")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.blue)
                                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                        )
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                
                Text("Use arrow keys or click to navigate")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(36)
    }
}

// MARK: - Screen 2: Global Search
struct Screen2View: View {
    var onContinue: () -> Void
    var onBack: () -> Void
    @State private var isEditingHotkey = false
    @State private var recordingHotkey = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        Text("Search all your notes...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.08))
                            .strokeBorder(Color.gray.opacity(0.15), lineWidth: 1)
                    )
                    
                    HStack(spacing: 12) {
                        SearchResultPreview(title: "Meeting Notes", preview: "Discussed Q1 roadmap...")
                        SearchResultPreview(title: "Ideas", preview: "New feature concept for...")
                        SearchResultPreview(title: "Journal", preview: "Today's thoughts on...")
                    }
                }
                
                VStack(spacing: 14) {
                    HStack(spacing: 12) {
                        VStack(spacing: 6) {
                            Text("⌘ + ⌥ + F")
                                .font(.system(size: 24, weight: .bold, design: .monospaced))
                                .tracking(0.5)
                                .foregroundColor(.blue)
                            
                            Text("Press keys to change...") 
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(.secondary.opacity(0.5))
                                .opacity(recordingHotkey ? 1 : 0)
                        }
                        
                        Spacer()
                        
                        Button(action: { recordingHotkey.toggle() }) {
                            Text(recordingHotkey ? "Recording..." : "Change")
                                .font(.system(size: 13, weight: .semibold))
                                .frame(width: 90, height: 32)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(recordingHotkey ? Color.orange : Color.gray.opacity(0.2))
                                )
                                .foregroundColor(recordingHotkey ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Text("Search all your notes instantly. No dock. No windows.")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            Spacer()
            
            VStack(spacing: 12) {
                Button(action: onContinue) {
                    Text("Continue")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.blue)
                                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                        )
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                
                Button(action: onBack) {
                    Text("Back")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(36)
    }
}

// MARK: - Screen 3: Auto-Save
struct Screen3View: View {
    var onStartUsing: () -> Void
    var onBack: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Untitled")
                                .font(.system(size: 15, weight: .semibold))
                            
                            Text("Just now")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                        Spacer()
                    }
                    
                    Divider()
                        .opacity(0.3)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("✦ Type your notes here")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.secondary)
                        
                        Text("✦ They're saved automatically")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.secondary)
                        
                        Text("✦ No manual save needed")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .frame(height: 160)
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.06))
                        .strokeBorder(Color.gray.opacity(0.15), lineWidth: 1)
                )
                
                VStack(spacing: 12) {
                    Text("Write. Close. It's saved.")
                        .font(.system(size: 20, weight: .semibold))
                    
                    Text("No lost drafts. Just frictionless writing.")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.secondary)
                }
                .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            VStack(spacing: 12) {
                Button(action: onStartUsing) {
                    Text("Start using DropNote")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.blue)
                                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                        )
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                
                Button(action: onBack) {
                    Text("Back")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(36)
    }
}

// MARK: - Helpers
struct SearchResultPreview: View {
    let title: String
    let preview: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
            
            Text(preview)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.gray.opacity(0.06))
        .cornerRadius(8)
    }
}

#Preview {
    OnboardingView()
}
