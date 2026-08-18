import AppKit
import ApplicationServices
import Foundation

public final class TextTarget: @unchecked Sendable {
    fileprivate let element: AXUIElement

    fileprivate init(element: AXUIElement) {
        self.element = element
    }
}

@MainActor
public enum TextInjector {
    public static func requestAccessibilityPermission() -> Bool {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    public static func captureTarget() throws -> TextTarget {
        guard AXIsProcessTrusted() else {
            throw VoiceQueryError.accessibilityPermissionMissing
        }

        let systemWide = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        let focusStatus = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        )
        guard focusStatus == .success, let focusedValue else {
            throw VoiceQueryError.noFocusedInput
        }

        let focusedElement = focusedValue as! AXUIElement
        if isSecureInput(focusedElement) {
            throw VoiceQueryError.secureInputField
        }

        return TextTarget(element: focusedElement)
    }

    public static func insert(_ text: String, into target: TextTarget? = nil) throws {
        let focusedElement: AXUIElement
        if let target {
            focusedElement = target.element
        } else {
            focusedElement = try captureTarget().element
        }

        let directStatus = AXUIElementSetAttributeValue(
            focusedElement,
            kAXSelectedTextAttribute as CFString,
            text as CFString
        )
        if directStatus == .success {
            return
        }

        try pasteThroughClipboard(text)
    }

    private static func isSecureInput(_ element: AXUIElement) -> Bool {
        var subroleValue: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            element,
            kAXSubroleAttribute as CFString,
            &subroleValue
        )
        guard status == .success, let subrole = subroleValue as? String else {
            return false
        }
        return subrole == kAXSecureTextFieldSubrole as String
    }

    private static func pasteThroughClipboard(_ text: String) throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            throw VoiceQueryError.noFocusedInput
        }

        guard let source = CGEventSource(stateID: .combinedSessionState),
              let keyDown = CGEvent(
                keyboardEventSource: source,
                virtualKey: 0x09,
                keyDown: true
              ),
              let keyUp = CGEvent(
                keyboardEventSource: source,
                virtualKey: 0x09,
                keyDown: false
              ) else {
            throw VoiceQueryError.noFocusedInput
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
