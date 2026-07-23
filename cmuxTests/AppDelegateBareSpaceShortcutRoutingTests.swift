import AppKit
import XCTest

#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
#endif

@MainActor
final class AppDelegateBareSpaceShortcutRoutingTests: XCTestCase {
    private var savedShortcutsByAction: [KeyboardShortcutSettings.Action: StoredShortcut] = [:]
    private var actionsWithPersistedShortcut: Set<KeyboardShortcutSettings.Action> = []
    private var originalSettingsFileStore: KeyboardShortcutSettingsFileStore!

    override func setUp() {
        super.setUp()
        executionTimeAllowance = 30
        actionsWithPersistedShortcut = Set(
            KeyboardShortcutSettings.Action.allCases.filter {
                UserDefaults.standard.object(forKey: $0.defaultsKey) != nil
            }
        )
        savedShortcutsByAction = Dictionary(
            uniqueKeysWithValues: actionsWithPersistedShortcut.map { action in
                (action, KeyboardShortcutSettings.shortcut(for: action))
            }
        )
        originalSettingsFileStore = KeyboardShortcutSettings.settingsFileStore
        KeyboardShortcutSettings.resetAll()
    }

    override func tearDown() {
        KeyboardShortcutSettings.settingsFileStore = originalSettingsFileStore
        for action in KeyboardShortcutSettings.Action.allCases {
            if actionsWithPersistedShortcut.contains(action),
               let savedShortcut = savedShortcutsByAction[action] {
                KeyboardShortcutSettings.setShortcut(savedShortcut, for: action)
            } else {
                KeyboardShortcutSettings.resetShortcut(for: action)
            }
        }
        super.tearDown()
    }

    func testFocusedTerminalShortcutPassthroughBypassesOnlyConfiguredChords() {
        guard let appDelegate = AppDelegate.shared else {
            XCTFail("Expected AppDelegate.shared")
            return
        }

        let windowId = appDelegate.createMainWindow()
        defer { closeWindow(withId: windowId) }

        guard let window = window(withId: windowId),
              let manager = appDelegate.tabManagerFor(windowId: windowId),
              let workspace = manager.selectedWorkspace else {
            XCTFail("Expected test window, manager, and workspace")
            return
        }

        window.makeKeyAndOrderFront(nil)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

        let passthroughs: [(String, UInt16, NSEvent.ModifierFlags)] = [
            ("t", 17, [.command]),
            ("n", 45, [.command]),
            ("\t", 48, [.control]),
            ("\t", 48, [.control, .shift]),
        ]
        workspace.setShortcutPassthrough([
            "cmd+t",
            "cmd+n",
            "ctrl+tab",
            "ctrl+shift+tab",
        ])

        for (key, keyCode, modifiers) in passthroughs {
            guard let event = makeKeyDownEvent(
                key: key,
                keyCode: keyCode,
                modifiers: modifiers,
                windowNumber: window.windowNumber
            ) else {
                XCTFail("Failed to construct shortcut event")
                return
            }
#if DEBUG
            XCTAssertFalse(appDelegate.debugHandleCustomShortcut(event: event))
#else
            XCTFail("debugHandleCustomShortcut is only available in DEBUG")
#endif
        }

        workspace.setShortcutPassthrough([])
        for (key, keyCode, modifiers) in passthroughs {
            guard let event = makeKeyDownEvent(
                key: key,
                keyCode: keyCode,
                modifiers: modifiers,
                windowNumber: window.windowNumber
            ) else {
                XCTFail("Failed to construct shortcut event")
                return
            }
#if DEBUG
            XCTAssertTrue(appDelegate.debugHandleCustomShortcut(event: event))
#else
            XCTFail("debugHandleCustomShortcut is only available in DEBUG")
#endif
        }

        for (key, keyCode, modifiers) in passthroughs {
            manager.selectWorkspace(workspace)
            _ = manager.openBrowser(inWorkspace: workspace.id)
            guard let event = makeKeyDownEvent(
                key: key,
                keyCode: keyCode,
                modifiers: modifiers,
                windowNumber: window.windowNumber
            ) else {
                XCTFail("Failed to construct shortcut event")
                return
            }
#if DEBUG
            XCTAssertTrue(appDelegate.debugHandleCustomShortcut(event: event))
#else
            XCTFail("debugHandleCustomShortcut is only available in DEBUG")
#endif
        }
    }

    func testBareSpaceShortcutDispatchesConfiguredAction() {
        guard let appDelegate = AppDelegate.shared else {
            XCTFail("Expected AppDelegate.shared")
            return
        }

        let windowId = appDelegate.createMainWindow()
        defer { closeWindow(withId: windowId) }

        guard let window = window(withId: windowId),
              let manager = appDelegate.tabManagerFor(windowId: windowId) else {
            XCTFail("Expected test window and manager")
            return
        }

        window.makeKeyAndOrderFront(nil)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

        let initialCount = manager.tabs.count
        let shortcut = StoredShortcut(key: "space", command: false, shift: false, option: false, control: false)

        withTemporaryShortcut(action: .newTab, shortcut: shortcut) {
            guard let event = makeKeyDownEvent(key: " ", keyCode: 49, windowNumber: window.windowNumber) else {
                XCTFail("Failed to construct Space event")
                return
            }

#if DEBUG
            XCTAssertTrue(appDelegate.debugHandleCustomShortcut(event: event))
#else
            XCTFail("debugHandleCustomShortcut is only available in DEBUG")
#endif
        }

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertEqual(manager.tabs.count, initialCount + 1, "Bare Space should dispatch when explicitly configured")
    }

