import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var stopItem: NSMenuItem!

    private var borderWindows: [BorderWindow] = []
    private var timerWindow: TimerWindow?
    private var todoWindow: TodoWindow?
    private var todosDismissed = false
    private var tick: Timer?
    private var signalSources: [DispatchSourceSignal] = []

    private var sessionActive = false
    private var sessionPreview = false
    private var sessionStart = Date()
    private var sessionEnd: Date? // nil = untimed
    private let appBlocker = AppBlocker()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Strip any block section left behind by a crash or force-quit.
        Hosts.unblock()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "◇"

        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(item("Start Focus", #selector(startUntimed)))
        for minutes in [25, 50, 90] {
            let i = NSMenuItem(title: "Focus \(minutes) min", action: #selector(startTimed(_:)), keyEquivalent: "")
            i.target = self
            i.tag = minutes
            menu.addItem(i)
        }
        menu.addItem(item("Preview Aura", #selector(startPreview)))
        menu.addItem(.separator())
        stopItem = item("Stop Session", #selector(stopSession))
        stopItem.isEnabled = false
        menu.addItem(stopItem)
        menu.addItem(.separator())
        menu.addItem(item("Quit Discipline", #selector(quit)))
        statusItem.menu = menu

        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)

        installSignalHandlers()

        // Test hook: DISCIPLINE_PREVIEW=1 auto-starts a preview session at launch.
        if ProcessInfo.processInfo.environment["DISCIPLINE_PREVIEW"] == "1" {
            startSession(minutes: nil, preview: true)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        Hosts.unblock()
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: "")
        i.target = self
        return i
    }

    // MARK: - Session lifecycle

    @objc private func startUntimed() { startSession(minutes: nil) }

    @objc private func startPreview() { startSession(minutes: nil, preview: true) }

    @objc private func startTimed(_ sender: NSMenuItem) { startSession(minutes: sender.tag) }

    private func startSession(minutes: Int?, preview: Bool = false) {
        guard !sessionActive else { return }
        sessionActive = true
        sessionPreview = preview
        sessionStart = Date()
        sessionEnd = minutes.map { Date().addingTimeInterval(TimeInterval($0 * 60)) }

        if !preview {
            if !Hosts.block() {
                alert("Site blocking is not set up",
                      "Run this once in Terminal, then start a session again:\n\n"
                      + "cd ~/discipline && sudo ./install.sh\n\n"
                      + "The focus border and timer still work without it.")
            }
            Brave.closeSocialTabs()
            appBlocker.activate()
        }

        todosDismissed = false
        buildOverlays()
        Todoist.fetchTasks { [weak self] lines in
            self?.todoWindow?.update(lines: lines)
        }
        statusItem.button?.title = "◆"
        stopItem.isEnabled = true

        tick = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.tickUpdate()
        }
        tick?.tolerance = 0.1
        tickUpdate()
    }

    @objc private func stopSession() { endSession() }

    private func endSession(playSound: Bool = false) {
        guard sessionActive else { return }
        sessionActive = false
        if !sessionPreview {
            Hosts.unblock()
            appBlocker.deactivate()
        }
        sessionPreview = false

        tick?.invalidate()
        tick = nil
        borderWindows.forEach { $0.orderOut(nil) }
        borderWindows = []
        timerWindow?.orderOut(nil)
        timerWindow = nil
        todoWindow?.orderOut(nil)
        todoWindow = nil

        statusItem.button?.title = "◇"
        stopItem.isEnabled = false

        if playSound { NSSound(named: "Glass")?.play() }
    }

    @objc private func quit() {
        endSession()
        NSApp.terminate(nil)
    }

    // MARK: - Overlays & ticking

    private func buildOverlays() {
        borderWindows.forEach { $0.orderOut(nil) }
        borderWindows = NSScreen.screens.map { BorderWindow(screen: $0) }
        if timerWindow == nil {
            let tw = TimerWindow()
            tw.onUnblock = { [weak self] in self?.endSession() }
            timerWindow = tw
        }
        timerWindow?.reposition()
        timerWindow?.orderFrontRegardless()

        if !todosDismissed, todoWindow == nil {
            let tdw = TodoWindow()
            tdw.onClose = { [weak self] in
                self?.todosDismissed = true
                self?.todoWindow?.orderOut(nil)
                self?.todoWindow = nil
            }
            todoWindow = tdw
        }
        todoWindow?.reposition()
        todoWindow?.orderFrontRegardless()
    }

    private func tickUpdate() {
        guard sessionActive else { return }
        if let end = sessionEnd {
            let remaining = Int(end.timeIntervalSinceNow.rounded())
            if remaining <= 0 {
                endSession(playSound: true)
                return
            }
            timerWindow?.update(text: formatInterval(remaining))
        } else {
            let elapsed = Int(Date().timeIntervalSince(sessionStart).rounded())
            timerWindow?.update(text: formatInterval(elapsed))
        }
    }

    @objc private func screensChanged() {
        guard sessionActive else { return }
        buildOverlays()
    }

    // MARK: - Crash safety

    private func installSignalHandlers() {
        for sig in [SIGINT, SIGTERM] {
            signal(sig, SIG_IGN)
            let src = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            src.setEventHandler {
                Hosts.unblock()
                exit(0)
            }
            src.resume()
            signalSources.append(src)
        }
    }

    private func alert(_ title: String, _ text: String) {
        let a = NSAlert()
        a.messageText = title
        a.informativeText = text
        a.alertStyle = .warning
        a.runModal()
    }
}
