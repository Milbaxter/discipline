import AppKit

/// Quits distracting desktop apps at session start and re-quits them if they
/// are launched while a session is running.
final class AppBlocker {
    // Telegram ships under several bundle IDs depending on install source.
    private let blockedBundleIDs: Set<String> = [
        "com.tdesktop.Telegram",
        "org.telegram.desktop",
        "ru.keepcoder.Telegram",
        "org.whispersystems.signal-desktop",
        "net.whatsapp.WhatsApp",
    ]

    private var observer: NSObjectProtocol?

    func activate() {
        NSWorkspace.shared.runningApplications.forEach(quitIfBlocked)
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            // Give the app a moment to finish launching so it can handle the quit event.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                self?.quitIfBlocked(app)
            }
        }
    }

    func deactivate() {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            self.observer = nil
        }
    }

    private func quitIfBlocked(_ app: NSRunningApplication) {
        guard let id = app.bundleIdentifier, blockedBundleIDs.contains(id) else { return }
        app.terminate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if !app.isTerminated { app.forceTerminate() }
        }
    }
}
