import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english
    case spanish
    case french
    case german
    case italian
    case portuguese
    case japanese
    case korean
    case chineseSimplified
    case arabic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .english: "English"
        case .spanish: "Spanish"
        case .french: "French"
        case .german: "German"
        case .italian: "Italian"
        case .portuguese: "Portuguese"
        case .japanese: "Japanese"
        case .korean: "Korean"
        case .chineseSimplified: "Chinese"
        case .arabic: "Arabic"
        }
    }

    var nativeTitle: String {
        switch self {
        case .english: "English"
        case .spanish: "Español"
        case .french: "Français"
        case .german: "Deutsch"
        case .italian: "Italiano"
        case .portuguese: "Português"
        case .japanese: "日本語"
        case .korean: "한국어"
        case .chineseSimplified: "简体中文"
        case .arabic: "العربية"
        }
    }

    var englishSubtitle: String? {
        nativeTitle == title ? nil : title
    }

    var shortTitle: String {
        switch self {
        case .chineseSimplified:
            "Chinese"
        default:
            title
        }
    }

    var translationIdentifier: String {
        switch self {
        case .english: "en"
        case .spanish: "es"
        case .french: "fr"
        case .german: "de"
        case .italian: "it"
        case .portuguese: "pt"
        case .japanese: "ja"
        case .korean: "ko"
        case .chineseSimplified: "zh-Hans"
        case .arabic: "ar"
        }
    }

    var speechLocaleIdentifier: String {
        switch self {
        case .english: "en-US"
        case .spanish: "es-ES"
        case .french: "fr-FR"
        case .german: "de-DE"
        case .italian: "it-IT"
        case .portuguese: "pt-BR"
        case .japanese: "ja-JP"
        case .korean: "ko-KR"
        case .chineseSimplified: "zh-Hans-CN"
        case .arabic: "ar-SA"
        }
    }

    var localeLanguage: Locale.Language {
        Locale.Language(identifier: translationIdentifier)
    }
}

struct ConversationDirection: Equatable {
    var source: AppLanguage
    var target: AppLanguage

    static let `default` = ConversationDirection(source: .english, target: .spanish)

    mutating func reverse() {
        (source, target) = (target, source)
    }
}

enum LanguagePosition: String, Identifiable {
    case source
    case target

    var id: String { rawValue }

    var title: String {
        switch self {
        case .source: "I speak"
        case .target: "They hear"
        }
    }

    var subtitle: String {
        switch self {
        case .source: "The language you talk in"
        case .target: "The language CatLate speaks back"
        }
    }
}
