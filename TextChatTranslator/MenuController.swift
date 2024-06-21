import Foundation
import AppKit

class MenuController {
  let startTranslation: NSMenuItem
  let quitApplication: NSMenuItem

  private let statusItem: NSStatusItem

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

  init(startTranslationAction: Selector, quitApplicationAction: Selector) {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    statusItem.button?.image = NSImage(named: "translator")

    let menu = NSMenu()
    statusItem.menu = menu

    startTranslation = NSMenuItem(
      title: NSLocalizedString("Start Translation", comment: ""),
      action: startTranslationAction,
      keyEquivalent: ""
    )

    startTranslation.image = NSImage(named: "discord")
    startTranslation.onStateImage = NSImage(named: NSImage.statusAvailableName)
    startTranslation.offStateImage = NSImage(named: NSImage.statusNoneName)
    menu.addItem(startTranslation)

    menu.addItem(NSMenuItem.separator())

    quitApplication = NSMenuItem(
      title: NSLocalizedString("Quit Text Chat Translator", comment: ""),
      action: quitApplicationAction,
      keyEquivalent: "q"
    )
    menu.addItem(quitApplication)
  }
}
