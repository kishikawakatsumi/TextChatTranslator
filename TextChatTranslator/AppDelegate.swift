import Cocoa
import Translation

private let debounce = Debounce(delay: 0.2)

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
  var translationSession: TranslationSession? {
    didSet {
      guard let _ = translationSession else { return }
      guard mainWindow == nil else { return }
      for window in NSApp.windows {
        if window.className == "SwiftUI.AppKitWindow" {
          window.titleVisibility = .hidden
          window.titlebarAppearsTransparent = true

          window.hasShadow = false

          window.standardWindowButton(.closeButton)?.isHidden = true
          window.standardWindowButton(.miniaturizeButton)?.isHidden = true
          window.standardWindowButton(.zoomButton)?.isHidden = true
          window.ignoresMouseEvents = true

          window.isOpaque = false
          window.backgroundColor = .clear

          window.setContentSize(.zero)
          window.setFrameOrigin(.zero)

          mainWindow = window
        }
      }
    }
  }

  private lazy var statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
  private let translationMenuItem = NSMenuItem(
    title: NSLocalizedString("Start Translation", comment: ""),
    action: #selector(toggleTranslationEnabled), keyEquivalent: ""
  )

  private var mainWindow: NSWindow?
  private var overlays = [NSWindow]()

  private var application: AXUIElement?

  private var firstMessagePosition: CGPoint = .zero
  private var currentMessages = [AXUIElement]() {
    didSet {
      firstMessagePosition = currentMessages.first?.frame?.origin ?? .zero
    }
  }

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
      title: NSLocalizedString("Settings…", comment: ""),
      action: #selector(openSettings), keyEquivalent: ",")
    )
    
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
      return application != nil
    }
    return true
  }

  private func setup() {
    Task {
      let sequence = NSWorkspace.shared.notificationCenter
        .notifications(named: NSWorkspace.didActivateApplicationNotification)
      for await notification in sequence {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { continue }

        if app.bundleIdentifier == "com.hnc.Discord" {
          application = AXUIElementCreateApplication(app.processIdentifier)
        } else {
          application = nil
          await MainActor.run {
            isTranslationEnabled = false
          }
        }
      }
    }

    NSEvent.addGlobalMonitorForEvents(
      matching: [.any]
    ) { (event) in
      guard let _ = self.application else { return }

      if !self.currentMessages.isEmpty {
        if self.firstMessagePosition.y != self.currentMessages.first?.frame?.origin.y {
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

  @objc
  private func openSettings() {
    let openSettings = OpenSettings()
    openSettings.openSettings()
    NSApp.activate()
  }

  private func translateMessages() {
    guard isTranslationEnabled else {
      return
    }

    if currentMessages.isEmpty {
      let messages = fetchVisibleMessages()

      for message in messages {
        var text = ""
        concatMessageText(in: message, text: &text)

        if text.isEmpty {
          continue
        }

        if let frame = message.frame {
          let overlayWindow = OverlayWindow()

          let t = text
          Task { @MainActor in
            if let translationSession {
              overlayWindow.text = try await translate(
                session: translationSession,
                text: t
              )
            }
          }

          overlayWindow.setFrameOrigin(frame.origin)
          overlayWindow.setContentSize(frame.size)

          overlayWindow.orderFront(nil)

          overlays.append(overlayWindow)
        }
      }
      currentMessages = messages
    }
  }

  private func closeAllOverlays() {
    for overlay in self.overlays {
      overlay.close()
    }
    self.overlays = []
    self.currentMessages = []
  }

  private func fetchVisibleMessages() -> [AXUIElement] {
    var messages = [AXUIElement]()

    if let application {
      let focusedWindow = application.focusedWindow

      if let messageList = findMessageListElement(in: focusedWindow) {
        let rowContainers = messageList.children
          .filter { $0.role == kAXGroupRole }
        for rowContainer in rowContainers {
          for row in rowContainer.children {
            if row.roleDescription == "message" {
              let messageContainer = row
              let messageGroup = messageContainer.children
                .filter { $0.roleDescription != "heading" && $0.roleDescription != "time" }
                .filter { $0.children.allSatisfy { $0.roleDescription != "article" } }
              for message in messageGroup {
                if let frame = message.frame, frame.height > 1.0 {
                  messages.append(message)
                }
              }
            }
          }
        }
      }
    }

    return messages
  }

  private func findMessageListElement(in element: AXUIElement?) -> AXUIElement? {
    for child in element?.children ?? [] {
      if child.role == kAXGroupRole || child.role == kAXListRole || child.role == "AXWebArea" {
        if let messageList = findMessageListElement(in: child) {
          return messageList
        }
      }
      if child.roleDescription == "content list" && child.description.starts(with: "Messages") {
        return child
      }
    }
    return nil
  }

  private func concatMessageText(in element: AXUIElement, text: inout String) {
    for message in element.children {
      if message.role == kAXStaticTextRole && message.roleDescription == "text" {
        text += message.value
      } else {
        if message.role == kAXGroupRole {
          concatMessageText(in: message, text: &text)
        }
      }
    }
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
