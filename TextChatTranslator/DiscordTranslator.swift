import Foundation
import ApplicationServices

class DiscordTranslator: Translator {
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
    guard let messageList = findMessageListElement(in: focusedWindow) else { return }

    let rowContainers = messageList.children
      .filter { $0.role == kAXGroupRole }
    for rowContainer in rowContainers {
      for row in rowContainer.children {
        guard row.roleDescription == "message" else {
          continue
        }

        let messageContainer = row
        let messageGroup = messageContainer.children
          .filter { $0.roleDescription != "heading" && $0.roleDescription != "time" }
          .filter { $0.children.allSatisfy { $0.roleDescription != "article" } }
        for message in messageGroup {
          guard let frame = message.frame, frame.height > 1.0 else {
            continue
          }
          var text = ""
          var minX = CGFloat.greatestFiniteMagnitude
          concatMessageText(in: message, text: &text, minX: &minX)
          var textFrame = frame
          textFrame.origin.x = minX
          messages.append(
            Message(
              frame: frame, textFrame: textFrame, text: text, axElement: message
            )
          )
        }
      }
    }

    self.messages = messages
  }

  private func findMessageListElement(in element: AXUIElement) -> AXUIElement? {
    for child in element.children {
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

  private func concatMessageText(in element: AXUIElement, text: inout String, minX: inout CGFloat) {
    for message in element.children {
      if message.role == kAXStaticTextRole && message.roleDescription == "text" {
        text += message.value
        guard let frame = message.frame else {
          continue
        }
        minX = min(frame.minX, minX)
      } else {
        guard message.role == kAXGroupRole else {
          continue
        }
        concatMessageText(in: message, text: &text, minX: &minX)
      }
    }
  }
}
