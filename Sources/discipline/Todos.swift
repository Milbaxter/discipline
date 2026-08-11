import AppKit
import Foundation

/// Todo list pill shown just above the timer pill, bottom-right. The ✕ hides
/// it for the current session; every new session shows it again.
final class TodoWindow: NSPanel {
    var onClose: (() -> Void)?
    private var lines: [String] = ["loading…"]

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 250, height: 44),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        hidesOnDeactivate = false
        rebuild()
        orderFrontRegardless()
    }

    func update(lines: [String]) {
        self.lines = lines.isEmpty ? ["no open todos"] : lines
        rebuild()
        reposition()
    }

    private func rebuild() {
        let lineHeight: CGFloat = 16
        let headerPad: CGFloat = 26
        let bottomPad: CGFloat = 8
        let size = NSSize(width: 250,
                          height: headerPad + CGFloat(lines.count) * lineHeight + bottomPad)
        setContentSize(size)

        let container = NSView(frame: NSRect(origin: .zero, size: size))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.35).cgColor
        container.layer?.cornerRadius = 8

        let title = NSTextField(labelWithString: "todos")
        title.font = .systemFont(ofSize: 10, weight: .semibold)
        title.textColor = NSColor(white: 1.0, alpha: 0.45)
        title.frame = NSRect(x: 12, y: size.height - 20, width: 100, height: 14)
        container.addSubview(title)

        let close = NSButton(title: "", target: self, action: #selector(closeClicked))
        close.isBordered = false
        close.attributedTitle = NSAttributedString(
            string: "✕",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: NSColor(white: 1.0, alpha: 0.55),
            ])
        close.frame = NSRect(x: size.width - 28, y: size.height - 22, width: 18, height: 18)
        container.addSubview(close)

        for (i, line) in lines.enumerated() {
            let l = NSTextField(labelWithString: line)
            l.font = .systemFont(ofSize: 11)
            l.textColor = NSColor(red: 0.78, green: 0.88, blue: 1.0, alpha: 0.9)
            l.lineBreakMode = .byTruncatingTail
            l.frame = NSRect(x: 12, y: size.height - headerPad - CGFloat(i + 1) * lineHeight + 2,
                             width: size.width - 24, height: lineHeight - 2)
            container.addSubview(l)
        }

        contentView = container
    }

    @objc private func closeClicked() { onClose?() }

    func reposition() {
        guard let screen = NSScreen.main else { return }
        let v = screen.visibleFrame
        let margin: CGFloat = 14
        // Stacked 8pt above the 30pt timer pill.
        setFrameOrigin(NSPoint(x: v.maxX - frame.width - margin,
                               y: v.minY + margin + 30 + 8))
    }
}

enum Todoist {
    private static var tokenURLs: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            home.appendingPathComponent(".config/discipline/todoist_token"),
            home.appendingPathComponent(".config/orchestrator/todoist_token"),
        ]
    }

    private static var token: String? {
        for url in tokenURLs {
            if let t = (try? String(contentsOf: url, encoding: .utf8))?
                .trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
                return t
            }
        }
        return nil
    }

    /// Fetch open tasks; calls back on the main queue with display lines.
    static func fetchTasks(completion: @escaping ([String]) -> Void) {
        guard let token
        else {
            DispatchQueue.main.async { completion(["no todoist token found"]) }
            return
        }
        var req = URLRequest(url: URL(string: "https://api.todoist.com/api/v1/tasks")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: req) { data, _, _ in
            var lines = ["todoist unreachable"]
            if let data,
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let results = obj["results"] as? [[String: Any]] {
                let contents = results.compactMap { $0["content"] as? String }
                lines = contents.prefix(8).map { "· \($0)" }
                if contents.count > 8 { lines.append("… +\(contents.count - 8) more") }
            }
            DispatchQueue.main.async { completion(lines) }
        }.resume()
    }
}
