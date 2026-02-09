import Carbon
import AppKit

class HotKeyManager {
    static let shared = HotKeyManager()
    
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    
    private init() {}
    
    func registerGlobalSearchHotKey() {
        // CMD + OPTION + F
        let keyCode: UInt32 = 3 // F key
        let modifiers: UInt32 = UInt32(cmdKey | optionKey)
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        var handler: EventHandlerRef?
        InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, event, userData) -> OSStatus in
            HotKeyManager.shared.handleHotKeyEvent()
            return noErr
        }, 1, &eventType, nil, &handler)
        
        eventHandler = handler
        
        var hotKeyID = EventHotKeyID(signature: OSType(0x48544B59), id: 1) // 'HTKY' signature
        var hotKeyRef: EventHotKeyRef?
        
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        
        if status == noErr {
            self.hotKeyRef = hotKeyRef
            print("✅ Global hotkey registered: CMD+OPTION+F")
        } else {
            print("❌ Failed to register hotkey, status: \(status)")
        }
    }
    
    func unregisterGlobalSearchHotKey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }
    
    private func handleHotKeyEvent() {
        DispatchQueue.main.async {
            SearchWindowController.shared.toggle()
        }
    }
}
