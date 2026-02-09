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
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            do {
                return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            } catch {
                // Fall through to password authentication
            }
        }
        
        guard let existingPassword = getPassword() else {
            return await promptAndSetPassword(
                title: "Set Password",
                message: "Set an app password to unlock locked notes."
            )
        }
        
        let enteredPassword = promptForSecureText(title: "Enter Password", message: reason)
        return enteredPassword == existingPassword
    }
    
    // MARK: - Private Methods
    
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
