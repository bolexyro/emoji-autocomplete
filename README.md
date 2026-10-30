# Emoji Autocomplete for Windows

A shareable AutoHotkey v2 utility that adds Telegram-style `:shortcode` suggestions to common Windows text fields. Type `:lau`, choose 😂, and it replaces the shortcode only after confirmation.

## Features

- Filters a compact horizontal popup while you type.
- Uses bundled color Twemoji graphics for consistent, readable rendering.
- Left/Right or Up/Down navigation, Enter/Tab insertion, Escape cancellation.
- Mouse selection and caret-relative placement with a pointer fallback.
- Leaves typed text untouched until selection.
- Can be disabled persistently for selected applications.
- Editable UTF-8 TSV catalog and INI configuration.

## Install and use from source

1. Install [AutoHotkey v2](https://www.autohotkey.com/). Version 1 is incompatible.
2. Download this repository and double-click `EmojiAutocomplete.ahk`.
3. Keep the `data` and `config` folders beside the script. Optionally put a shortcut in `shell:startup`.

To launch it automatically after signing in, right-click the Emoji Autocomplete
tray icon and enable **Start with Windows**. The checked state confirms the
current executable or source script is registered for the current Windows user.
Choose it again to disable automatic startup.

Type `:lau`, `:heart`, `:thumb`, or `:rocket`. Use Left/Up for the previous result, Right/Down for the next, Enter/Tab to insert, or Escape to cancel. Backspace updates the search. You can also click a result. Whitespace or punctuation ends a search.

### Disable it in selected applications

Focus the application you want to exclude, right-click the Emoji Autocomplete
tray icon, and choose the **Disable in _app.exe_** command. Repeat the command
to enable it again. The choice is stored by executable name and survives
restarts.

The tray command names the exact executable it will change, for example
**Disable in slack.exe** or **Enable in slack.exe**. You can also press
**Ctrl+Alt+E** while an application is focused to toggle Emoji Autocomplete in
that app immediately. This avoids losing the target when opening the tray menu.

For the most reliable method, choose **Manage disabled apps...** from the tray
menu, check every application where autocomplete should remain off, and press
**Save**. The manager writes the executable names directly to the active
`config/settings.ini` file and also shows previously disabled apps that are not
currently running.

For scripting or troubleshooting, the executable also supports direct updates:

```powershell
.\EmojiAutocomplete.exe --disable-app slack.exe
.\EmojiAutocomplete.exe --enable-app slack.exe
```

You can also edit the comma-separated list in `config/settings.ini` directly:

```ini
[disabled_apps]
process_names=Code.exe,WindowsTerminal.exe
```

Choose **Reload settings** from the tray menu after editing the file manually.

### Positioning in custom editors

The utility remembers the last click into a field and tracks typed character
widths to approximate the caret in modern controls that expose no reliable
Windows caret. Standard controls still use their native caret. If an app needs
a fixed fallback, add its executable name to `positioning.bottom_anchor_apps`
in `config/settings.ini` to anchor above the bottom composer.

## Catalog and settings

Edit `data/emoji.tsv` in a UTF-8 editor. Non-comment rows contain four tab-separated fields:

```text
emoji<TAB>canonical_name<TAB>alias_one,alias_two<TAB>keyword_one,keyword_two
```

Use lowercase ASCII letters, numbers, underscores, plus signs, or hyphens for names and aliases. Restart after editing. `config/settings.ini` controls result count, minimum query length, and disabled applications.

## Build a standalone Windows executable

Recipients do not need AutoHotkey when given the compiled package. Install AutoHotkey v2 with `Ahk2Exe`, then run from PowerShell:

```powershell
.\scripts\Build.ps1
```

For a custom compiler path, use `-Ahk2Exe 'C:\path\to\Ahk2Exe.exe'`. The output is `dist\EmojiAutocomplete-Windows.zip`, including the executable, editable data/config, README, and license. Distribute the whole ZIP. Windows may warn about an unsigned executable; code-sign public releases where practical.

## Validation

Run `.\scripts\Validate.ps1`. Then manually test `:lau` in Notepad, a browser field, and a messaging app, covering filtering, navigation, Enter/Tab, Escape, Backspace, and clicking.

## Compatibility and limitations

This uses a global input hook plus synthetic Backspace and Unicode input. It works in many Win32 controls, browsers, Electron apps, messaging clients, and editors, but cannot support every Windows control.

- **Elevated apps:** Windows blocks input from a normal process to an administrator-elevated target. Run the utility elevated only when necessary, accepting the additional privilege.
- **Custom/protected controls:** Games, terminals, remote desktops, password fields, secure desktops, anti-cheat software, and custom controls may ignore hooks, hide the caret, or reject synthetic input.
- **Caret location:** If a control exposes no caret, the popup uses the mouse pointer and placement is approximate.
- **IME/layouts:** Composition, dead keys, and unusual layouts can produce different events. Shortcodes intentionally use ASCII name characters.
- **Reserved keys and undo:** Popup navigation keys are reserved while it is open. Backspace-plus-text insertion may be grouped differently by each app's undo system.

Do not use this utility in password or other sensitive fields.

## Portability and future ports

The executable and AutoHotkey source are **Windows-only**. The TSV catalog and matching concepts are portable, but input capture, caret placement, UI, and insertion require native rewrites.

- macOS: Swift/AppKit with Accessibility APIs and input monitoring; permissions and code signing are required.
- Linux: X11 can use global hooks/XTest. Wayland usually needs compositor-specific integration or an input-method framework such as IBus/Fcitx with GTK/Qt.

Future ports can reuse `data/emoji.tsv`; the Windows executable is not cross-platform.

## Project layout

`EmojiAutocomplete.ahk` is the app; `data/emoji.tsv` and `config/settings.ini` are editable resources; `assets/emoji` contains the color graphics; `scripts/Build.ps1` packages releases; `scripts/Validate.ps1` checks the project. Licensed under MIT; see `LICENSE`.

The bundled graphics come from Twemoji 15.1.0 under CC BY 4.0. See `THIRD_PARTY_NOTICES.md` for attribution. Run `scripts/FetchEmojiAssets.ps1` when adding catalog entries or refreshing the pinned assets.
