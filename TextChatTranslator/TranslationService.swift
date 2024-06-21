import Foundation

class TranslationService {
  private let cache = NSCache<NSString, NSString>()

  func translate(text: String) async throws -> String {
    // You can implement your own translation logic here
    return text
  }
}
