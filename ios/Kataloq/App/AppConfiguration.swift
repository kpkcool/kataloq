import Foundation

/// Runtime configuration. The backend base URL is resolved in this order:
///   1. `KATALOQ_API_BASE_URL` environment variable (scheme → Run → Environment; useful on a device)
///   2. `KataloqAPIBaseURL` in Info.plist, set from the `API_BASE_URL` build setting
///   3. `http://localhost:3000` (the Simulator shares the Mac's network)
struct AppConfiguration: Equatable {
    static let baseURLEnvironmentKey = "KATALOQ_API_BASE_URL"
    static let baseURLInfoKey = "KataloqAPIBaseURL"

    static let defaultBaseURL: URL = {
        guard let url = URL(string: "http://localhost:3000") else {
            preconditionFailure("The default API base URL literal is invalid.")
        }
        return url
    }()

    let apiBaseURL: URL

    static func load(
        infoDictionary: [String: Any]? = Bundle.main.infoDictionary,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> AppConfiguration {
        let candidates = [environment[baseURLEnvironmentKey], infoDictionary?[baseURLInfoKey] as? String]
        for candidate in candidates {
            if let url = validBaseURL(candidate) {
                return AppConfiguration(apiBaseURL: url)
            }
        }
        return AppConfiguration(apiBaseURL: defaultBaseURL)
    }

    private static func validBaseURL(_ value: String?) -> URL? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty,
              !trimmed.contains("$("), // an unexpanded build setting
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil
        else { return nil }
        return url
    }
}
