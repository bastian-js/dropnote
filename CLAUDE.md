# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

DropNote is a native macOS menu bar app for quick note-taking. Built with Swift/SwiftUI/AppKit — no web stack, no package manager. All data is stored locally in `~/Library/Application Support/DropNote/`.

## Building

Open `dropnote.xcodeproj` in Xcode and build/run from there (Cmd+R). There is no CLI build script. Minimum deployment target is macOS 10.15, Swift 5.9+.

To run tests: Cmd+U in Xcode. The test target is `dropnoteTests`.

## Architecture

**Entry points:**
- `dropnoteApp.swift` — SwiftUI `@main`, wires up app lifecycle
- `AppDelegate.swift` — AppKit delegate that owns the menu bar icon, `NSPopover`, and window controllers; the central coordinator

**Services (data layer):**
- `NotesFileService.swift` — Reads/writes `notes.json`; handles debounced auto-save
- `TodoFileService.swift` — Reads/writes `todos.json` for the todo list feature
- `SettingsService.swift` — Reads/writes `settings.json`; owns `AppSettings`
- `NoteSearchService.swift` — In-memory search index over `IndexedNote`; scoring weights title > word boundary > prefix > recency
- `AuthenticationService.swift` — Touch ID / password protection backed by Keychain

**Models:** `Note`, `TodoItem`, `IndexedNote`, `AppSettings`, `SearchResult` (defined in `Models/`)

**Managers (macOS glue):**
- `HotKeyManager.swift` — Global hotkey via Carbon API (default: Cmd+Opt+F)
- `SearchWindowController.swift` — Hosts the full-text search modal
- `SettingsWindowController.swift` — Hosts the settings window
- `FullWindowController.swift` — Hosts the full notes window (singleton, hides on close to preserve state)

**UI (SwiftUI views):**
- `ContentView` — main popover root; when `showTodoTab` setting is on, shows a Todos tab before note tabs
- `TodoListView` — shared todo list component used in both the popover tab and the full-window sidebar; `compact: true` renders a slimmer version for the sidebar
- `TabsBar` — supports an optional Todos tab prepended before note tabs
- `NoteEditor` → `RichTextEditor` → `FormattingToolbar` — editor stack, reused in both popover and full window
- `FullWindowView` — full-screen notes window with collapsible sidebar (`FullWindowSidebar`) and `FullWindowEditor`

**Helpers:** `FileExportHelper` (PDF/TXT), `ColorSchemeHelper` (live theming), `TextFormattingHelper` (RTF ↔ NSAttributedString), `DateFormattingHelper`.

## AppSettings — new fields (backward-compatible via custom `Codable` decoder)
- `showTodoTab: Bool = true` — enables the Todos tab in the popover and sidebar
- `sidebarExpanded: Bool = true` — persists the full-window sidebar collapse state

## Key Data Flow

1. Menu bar click → `AppDelegate` shows `NSPopover` with `ContentView`
2. `ContentView` observes `NotesFileService` and `SettingsService` as `@StateObject`
3. Edits trigger debounced save via `NotesFileService`
4. Search input flows to `NoteSearchService`, which returns scored `SearchResult` objects
5. Global hotkey (Cmd+Opt+F) → `HotKeyManager` → `AppDelegate` → `SearchWindowController`

## App Sandbox

The app is sandboxed (`dropnote.entitlements`). File access is limited to user-selected files plus the app's own container. Keychain is used for all secret storage. `ServiceManagement` is used for launch-at-login.

## Rich Text

Notes store plain text and optionally an `attributedTextRTF` field (Data). RTF serialization is handled in `TextFormattingHelper`. When both exist, RTF takes precedence in the editor.
