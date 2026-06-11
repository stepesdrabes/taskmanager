import Foundation
import Observation

/// Runtime localization backed by one JSON file per language under
/// `Localizations/`. Keys are dotted paths into the (nested) JSON; values may
/// contain `{placeholder}` tokens filled in at lookup time. Missing keys fall
/// back to English, then to the key itself. Switching language is live —
/// views re-render because `strings` is observed.
@Observable @MainActor
final class Localizer {
    struct Language: Identifiable, Hashable {
        let code: String
        let name: String
        var id: String { code }
    }

    /// Stored preference meaning "follow the system language".
    static let systemCode = "system"
    private static let defaultsKey = "appLanguage"

    let available: [Language]
    private(set) var languageCode: String
    private var strings: [String: String]
    private let fallback: [String: String]

    /// "system" or a concrete code like "en" / "cs"; persisted and applied live.
    var preference: String {
        didSet {
            guard preference != oldValue else { return }
            UserDefaults.standard.set(preference, forKey: Self.defaultsKey)
            languageCode = Self.resolve(preference, available: available)
            strings = Self.load(languageCode)
        }
    }

    init() {
        let discovered = Self.discover()
        available = discovered
        fallback = Self.load("en")
        let stored = UserDefaults.standard.string(forKey: Self.defaultsKey) ?? Self.systemCode
        let code = Self.resolve(stored, available: discovered)
        languageCode = code
        strings = Self.load(code)
        preference = stored   // last: a didSet would otherwise touch the above
    }

    /// Localized string for `key`, with optional `{name}` substitutions.
    func callAsFunction(_ key: String, _ arguments: KeyValuePairs<String, String> = [:]) -> String {
        var text = strings[key] ?? fallback[key] ?? key
        for (name, value) in arguments {
            text = text.replacingOccurrences(of: "{\(name)}", with: value)
        }
        return text
    }

    // MARK: - Loading

    /// The bundle carrying `Localizations/`. SwiftPM's generated `Bundle.module`
    /// looks beside the executable and falls back to the build machine's
    /// absolute path, so it crashes once the `.app` is moved off the build host.
    /// We locate the resource bundle ourselves: `Contents/Resources` in the
    /// assembled `.app`, or next to the binary under `swift run`.
    private static let bundle: Bundle = {
        let name = "TaskManager_TaskManager.bundle"
        let candidates = [
            Bundle.main.resourceURL?.appendingPathComponent(name),
            Bundle.main.bundleURL.appendingPathComponent(name),
        ]
        for case let url? in candidates where (try? url.checkResourceIsReachable()) == true {
            if let bundle = Bundle(url: url) { return bundle }
        }
        return .main
    }()

    private static func resolve(_ preference: String, available: [Language]) -> String {
        if preference == systemCode { return systemMatch(available) }
        return available.contains { $0.code == preference } ? preference : "en"
    }

    private static func systemMatch(_ available: [Language]) -> String {
        for identifier in Locale.preferredLanguages {
            let code = Locale(identifier: identifier).language.languageCode?.identifier ?? String(identifier.prefix(2))
            if available.contains(where: { $0.code == code }) { return code }
        }
        return "en"
    }

    private static func discover() -> [Language] {
        guard let urls = bundle.urls(forResourcesWithExtension: "json", subdirectory: "Localizations") else {
            return []
        }
        return urls
            .map { url -> Language in
                let code = url.deletingPathExtension().lastPathComponent
                return Language(code: code, name: load(code)["language.name"] ?? code)
            }
            .sorted { $0.name < $1.name }
    }

    private static func load(_ code: String) -> [String: String] {
        guard let url = bundle.url(forResource: code, withExtension: "json", subdirectory: "Localizations"),
              let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return flatten(object)
    }

    private static func flatten(_ dictionary: [String: Any], prefix: String = "") -> [String: String] {
        var result: [String: String] = [:]
        for (key, value) in dictionary {
            let path = prefix.isEmpty ? key : "\(prefix).\(key)"
            if let string = value as? String {
                result[path] = string
            } else if let nested = value as? [String: Any] {
                result.merge(flatten(nested, prefix: path)) { current, _ in current }
            }
        }
        return result
    }
}
