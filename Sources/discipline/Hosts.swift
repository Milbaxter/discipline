import Foundation

enum Hosts {
    private static let helper = "/usr/local/bin/discipline-hosts"

    @discardableResult
    private static func run(_ command: String) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        p.arguments = ["-n", helper, command] // -n: never prompt; fails fast if sudoers rule missing
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return false }
        p.waitUntilExit()
        return p.terminationStatus == 0
    }

    @discardableResult
    static func block() -> Bool { run("block") }
    @discardableResult
    static func unblock() -> Bool { run("unblock") }
}

enum Brave {
    /// Close any open Brave tabs on blocked sites. Best-effort: silently does
    /// nothing if Brave isn't running or Automation permission is denied.
    static func closeSocialTabs() {
        let script = """
        if application "Brave Browser" is running then
            tell application "Brave Browser"
                repeat with w in windows
                    try
                        set n to count of tabs of w
                        repeat with i from n to 1 by -1
                            try
                                set u to URL of tab i of w
                                if u contains "youtube.com" or u contains "youtu.be" ¬
                                    or u contains "://x.com" or u contains "://www.x.com" ¬
                                    or u contains "twitter.com" or u contains "instagram.com" ¬
                                    or u contains "tiktok.com" or u contains "twitch.tv" ¬
                                    or u contains "reddit.com" or u contains "discord.com" then
                                    close tab i of w
                                end if
                            end try
                        end repeat
                    end try
                end repeat
            end tell
        end if
        """
        DispatchQueue.global(qos: .utility).async {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            p.arguments = ["-e", script]
            p.standardOutput = FileHandle.nullDevice
            p.standardError = FileHandle.nullDevice
            try? p.run()
            p.waitUntilExit()
        }
    }
}