    func testBareSpaceChordPrefixArmsConfiguredShortcut() {
        guard let appDelegate = AppDelegate.shared else {
            XCTFail("Expected AppDelegate.shared")
            return
        }

        let windowId = appDelegate.createMainWindow()
        defer { closeWindow(withId: windowId) }

        guard let window = window(withId: windowId),
              let manager = appDelegate.tabManagerFor(windowId: windowId) else {
            XCTFail("Expected test window and manager")
            return
        }

        window.makeKeyAndOrderFront(nil)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

        let initialCount = manager.tabs.count
        let shortcut = StoredShortcut(
            key: "space",
            command: false,
            shift: false,
            option: false,
            control: false,
            chordKey: "n"
        )

        withTemporaryShortcut(action: .newTab, shortcut: shortcut) {
            guard let prefixEvent = makeKeyDownEvent(key: " ", keyCode: 49, windowNumber: window.windowNumber),
                  let actionEvent = makeKeyDownEvent(key: "n", keyCode: 45, windowNumber: window.windowNumber) else {
                XCTFail("Failed to construct Space chord events")
                return
            }

#if DEBUG
            XCTAssertTrue(appDelegate.debugHandleCustomShortcut(event: prefixEvent))
            XCTAssertEqual(manager.tabs.count, initialCount, "Bare Space prefix must not fire the action early")
            XCTAssertTrue(appDelegate.debugHandleCustomShortcut(event: actionEvent))
#else
            XCTFail("debugHandleCustomShortcut is only available in DEBUG")
#endif
        }

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertEqual(manager.tabs.count, initialCount + 1, "Bare Space chord should dispatch on the second stroke")
    }

    func testCreateMainWindowUsesPersistedGeometryWhenNoSourceWindow() throws {
        let previousShared = AppDelegate.shared
        let appDelegate = AppDelegate()
        defer { AppDelegate.shared = previousShared }

        let defaults = UserDefaults.standard
        let persistedGeometryKey = AppDelegate.debugPersistedWindowGeometryDefaultsKey
        let previousPersistedGeometry = defaults.object(forKey: persistedGeometryKey)
        var windowId: UUID?
        defer {
            if let windowId {
                closeWindow(withId: windowId)
            }
            restoreDefaultsValue(
                previousPersistedGeometry,
                forKey: persistedGeometryKey,
                defaults: defaults
            )
        }

        let screen = try XCTUnwrap(NSScreen.main ?? NSScreen.screens.first)
        let visibleFrame = screen.visibleFrame
        let savedWidth = max(
            CGFloat(SessionPersistencePolicy.minimumWindowWidth),
            min(1_100, visibleFrame.width - 40)
        )
        let savedHeight = max(
            CGFloat(SessionPersistencePolicy.minimumWindowHeight),
            min(760, visibleFrame.height - 40)
        )
        let savedFrame = CGRect(
            x: visibleFrame.midX - savedWidth / 2,
            y: visibleFrame.midY - savedHeight / 2,
            width: savedWidth,
            height: savedHeight
        )
        let payload = AppDelegate.PersistedWindowGeometry(
            version: AppDelegate.persistedWindowGeometrySchemaVersion,
            frame: SessionRectSnapshot(savedFrame),
            display: SessionDisplaySnapshot(
                displayID: screen.cmuxDisplayID,
                frame: SessionRectSnapshot(screen.frame),
                visibleFrame: SessionRectSnapshot(screen.visibleFrame)
            )
        )
        defaults.set(try JSONEncoder().encode(payload), forKey: persistedGeometryKey)

        let createdWindowId = appDelegate.createMainWindow(shouldActivate: false, sourceWindow: nil)
        windowId = createdWindowId

        let window = try XCTUnwrap(window(withId: createdWindowId))
        XCTAssertEqual(window.frame.minX, savedFrame.minX, accuracy: 1)
        XCTAssertEqual(window.frame.minY, savedFrame.minY, accuracy: 1)
        XCTAssertEqual(window.frame.width, savedFrame.width, accuracy: 1)
        XCTAssertEqual(window.frame.height, savedFrame.height, accuracy: 1)
    }

    private func makeKeyDownEvent(
        key: String,
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags = [],
        windowNumber: Int
    ) -> NSEvent? {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: windowNumber,
            context: nil,
            characters: key,
            charactersIgnoringModifiers: key,
            isARepeat: false,
            keyCode: keyCode
        )
    }

    private func withTemporaryShortcut(
        action: KeyboardShortcutSettings.Action,
        shortcut: StoredShortcut,
        _ body: () -> Void
    ) {
        let hadPersistedShortcut = UserDefaults.standard.object(forKey: action.defaultsKey) != nil
        let originalShortcut = KeyboardShortcutSettings.shortcut(for: action)
        defer {
            if hadPersistedShortcut {
                KeyboardShortcutSettings.setShortcut(originalShortcut, for: action)
            } else {
                KeyboardShortcutSettings.resetShortcut(for: action)
            }
        }
        KeyboardShortcutSettings.setShortcut(shortcut, for: action)
        body()
    }

    private func window(withId windowId: UUID) -> NSWindow? {
        let identifier = "cmux.main.\(windowId.uuidString)"
        return NSApp.windows.first(where: { $0.identifier?.rawValue == identifier })
    }

    private func closeWindow(withId windowId: UUID) {
        guard let window = window(withId: windowId) else { return }
        window.performClose(nil)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
    }

    private func restoreDefaultsValue(_ value: Any?, forKey key: String, defaults: UserDefaults) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
