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

  var isFocused: Bool {
    (try? copyValue(key: kAXFocusedAttribute)) ?? false
  }

  var isEnabled: Bool {
    (try? copyValue(key: kAXEnabledAttribute)) ?? false
  }

  var isHidden: Bool {
    (try? copyValue(key: kAXHiddenAttribute)) ?? false
  }
}

public extension AXUIElement {
  var position: CGPoint? {
    guard let value: AXValue = try? copyValue(key: kAXPositionAttribute) else { return nil }
    var point: CGPoint = .zero
    if AXValueGetValue(value, .cgPoint, &point) {
      return point
    }
    return nil
  }

  var size: CGSize? {
    guard let value: AXValue = try? copyValue(key: kAXSizeAttribute) else { return nil }
    var size: CGSize = .zero
    if AXValueGetValue(value, .cgSize, &size) {
      return size
    }
    return nil
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

  var windows: [AXUIElement] {
    (try? copyValue(key: kAXWindowsAttribute)) ?? []
  }

  var isFullScreen: Bool {
    (try? copyValue(key: "AXFullScreen")) ?? false
  }

  var focusedWindow: AXUIElement? {
    try? copyValue(key: kAXFocusedWindowAttribute)
  }

  var topLevelElement: AXUIElement? {
    try? copyValue(key: kAXTopLevelUIElementAttribute)
  }

  var rows: [AXUIElement] {
    (try? copyValue(key: kAXRowsAttribute)) ?? []
  }

  var parent: AXUIElement? {
    try? copyValue(key: kAXParentAttribute)
  }

  var children: [AXUIElement] {
    (try? copyValue(key: kAXChildrenAttribute)) ?? []
  }

  var visibleChildren: [AXUIElement] {
    (try? copyValue(key: kAXVisibleChildrenAttribute)) ?? []
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

  func copyParameterizedValue<T>(
    key: String,
    parameters: AnyObject,
    ofType _: T.Type = T.self
  ) throws -> T {
    var value: AnyObject?
    let error = AXUIElementCopyParameterizedAttributeValue(
      self,
      key as CFString,
      parameters as CFTypeRef,
      &value
    )
    if error == .success, let value = value as? T {
      return value
    }
    throw error
  }
}

extension AXError: @retroactive Error {}

private func cocoaScreenPointFromCarbonScreenPoint(_ carbonPoint: CGPoint) -> CGPoint {
  CGPoint(x: carbonPoint.x, y: NSScreen.screens[0].frame.size.height - carbonPoint.y)
}
