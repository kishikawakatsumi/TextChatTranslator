import Cocoa

private let debounce = Debounce(delay: 0.2)

@main
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
  private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
  private let translationMenuItem = NSMenuItem(
    title: NSLocalizedString("Start Translation", comment: ""),
    action: #selector(toggleTranslationEnabled), keyEquivalent: ""
  )

  private var translator: Translator?
  private var overlays = [NSWindow]()

  private var isTranslationEnabled = false {
    didSet {
      if isTranslationEnabled {
        translateMessages()
        translationMenuItem.title = NSLocalizedString("Stop Translation", comment: "")
        translationMenuItem.state = .on
      } else {
        closeAllOverlays()
        translationMenuItem.title = NSLocalizedString("Start Translation", comment: "")
        translationMenuItem.state = .off
      }
    }
  }

  func applicationDidFinishLaunching(_ aNotification: Notification) {
    statusItem.button?.image = NSImage(named: "translator")

    let menu = NSMenu()

    translationMenuItem.image = NSImage(named: "discord")
    translationMenuItem.onStateImage = NSImage(named: NSImage.statusAvailableName)
    translationMenuItem.offStateImage = NSImage(named: NSImage.statusNoneName)
    menu.addItem(translationMenuItem)

    menu.addItem(NSMenuItem.separator())
    menu.addItem(NSMenuItem(
      title: NSLocalizedString("Quit Text Chat Translator", comment: ""),
      action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    )

    statusItem.menu = menu

    let trustedCheckOptionPrompt = kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString
    let options = [trustedCheckOptionPrompt: true] as CFDictionary
    if AXIsProcessTrustedWithOptions(options) {
      setup()
    } else {
      waitPermisionGranted {
        self.setup()
      }
    }
  }

  func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
    if translationMenuItem === menuItem {
      return translator != nil
    }
    return true
  }

  private func setup() {
    Task {
      let sequence = NSWorkspace.shared.notificationCenter
        .notifications(named: NSWorkspace.didActivateApplicationNotification)
      for await notification in sequence {
        guard let activeApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { continue }

        if activeApp.bundleIdentifier == "com.hnc.Discord" {
          let app = AXUIElementCreateApplication(activeApp.processIdentifier)
          translator = DiscordTranslator(application: app)
        } else {
          translator = nil
        }
      }
    }

    NSEvent.addGlobalMonitorForEvents(
      matching: [.any]
    ) { (event) in
      guard let translator = self.translator else { return }

      if let message = translator.messages.first {
        if translator.scrollPosition.y != message.axElement.frame?.origin.y {
          self.closeAllOverlays()
        }
      }
      debounce.call {
        self.translateMessages()
      }
    }
  }

  @objc
  private func toggleTranslationEnabled() {
    isTranslationEnabled.toggle()
  }

  private func translateMessages() {
    guard isTranslationEnabled else {
      return
    }

    if let translator, overlays.isEmpty {
      translator.perform()

      for message in translator.messages {
        if message.text.isEmpty {
          continue
        }

        let overlayWindow = OverlayWindow()
        overlayWindow.leadingMargin = message.textFrame.minX - message.frame.minX

        Task { @MainActor in
          overlayWindow.text = try await translate(text: message.text)
        }

        overlayWindow.setFrameOrigin(message.frame.origin)
        overlayWindow.setContentSize(message.frame.size)

        overlayWindow.orderFront(nil)

        overlays.append(overlayWindow)
      }
    }
  }

  private func closeAllOverlays() {
    overlays.forEach { $0.close() }
    overlays = []
  }

  private func waitPermisionGranted(completion: @escaping () -> Void) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
      if AXIsProcessTrusted() {
        completion()
      } else {
        self.waitPermisionGranted(completion: completion)
      }
    }
  }
}
