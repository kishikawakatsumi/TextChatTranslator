import SwiftUI
import Observation
import Translation

@main
struct TextChatTranslatorApp: App {
  @AppStorage("targetLanguage") private var targetLanguage = "ja"

  @State private var translationContext = TranslationContext()
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    WindowGroup {
      VStack {}
        .translationTask(translationContext.configuration) { (session) in
          appDelegate.translationSession = session
        }
    }
    Settings {
      SettingsView()
        .environment(\.translationContext, translationContext)
    }
  }
}

struct OpenSettings {
  @Environment(\.openSettings) var openSettings
}
