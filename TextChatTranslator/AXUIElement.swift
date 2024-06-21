import AppKit
import ApplicationServices

extension AXUIElement {
  var value: String {
    (try? copyValue(key: kAXValueAttribute)) ?? ""
  }

  var role: String {
    (try? copyValue(key: kAXRoleAttribute)) ?? ""
  }

  var description: String {
    (try? copyValue(key: kAXDescriptionAttribute)) ?? ""
  }

  var roleDescription: String {
    (try? copyValue(key: kAXRoleDescriptionAttribute)) ?? ""
  }
  
  var frame: CGRect? {
    guard let value: AXValue = try? copyValue(key: "AXFrame") else { return nil }
    var rect: CGRect = .zero
    if AXValueGetValue(value, .cgRect, &rect) {
      var origin = cocoaScreenPointFromCarbonScreenPoint(rect.origin)
      origin.y -= rect.height
      rect.origin = origin
      return rect
    }
    return nil
  }
}

extension AXUIElement {
  var focusedElement: AXUIElement? {
    try? copyValue(key: kAXFocusedUIElementAttribute)
  }

  var sharedFocusElements: [AXUIElement] {
    (try? copyValue(key: kAXChildrenAttribute)) ?? []
  }

  var window: AXUIElement? {
    try? copyValue(key: kAXWindowAttribute)
  }

  var focusedWindow: AXUIElement? {
    try? copyValue(key: kAXFocusedWindowAttribute)
  }

  var children: [AXUIElement] {
    (try? copyValue(key: kAXChildrenAttribute)) ?? []
  }

  func children(where match: (AXUIElement) -> Bool) -> [AXUIElement] {
    var all = [AXUIElement]()
    for child in children {
      if match(child) { all.append(child) }
    }
    for child in children {
      all.append(contentsOf: child.children(where: match))
    }
    return all
  }

  func firstChild(where match: (AXUIElement) -> Bool) -> AXUIElement? {
    for child in children {
      if match(child) { return child }
    }
    for child in children {
      if let target = child.firstChild(where: match) {
        return target
      }
    }
    return nil
  }
}

extension AXUIElement {
  func copyValue<T>(key: String, ofType _: T.Type = T.self) throws -> T {
    var value: AnyObject?
    let error = AXUIElementCopyAttributeValue(self, key as CFString, &value)
    if error == .success, let value = value as? T {
      return value
    }
    throw error
  }
}

extension AXError: Error {}

private func cocoaScreenPointFromCarbonScreenPoint(_ carbonPoint: CGPoint) -> CGPoint {
  CGPoint(x: carbonPoint.x, y: NSScreen.screens[0].frame.size.height - carbonPoint.y)
}
