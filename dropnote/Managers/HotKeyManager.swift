import Carbon
import AppKit

final class HotKeyManager {
    static let shared = HotKeyManager()
    
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    
    private init() {}
    
    @discardableResult
    func registerGlobalSearchHotKey(keyCode: UInt32, modifiers: UInt32) -> OSStatus {
        unregisterGlobalSearchHotKey()
        installEventHandlerIfNeeded()
        
        var hotKeyID = EventHotKeyID(signature: OSType(0x48544B59), id: 1) // 'HTKY'
        var hotKeyRef: EventHotKeyRef?
        
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if status == noErr {
            self.hotKeyRef = hotKeyRef
        }
        
        return status
    }
    
    func updateGlobalSearchHotKey(keyCode: UInt32, modifiers: UInt32) -> Bool {
        let status = registerGlobalSearchHotKey(keyCode: keyCode, modifiers: modifiers)
        return status == noErr
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
    
    private func installEventHandlerIfNeeded() {
        guard eventHandler == nil else {
            return
        }
        
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        
        var handler: EventHandlerRef?
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, _, _) -> OSStatus in
                HotKeyManager.shared.handleHotKeyEvent()
                return noErr
            },
            1,
            &eventType,
            nil,
            &handler
        )
        
        eventHandler = handler
    }
    
    private func handleHotKeyEvent() {
        DispatchQueue.main.async {
            SearchWindowController.shared.toggle()
        }
    }
}
