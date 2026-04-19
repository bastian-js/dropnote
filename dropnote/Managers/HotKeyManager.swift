import Carbon
import AppKit

final class HotKeyManager {
    static let shared = HotKeyManager()

    // Search hotkey (id = 1)
    private var searchHotKeyRef: EventHotKeyRef?
    // Full-window hotkey (id = 2)
    private var fullWindowHotKeyRef: EventHotKeyRef?
    // Single shared event handler for all hotkeys
    private var eventHandler: EventHandlerRef?

    private init() {}

    // MARK: - Search Hotkey

    @discardableResult
    func registerGlobalSearchHotKey(keyCode: UInt32, modifiers: UInt32) -> OSStatus {
        unregisterHotKey(&searchHotKeyRef)
        installEventHandlerIfNeeded()
        return registerHotKey(keyCode: keyCode, modifiers: modifiers, id: 1, ref: &searchHotKeyRef)
    }

    func updateGlobalSearchHotKey(keyCode: UInt32, modifiers: UInt32) -> Bool {
        return registerGlobalSearchHotKey(keyCode: keyCode, modifiers: modifiers) == noErr
    }

    func unregisterGlobalSearchHotKey() {
        unregisterHotKey(&searchHotKeyRef)
    }

    // MARK: - Full-Window Hotkey

    @discardableResult
    func registerFullWindowHotKey(keyCode: UInt32, modifiers: UInt32) -> OSStatus {
        unregisterHotKey(&fullWindowHotKeyRef)
        installEventHandlerIfNeeded()
        return registerHotKey(keyCode: keyCode, modifiers: modifiers, id: 2, ref: &fullWindowHotKeyRef)
    }

    func updateFullWindowHotKey(keyCode: UInt32, modifiers: UInt32) -> Bool {
        return registerFullWindowHotKey(keyCode: keyCode, modifiers: modifiers) == noErr
    }

    // MARK: - Private Helpers

    private func registerHotKey(keyCode: UInt32, modifiers: UInt32, id: UInt32, ref: inout EventHotKeyRef?) -> OSStatus {
        var hotKeyID = EventHotKeyID(signature: OSType(0x44524F50), id: id) // 'DROP'
        var newRef: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &newRef)
        if status == noErr { ref = newRef }
        return status
    }

    private func unregisterHotKey(_ ref: inout EventHotKeyRef?) {
        if let r = ref { UnregisterEventHotKey(r); ref = nil }
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandler == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        var handler: EventHandlerRef?
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, theEvent, _) -> OSStatus in
                var hkID = EventHotKeyID()
                GetEventParameter(
                    theEvent,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hkID
                )
                HotKeyManager.shared.handleHotKeyPress(id: hkID.id)
                return noErr
            },
            1, &eventType, nil, &handler
        )
        eventHandler = handler
    }

    func handleHotKeyPress(id: UInt32) {
        DispatchQueue.main.async {
            switch id {
            case 1: SearchWindowController.shared.toggle()
            case 2: FullWindowController.shared.show()
            default: break
            }
        }
    }
}
