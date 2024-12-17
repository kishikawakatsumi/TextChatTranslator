import Foundation
import ApplicationServices

class SlackTranslator: Translator {
  var scrollPosition: CGPoint = .zero

  private var application: AXUIElement
  var messages = [Message]() {
    didSet {
      scrollPosition = messages.first?.frame.origin ?? .zero
    }
  }

  init(application: AXUIElement) {
    self.application = application
  }

  func perform() {
    var messages = [Message]()

    guard let focusedWindow = application.focusedWindow else { return }

    var lists = [AXUIElement]()
    findListElements(in: focusedWindow, lists: &lists)

    for list in lists {
      for child in list.children {
        if child.role != kAXGroupRole {
          continue
        }
        for child in child.children {
          if child.role != kAXGroupRole {
            continue
          }
          for child in child.children {
            if child.role != kAXGroupRole {
              continue
            }
            for child in child.children {
              guard let frame = child.frame, frame.height > 1.0 else {
                continue
              }
              guard child.description.isEmpty else {
                continue
              }
              var text = ""
              concatMessageText(in: child, text: &text)
              messages.append(
                Message(
                  frame: frame, textFrame: frame, text: text, axElement: child
                )
              )
            }
          }
        }
      }
    }

    self.messages = messages
  }

  private func findListElements(in element: AXUIElement, lists: inout [AXUIElement]) {
    for child in element.children {
      if child.role == kAXToolbarRole {
        continue
      }
      if child.role == kAXTabGroupRole {
        continue
      }
      if child.role == kAXOutlineRole {
        continue
      }
      if child.role == kAXListRole {
        lists.append(child)
      }
      findListElements(in: child, lists: &lists)
    }
  }

  private func concatMessageText(in element: AXUIElement, text: inout String) {
    if element.role == kAXStaticTextRole {
      text += element.value
    }

    for message in element.children {
      if message.role == kAXStaticTextRole {
        text += message.value
      } else {
        guard message.role == kAXGroupRole else {
          continue
        }
        concatMessageText(in: message, text: &text)
      }
    }
  }
}
