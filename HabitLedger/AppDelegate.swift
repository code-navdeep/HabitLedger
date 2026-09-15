import AppKit
import Combine
import SwiftUI

/// Lets the status-item menu drive the panel's navigation state.
final class PanelRouter: ObservableObject {
    enum Request {
        case adding
        case settings
    }

    @Published var requestedState: Request?
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let store = HabitStore()
    private let router = PanelRouter()
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var cancellables = Set<AnyCancellable>()
    private var dayChangeObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let root = MenuBarContentView()
            .environmentObject(store)
            .environmentObject(router)
        let hosting = NSHostingController(rootView: root)
        hosting.sizingOptions = .preferredContentSize
        popover.contentViewController = hosting
        popover.behavior = .transient
        popover.animates = true

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "flame", accessibilityDescription: "HabitLedger")
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        store.$habits
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateStatusIcon() }
            .store(in: &cancellables)

        dayChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged, object: nil, queue: .main
        ) { [weak self] _ in
            self?.updateStatusIcon()
        }

        updateStatusIcon()
    }

    // MARK: - Click Routing

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else {
            togglePopover()
            return
        }
        // Two-finger click arrives as rightMouseUp; Ctrl-click as leftMouseUp + .control.
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - Status-Item Menu (secondary click)

    private func showMenu() {
        let menu = NSMenu()
        menu.delegate = self

        let about = NSMenuItem(title: "About HabitLedger", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        menu.addItem(.separator())

        let add = NSMenuItem(title: "Add New Habit", action: #selector(addHabit), keyEquivalent: "n")
        add.target = self
        menu.addItem(add)

        let settings = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit HabitLedger", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        // Standard status-item trick: attach the menu, click to open it, and
        // detach in menuDidClose so plain left-clicks keep toggling the popover.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
    }

    func menuDidClose(_ menu: NSMenu) {
        statusItem.menu = nil
    }

    // MARK: - Menu Actions

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)

        let credits = NSMutableAttributedString()
        let baseAttributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12)]
        credits.append(NSAttributedString(string: "Nav Virdi\n", attributes: baseAttributes))
        if let siteURL = URL(string: "https://Liberated.Studio") {
            var attributes = baseAttributes
            attributes[.link] = siteURL
            credits.append(NSAttributedString(string: "Liberated.Studio\n", attributes: attributes))
        }
        if let mailURL = URL(string: "mailto:nav@Liberated.Studio") {
            var attributes = baseAttributes
            attributes[.link] = mailURL
            credits.append(NSAttributedString(string: "nav@Liberated.Studio", attributes: attributes))
        }

        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }

    @objc private func addHabit() {
        openPanel(with: .adding)
    }

    @objc private func showSettings() {
        openPanel(with: .settings)
    }

    private func openPanel(with request: PanelRouter.Request) {
        router.requestedState = request
        if !popover.isShown {
            togglePopover()
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Status Icon Feedback

    /// Filled flame when every active habit has an entry for today.
    private func updateStatusIcon() {
        let today = Date()
        let active = store.activeHabits(on: today)
        let allLogged = !active.isEmpty && active.allSatisfy { $0.getEntry(for: today) != nil }
        statusItem?.button?.image = NSImage(
            systemSymbolName: allLogged ? "flame.fill" : "flame",
            accessibilityDescription: "HabitLedger"
        )
    }
}
