import Foundation
import AppKit

class MenuController {
  let startTranslation: NSMenuItem
  let openSettings: NSMenuItem
  let quitApplication: NSMenuItem

  private lazy var statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

  var isTranslationEnabled = false {
    didSet {
      if isTranslationEnabled {
        startTranslation.title = NSLocalizedString("Stop Translation", comment: "")
        startTranslation.state = .on
      } else {
        startTranslation.title = NSLocalizedString("Start Translation", comment: "")
        startTranslation.state = .off
      }
    }
  }

  init(startTranslationAction: Selector, openSettingsAction: Selector, quitApplicationAction: Selector) {
    startTranslation = NSMenuItem(
      title: NSLocalizedString("Start Translation", comment: ""),
      action: startTranslationAction,
      keyEquivalent: ""
    )
    startTranslation.onStateImage = NSImage(named: NSImage.statusAvailableName)
    startTranslation.offStateImage = NSImage(named: NSImage.statusNoneName)

    openSettings = NSMenuItem(
      title: NSLocalizedString("Settings…", comment: ""),
      action: openSettingsAction,
      keyEquivalent: ","
    )

    quitApplication = NSMenuItem(
      title: NSLocalizedString("Quit Text Chat Translator", comment: ""),
      action: quitApplicationAction,
      keyEquivalent: "q"
    )
  }

  func setup() {
    let menu = NSMenu()

    menu.addItem(startTranslation)
    menu.addItem(NSMenuItem.separator())
    menu.addItem(openSettings)
    menu.addItem(NSMenuItem.separator())
    menu.addItem(quitApplication)

    statusItem.button?.image = NSImage(named: "translator")
    statusItem.menu = menu
  }
}
