import Combine
import Foundation

class RoamConfig: ObservableObject {
    static let shared = RoamConfig()

    @PublishedPersist(key: "roamGraphName", defaultValue: "")
    var graphName: String

    @PublishedPersist(key: "roamApiToken", defaultValue: "")
    var apiToken: String

    // Always strip whitespace/control chars when reading — stray newlines from .env
    // or copy-paste are the most common cause of "hostname not found" errors.
    private var cleanGraphName: String { graphName.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var cleanApiToken: String  { apiToken.trimmingCharacters(in: .whitespacesAndNewlines) }

    var isConfigured: Bool { !cleanGraphName.isEmpty && !cleanApiToken.isEmpty }

    var api: RoamAPI? {
        guard isConfigured else { return nil }
        return RoamAPI(graphName: cleanGraphName, token: cleanApiToken)
    }

    private init() {
        loadDotEnvIfNeeded()
    }

    // Reads ~/.env or ~/Documents/NotchDrop/.env on first launch (before any credentials are saved).
    // Copy .env.example → one of those paths and fill in your values.
    private func loadDotEnvIfNeeded() {
        guard graphName.isEmpty, apiToken.isEmpty else { return }

        let candidates: [URL] = [
            documentsDirectory.appendingPathComponent(".env"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".env"),
        ]

        for url in candidates {
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let pairs = parseEnv(content)
            if let name = pairs["ROAM_GRAPH_NAME"], !name.isEmpty { graphName = name }
            if let token = pairs["ROAM_API_TOKEN"], !token.isEmpty { apiToken = token }
            if isConfigured { break }
        }
    }

    private func parseEnv(_ raw: String) -> [String: String] {
        raw.components(separatedBy: .newlines).reduce(into: [:]) { result, line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("#"), let eqRange = trimmed.range(of: "=") else { return }
            let key = String(trimmed[..<eqRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let value = String(trimmed[eqRange.upperBound...])
                .trimmingCharacters(in: .init(charactersIn: " \t\"'"))
            result[key] = value
        }
    }
}
