import Cocoa

enum TextInjector {
    private static let pasteboardType: NSPasteboard.PasteboardType = .string

    /// Pastes `text` into the focused app by setting the clipboard and posting Cmd+V.
    /// The previous clipboard contents are restored after a short delay.
    static func paste(_ text: String) {
        guard !text.isEmpty else { return }
        let pb = NSPasteboard.general

        let snapshot = capturePasteboard(pb)
        pb.clearContents()
        pb.setString(text, forType: pasteboardType)

        postCommandV()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            restorePasteboard(pb, snapshot: snapshot)
        }
    }

    private static func postCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9 // 'v'

        let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        down?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)

        let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        up?.flags = .maskCommand
        up?.post(tap: .cghidEventTap)
    }

    private static func capturePasteboard(_ pb: NSPasteboard) -> [[NSPasteboard.PasteboardType: Data]] {
        guard let items = pb.pasteboardItems else { return [] }
        return items.map { item in
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) { dict[type] = data }
            }
            return dict
        }
    }

    private static func restorePasteboard(_ pb: NSPasteboard, snapshot: [[NSPasteboard.PasteboardType: Data]]) {
        guard !snapshot.isEmpty else { return }
        pb.clearContents()
        let items = snapshot.map { dict -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in dict { item.setData(data, forType: type) }
            return item
        }
        pb.writeObjects(items)
    }
}
