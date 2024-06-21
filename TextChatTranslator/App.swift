import SwiftUI

#if canImport(Synchronization)
import Observation
import Translation

@main
@available(macOS 15.0, *)
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

@available(macOS 15.0, *)
struct OpenSettings {
  @Environment(\.openSettings) var openSettings
}
#else
@main
struct TextChatTranslatorApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  
  var body: some Scene {
    WindowGroup {
      VStack {}
        .onAppear {
          appDelegate.translationSession = nil
        }
    }
  }
}
#endif

