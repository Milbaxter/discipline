# Discipline

A tiny macOS menu bar app for focus: light-blue border around the screen, a
small countdown bottom-right with an **unblock** button, and system-wide
blocking of X/Twitter, YouTube, Instagram, TikTok, Twitch and Reddit via `/etc/hosts`.

## One-time setup

```sh
cd ~/discipline && sudo ./install.sh
```

This installs a root-owned helper at `/usr/local/bin/discipline-hosts` and a
sudoers rule so the app can toggle blocking without password prompts. The
helper only ever touches the section of `/etc/hosts` between
`# >>> discipline >>>` and `# <<< discipline <<<` markers.

## Use

Launch **Discipline** from /Applications (Spotlight: "Discipline"). It lives in
the menu bar as ◇.

- **Start Focus** — untimed session (timer counts up)
- **Focus 25/50/90 min** — countdown; border shifts amber in the last 10 min,
  chime + auto-unblock at zero
- **unblock** button (bottom-right pill) or **Stop Session** — ends the session
  and restores your hosts file
- **todos** panel (above the timer pill) — your open Todoist tasks, fetched at
  session start (token: `~/.config/orchestrator/todoist_token`). The ✕ hides it
  for the current session; every new session shows it again.
- Quitting the app also unblocks.

When a session starts, open Brave tabs on blocked sites are closed
automatically (macOS will ask once to allow Discipline to control Brave).

## Crash safety

Blocking never depends on a clean exit: the app strips any leftover block
section every time it launches, on quit, and on SIGINT/SIGTERM. If sites are
ever stuck blocked with the app gone, run:

```sh
sudo /usr/local/bin/discipline-hosts unblock
```

## Rebuild after code changes

```sh
./build.sh   # compiles and refreshes /Applications/Discipline.app
```

Note: some Command Line Tools installs ship a duplicate `SwiftBridging`
modulemap that breaks all Swift compiles; if yours does, `build.sh` detects it
and works around it with the VFS overlay in `toolchain-fix/`. Permanent fix
(optional):

```sh
sudo mv /Library/Developer/CommandLineTools/usr/include/swift/module.modulemap{,.bak}
```

## Files

- `Sources/discipline/` — the app (AppKit, no dependencies)
- `scripts/discipline-hosts` — root helper that edits /etc/hosts
- `install.sh` — one-time sudo setup
- `build.sh` — rebuild + reinstall the .app
