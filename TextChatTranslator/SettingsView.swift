import SwiftUI
#if compiler(>=6.0)
import Translation

@available(macOS 15, *)
struct SettingsView: View {
  var body: some View {
    TranslationSettingsView()
  }
}

@available(macOS 15, *)
struct TranslationSettingsView: View {
  @AppStorage("backgroundColor") private var backgroundColor = Color.white
  @AppStorage("textColor" )private var textColor = Color.black
  @AppStorage("fontSize" )private var fontSize = 16

  @AppStorage("sourceLanguage") private var sourceLanguage = "en-Latn-US"
  @AppStorage("targetLanguage") private var targetLanguage = "ja-Jpan-JP"
  
  @State private var supportedLanguages = [Locale.Language]()
  @State private var languageAvailability: String = ""
  @State private var needsInstallTranslation: Bool = false

  @Environment(\.translationContext) private var translationContext

  var body: some View {
    Form {
      ColorPicker("Background Color:", selection: $backgroundColor)
      ColorPicker("Text Color:", selection: $textColor)
      Picker("Font Size:", selection: $fontSize) {
        ForEach([4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 26, 28, 30, 32, 34, 36, 40, 44], id: \.self) { (size) in
          Text("\(size) pt")
            .tag(size)
        }
      }

      Divider()
        .padding(.vertical)

      Picker("Source Language:", selection: $sourceLanguage) {
        let locale = Locale()
        ForEach(Array(zip(supportedLanguages.indices, supportedLanguages)), id: \.0) { (index, language) in
          if let languageName = locale.localizedString(forIdentifier: language.maximalIdentifier) {
            Text(languageName)
              .tag(language.maximalIdentifier)
          }
        }
      }
      .onChange(of: sourceLanguage) { (oldValue, newValue) in
        invalidateTranslationSession()
      }
      Picker("Target Language:", selection: $targetLanguage) {
        let locale = Locale()
        ForEach(Array(zip(supportedLanguages.indices, supportedLanguages)), id: \.0) { (index, language) in
          if let languageName = locale.localizedString(forIdentifier: language.maximalIdentifier) {
            Text(languageName)
              .tag(language.maximalIdentifier)
          }
        }
      }
      .onChange(of: targetLanguage) { (oldValue, newValue) in
        invalidateTranslationSession()
      }
      Text(languageAvailability)
        .fixedSize(horizontal: false, vertical: true)
        .lineLimit(nil)
      Button("Install Translation") {
        Task { @MainActor in
          do {
            try await translationContext.session?.prepareTranslation()
          } catch {
            print(error)
          }
        }
      }
      .disabled(!needsInstallTranslation)
    }
    .padding(20)
    .frame(width: 480)
    .task { @MainActor in
      let availability = LanguageAvailability()
      supportedLanguages = await availability.supportedLanguages
    }
    .translationTask(translationContext.configuration) { (session) in
      translationContext.session = session

      let locale = Locale()

      let source = Locale.Language(identifier: sourceLanguage)
      let target = Locale.Language(identifier: targetLanguage)

      let availability = LanguageAvailability()
      let status = await availability.status(from: source, to: target)
      switch status {
      case .installed:
        languageAvailability = "\(locale.localizedString(forIdentifier: sourceLanguage) ?? sourceLanguage) to \(locale.localizedString(forIdentifier: targetLanguage) ?? targetLanguage) translation is installed."
        needsInstallTranslation = false
      case .supported:
        languageAvailability = "\(locale.localizedString(forIdentifier: sourceLanguage) ?? sourceLanguage) to \(locale.localizedString(forIdentifier: targetLanguage) ?? targetLanguage) translation is supported but not installed."
        needsInstallTranslation = true
      case .unsupported:
        languageAvailability = "\(locale.localizedString(forIdentifier: sourceLanguage) ?? sourceLanguage) to \(locale.localizedString(forIdentifier: targetLanguage) ?? targetLanguage) translation is not supported."
        needsInstallTranslation = false
      @unknown default:
        break
      }
    }
  }

  private func invalidateTranslationSession() {
    translationContext.configuration.invalidate()
    translationContext.configuration = TranslationSession.Configuration(
      source: Locale.Language(identifier: sourceLanguage),
      target: Locale.Language(identifier: targetLanguage)
    )
  }
}
#endif

extension Color: RawRepresentable {
  public init?(rawValue: String) {
    guard let data = Data(base64Encoded: rawValue) else {
      self = .black
      return
    }
    do {
      let color = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) ?? .black
      self = Color(color)
    } catch {
      self = .black
    }
  }

  public var rawValue: String {
    do {
      let data = try NSKeyedArchiver.archivedData(
        withRootObject: NSColor(self),
        requiringSecureCoding: false
      )
      return data.base64EncodedString()
    } catch {
      return ""
    }
  }
}
