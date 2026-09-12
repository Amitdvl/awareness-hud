# Awareness

Awareness is a focused, local-first macOS HUD that makes current computer activity visible without turning into a dashboard or surveillance tool.

The first vertical slice shows the active app, active window, and—when Chrome or Safari is frontmost—the current website and page title.

## Privacy boundary

Awareness records activity metadata only. It does not capture screenshots, keystrokes, passwords, page contents, or send activity to a server. Browser URL query strings are not displayed in the HUD.

Window titles require macOS Accessibility permission. Chrome and Safari website metadata require macOS Automation permission the first time the app asks each browser for its active tab.

## Run

```sh
./script/build_and_run.sh
```

The run script uses a release build by default to keep the resident HUD small and efficient. Set `BUILD_CONFIGURATION=debug` when iterating on code.

Use `./script/build_and_run.sh --verify` to build, launch, and confirm the app process is running.

## Current status

- Native AppKit HUD
- Menu-bar app
- Active application tracking
- Accessibility-backed focused-window title tracking
- Chrome and Safari active website tracking via local AppleScript
- Compact always-visible narrative rendering
- Content-sized HUD with persisted position and menu-bar Move HUD mode
- AppKit-only runtime surface for lower resident memory and fewer view invalidations
- Event-driven app, window, and browser-tab switching with a one-second Chrome/Safari fallback poll
- Smooth, second-accurate elapsed-time updates from a lightweight 250 ms main-queue heartbeat
- Per-app foreground time that accumulates throughout the local calendar day and resets at midnight
- Core formatter tests

Upcoming work includes persistent local history, idle/sleep handling, preferences, browser permission guidance, and a polished onboarding flow.
