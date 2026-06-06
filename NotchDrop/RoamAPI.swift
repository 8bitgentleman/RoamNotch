import Foundation

struct RoamAPI {
    let graphName: String
    let token: String

    private static let baseURL = "https://api.roamresearch.com"

    enum RoamError: Error, LocalizedError {
        case notConfigured
        case httpError(Int, String)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .notConfigured: return "Roam API not configured — add credentials in Settings"
            case .httpError(let code, let body): return "Roam API error \(code): \(body)"
            case .invalidResponse: return "Invalid response from Roam API"
            }
        }
    }

    struct CaptureBlock {
        let text: String
        let indent: Int
    }

    // MARK: - Public

    func sendCapture(_ blocks: [CaptureBlock]) async throws {
        guard !blocks.isEmpty else { return }
        try await sendBlocks(blocks, parentUID: Self.todayUID, childOrder: "last")
    }

    // MARK: - Tree send

    private func sendBlocks(_ blocks: [CaptureBlock], parentUID: String, childOrder: Any) async throws {
        var i = 0
        var order: Any = childOrder
        while i < blocks.count {
            let block = blocks[i]
            let uid = Self.generateUID()

            let payload: [String: Any] = [
                "action": "create-block",
                "block": ["string": block.text, "uid": uid],
                "location": ["parent-uid": parentUID, "order": order],
            ]
            let encodedName = graphName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? graphName
            try await perform(request(path: "/api/graph/\(encodedName)/write", body: payload))

            // Advance order to numeric after the first insertion
            order = (order as? Int ?? 0) + 1
            i += 1

            // Collect all directly-nested children (indent strictly greater than current block)
            var children: [CaptureBlock] = []
            while i < blocks.count, blocks[i].indent > block.indent {
                children.append(blocks[i])
                i += 1
            }

            if !children.isEmpty {
                // Normalize children so the shallowest starts at indent 0
                let base = children.map(\.indent).min()!
                let normalized = children.map { CaptureBlock(text: $0.text, indent: $0.indent - base) }
                try await sendBlocks(normalized, parentUID: uid, childOrder: 0)
            }
        }
    }

    // MARK: - HTTP

    private func request(path: String, body: [String: Any]) throws -> URLRequest {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.roamresearch.com"
        components.percentEncodedPath = path
        guard let url = components.url else { throw RoamError.invalidResponse }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "x-authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return req
    }

    // URLSession that never auto-follows redirects so we can manually re-POST with the body intact.
    private static let noRedirectSession: URLSession = {
        let config = URLSessionConfiguration.default
        return URLSession(configuration: config, delegate: NoRedirectDelegate(), delegateQueue: nil)
    }()

    private func perform(_ initial: URLRequest) async throws {
        var req = initial
        for _ in 0 ..< 4 {
            let (data, response) = try await Self.noRedirectSession.data(for: req)
            guard let http = response as? HTTPURLResponse else { throw RoamError.invalidResponse }
            switch http.statusCode {
            case 200: return
            case 301, 302, 307, 308:
                // Re-POST to the peer URL with the original body preserved.
                // Validate the redirect stays within *.roamresearch.com over https
                // before forwarding the Authorization token.
                guard
                    let loc = http.value(forHTTPHeaderField: "Location"),
                    let base = req.url,
                    let newURL = URL(string: loc, relativeTo: base)?.absoluteURL,
                    newURL.scheme == "https",
                    let host = newURL.host?.lowercased(),
                    host == "api.roamresearch.com" || host.hasSuffix(".api.roamresearch.com")
                else { throw RoamError.invalidResponse }
                req.url = newURL
                continue
            default:
                let body = String(data: data, encoding: .utf8) ?? ""
                throw RoamError.httpError(http.statusCode, body)
            }
        }
        throw RoamError.invalidResponse
    }

    // MARK: - Helpers

    // Roam daily note UIDs are the date as MM-DD-YYYY
    static var todayUID: String {
        let f = DateFormatter()
        f.dateFormat = "MM-dd-yyyy"
        return f.string(from: Date())
    }

    static func generateUID() -> String {
        let chars = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-")
        return String((0 ..< 9).map { _ in chars.randomElement()! })
    }
}

// Prevents URLSession from auto-following redirects so RoamAPI can re-POST with the body intact.
private final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil) // don't follow; we handle it manually
    }
}
