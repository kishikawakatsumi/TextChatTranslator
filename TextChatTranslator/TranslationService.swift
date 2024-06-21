import Foundation
import Translation

class TranslationService {
  private let cache = NSCache<NSString, NSString>()

#if compiler(>=6.0)
  @available(macOS 15.0, *)
  func translate(session: TranslationSession?, text: String) async throws -> String {
    if let translation = cache.object(forKey: NSString(string: text)) {
      return String(translation)
    }
    guard let session = session else {
      return text
    }

    do {
      let availability = LanguageAvailability()
      let status = try await availability.status(
        for: text,
        to: session.targetLanguage
      )
      if status == .installed {
        let response = try await session.translate(text)
        cache.setObject(NSString(string: response.targetText), forKey: NSString(string: text))
        return response.targetText
      }
    } catch {
      print(error)
    }
    return text
  }
#else
  func translate(text: String) async throws -> String {
    // You can implement your own translation logic here
    return text
  }
#endif
}

