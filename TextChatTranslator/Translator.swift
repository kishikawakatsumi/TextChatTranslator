import Foundation
import ApplicationServices

protocol Translator {
  var scrollPosition: CGPoint { get }
  var messages: [Message] { get }
  func perform()
}

struct Message {
  let frame: CGRect
  let textFrame: CGRect
  let text: String
  let axElement: AXUIElement
}
