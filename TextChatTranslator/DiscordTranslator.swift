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
        guard [
          "besked",
          "nachricht",
          "message",
          "mensaje",
          "enviar mensaje",
          "message",
          "poruka",
          "messaggio",
          "pranešimas",
          "üzenet",
          "bericht",
          "melding",
          "wiadomość",
          "mensagem",
          "mesaj",
          "viesti",
          "meddelande",
          "tin nhắn",
          "mesaj",
          "zpráva",
          "μήνυμα",
          "съобщение",
          "сообщение",
          "повідомлення",
          "मैसेज",
          "ข้อความ",
          "消息",
          "メッセージ",
          "傳送訊息",
          "메시지",
        ].contains(row.roleDescription) else {
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

      if child.roleDescription == "content list" && (
        child.description.starts(with: "Beskeder i") ||
        child.description.starts(with: "Nachrichten in") ||
        child.description.starts(with: "Messages") ||
        child.description.starts(with: "Mensajes en") ||
        child.description.starts(with: "Mensajes en") ||
        child.description.starts(with: "Messages sur") ||
        child.description.starts(with: "Poruke u kanalu") ||
        child.description.starts(with: "Messaggi in") ||
        child.description.starts(with: "Žinutės kanale") ||
        child.description.starts(with: "Üzenetek itt:") ||
        child.description.starts(with: "Berichten in") ||
        child.description.starts(with: "Meldinger på") ||
        child.description.starts(with: "Wiadomości w") ||
        child.description.starts(with: "Mensagens em") ||
        child.description.starts(with: "Mesaje pe") ||
        child.description.starts(with: "Kanavan") ||
        child.description.starts(with: "Meddelanden i") ||
        child.description.starts(with: "Tin nhắn trong") ||
        child.description.hasSuffix("kanalından mesaj var") ||
        child.description.starts(with: "Zprávy v kanálu") ||
        child.description.starts(with: "Μηνύματα στο") ||
        child.description.starts(with: "Съобщения в") ||
        child.description.starts(with: "Сообщения на") ||
        child.description.starts(with: "Повідомлення в каналі") ||
        child.description.hasSuffix("में मैसेज") ||
        child.description.starts(with: "ข้อความใน") ||
        child.description.hasSuffix("中的消息") ||
        child.description.hasSuffix("メッセージ") ||
        child.description.hasSuffix("中的訊息") ||
        child.description.hasSuffix("의 메시지")
      ) {
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
