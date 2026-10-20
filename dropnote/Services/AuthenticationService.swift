import Foundation
import AppKit
import LocalAuthentication
import Security

final class AuthenticationService {
    static let shared = AuthenticationService()
    
    private let service = "xyz.bbastian.dropnote"
    private let account = "notes_password_v1"
    
    private init() {}
    
    // MARK: - Public Methods
    
    func ensurePasswordOrBiometricsConfigured() async -> Bool {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            return true
        }
        
        if getPassword() != nil {
            return true
        }
        return await promptAndSetPassword(
            title: "Set Password",
            message: "Set an app password to lock notes."
        )
    }
    
    @MainActor
    func authenticate(reason: String) async -> Bool {
        // Keep the menu bar popover open while the system auth prompt takes focus.
        AppDelegate.shared?.beginAuthenticationHold()
        defer { AppDelegate.shared?.endAuthenticationHold() }

        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            // The system sheet already falls back to the login password, so its
            // answer is final. Cancelling or failing must never drop through to the
            // app-password path below.
            return (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) ?? false
        }

        guard let existingPassword = getPassword() else {
            // Nothing to verify against. Offering to set a password here would let
            // whoever is at the keyboard pick one and unlock the note.
            showAlert(
                title: "Can't Unlock",
                message: "No unlock method is available. Set up Touch ID or a login password in System Settings."
            )
            return false
        }

        let enteredPassword = promptForSecureText(title: "Enter Password", message: reason)
        return enteredPassword == existingPassword
    }

    /// Authenticates, then decrypts the note's body into memory. Every way of
    /// revealing a locked note's content goes through here.
    @MainActor
    func unlock(noteID: UUID, reason: String) async -> Bool {
        guard await authenticate(reason: reason) else { return false }
        guard NotesStore.shared.unseal(id: noteID) else {
            showAlert(
                title: "Can't Decrypt Note",
                message: "The encryption key for locked notes couldn't be read from your Keychain. The note's encrypted content has been left unchanged."
            )
            return false
        }
        return true
    }

    // MARK: - Private Methods

    @MainActor
    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @MainActor
    private func promptAndSetPassword(title: String, message: String) -> Bool {
        let password1 = promptForSecureText(title: title, message: message + "\n\nPassword:")
        guard !password1.isEmpty else {
            return false
        }
        
        let password2 = promptForSecureText(title: title, message: "Confirm password:")
        guard password1 == password2 else {
            return false
        }
        
        return setPassword(password1)
    }
    
    @MainActor
    private func promptForSecureText(title: String, message: String) -> String {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        alert.accessoryView = field
        
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else {
            return ""
        }
        return field.stringValue
    }
    
    private func setPassword(_ value: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            return false
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        SecItemDelete(query as CFDictionary)
        
        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }
    
    private func getPassword() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}
