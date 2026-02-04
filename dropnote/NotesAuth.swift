import Foundation
import AppKit
import LocalAuthentication
import Security

final class NotesAuth {
    static let shared = NotesAuth()

    private let service = "xyz.bbastian.dropnote"
    private let account = "notes_password_v1"

    private init() {}

    func ensurePasswordOrBiometricsConfigured() async -> Bool {
        let ctx = LAContext()
        var err: NSError?
        if ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) {
            return true
        }

        if getPassword() != nil { return true }
        return await promptAndSetPassword(title: "Set Password", message: "Set an app password to lock notes.")
    }

    @MainActor
    func authenticate(reason: String) async -> Bool {
        let ctx = LAContext()
        ctx.localizedCancelTitle = "Cancel"
        var err: NSError?
        if ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) {
            do {
                return try await ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            } catch {
            }
        }
        guard let existing = getPassword() else {
            return promptAndSetPassword(title: "Set Password", message: "Set an app password to unlock locked notes.")
        }

        let entered = promptForSecureText(title: "Enter Password", message: reason)
        return entered == existing
    }

    @MainActor
    private func promptAndSetPassword(title: String, message: String) -> Bool {
        let p1 = promptForSecureText(title: title, message: message + "\n\nPassword:")
        guard !p1.isEmpty else { return false }
        let p2 = promptForSecureText(title: title, message: "Confirm password:")
        guard p1 == p2 else { return false }
        return setPassword(p1)
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

        let resp = alert.runModal()
        guard resp == .alertFirstButtonReturn else { return "" }
        return field.stringValue
    }

    private func setPassword(_ value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)

        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
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
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

