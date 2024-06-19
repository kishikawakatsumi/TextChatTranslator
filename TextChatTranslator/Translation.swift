import Foundation
import Translation

func translate(session: TranslationSession, text: String) async throws -> String {
  do {
    let availability = LanguageAvailability()
    let status = try await availability.status(
      for: text,
      to: session.targetLanguage
    )
    if status == .installed {
      let response = try await session.translate(text)
      return response.targetText
    }
  } catch {
    print(error)
  }
  return text
}
