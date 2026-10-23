import Foundation

/// Uygulama içi dil seçimi (Türkçe / English).
/// Metinler kodda iki dilde yan yana durur: `L("Türkçe", "English")`.
enum Lang: String, CaseIterable, Identifiable {
    case tr, en

    var id: String { rawValue }
    var label: String { self == .tr ? "Türkçe" : "English" }

    static var current: Lang {
        if let saved = UserDefaults.standard.string(forKey: "lang"), let lang = Lang(rawValue: saved) {
            return lang
        }
        return Locale.preferredLanguages.first?.hasPrefix("tr") == true ? .tr : .en
    }
}

func L(_ tr: String, _ en: String) -> String {
    Lang.current == .tr ? tr : en
}
