import Cocoa
import Translation

private let debounce = Debounce(delay: 0.2)

#if compiler(>=6.0)
@available(macOS 15.0, *)
#endif
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
#if compiler(>=6.0)
  private let menuController = MenuController(
    startTranslationAction: #selector(toggleTranslationEnabled),
    openSettingsAction: #selector(openSettings),
    quitApplicationAction: #selector(NSApplication.terminate(_:))
  )
#else
  private let menuController = MenuController(
    startTranslationAction: #selector(toggleTranslationEnabled),
    quitApplicationAction: #selector(NSApplication.terminate(_:))
  )
#endif
  private var overlays = [NSWindow]()

  private var translator: Translator?
  private var service = TranslationService()

  private var mainWindow: NSWindow?
#if compiler(<6.0)
  typealias TranslationSession = AnyObject
#endif
  var translationSession: TranslationSession? {
    didSet {
#if compiler(>=6.0)
      guard let _ = translationSession else { return }
#endif
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

  private var isTranslationEnabled = false {
    didSet {
      menuController.isTranslationEnabled = isTranslationEnabled

      if isTranslationEnabled {
        translateMessages()
      } else {
        closeAllOverlays()
      }
    }
  }

  func applicationDidFinishLaunching(_ aNotification: Notification) {
    menuController.setup()
    
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
    if menuController.startTranslation === menuItem {
      return translator != nil
    }
    return true
  }

  private func setup() {
    Task { @MainActor in
      let sequence = NSWorkspace.shared.notificationCenter
        .notifications(named: NSWorkspace.didActivateApplicationNotification)
      for await notification in sequence {
        guard let activeApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { continue }

        if activeApp.bundleIdentifier == "com.hnc.Discord" {
          let app = AXUIElementCreateApplication(activeApp.processIdentifier)
          AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)

          translator = DiscordTranslator(application: app)
        } else {
          translator = nil
          isTranslationEnabled = false
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

#if compiler(>=6.0)
  @objc
  private func openSettings() {
    let openSettings = OpenSettings()
    openSettings.openSettings()
    NSApp.activate(ignoringOtherApps: true)
  }
#endif

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
#if compiler(>=6.0)
          overlayWindow.text = try await service.translate(
            session: translationSession,
            text: message.text
          )
#else
          overlayWindow.text = try await service.translate(
            text: message.text
          )
#endif
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
