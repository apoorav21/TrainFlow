import Foundation

// MARK: - API Error

enum APIError: LocalizedError {
    case unauthorized
    case httpError(Int, String?)
    case decodingError(String)
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Please sign in again."
        case .httpError(let code, let msg):
            return msg ?? "Server error \(code)"
        case .decodingError(let msg):
            return "Data error: \(msg)"
        case .networkError(let msg):
            return msg
        }
    }
}

// MARK: - API Client

final class APIClient {
    static let shared = APIClient()
    private init() {}

    private let baseURL = AWSTFConfig.shared.apiBaseURL

    // MARK: - Public Interface

    func get<T: Decodable>(_ path: String, queryItems: [URLQueryItem] = []) async throws -> T {
        let data = try await request(path, method: "GET", body: nil as EmptyBody?, queryItems: queryItems)
        return try decode(T.self, from: data, path: path)
    }

    func post<T: Decodable>(_ path: String, body: some Encodable) async throws -> T {
        let data = try await request(path, method: "POST", body: body, queryItems: [])
        return try decode(T.self, from: data, path: path)
    }

    func put<T: Decodable>(_ path: String, body: some Encodable) async throws -> T {
        let data = try await request(path, method: "PUT", body: body, queryItems: [])
        return try decode(T.self, from: data, path: path)
    }

    func delete(_ path: String) async throws {
        _ = try await request(path, method: "DELETE", body: nil as EmptyBody?, queryItems: [])
    }

    // MARK: - Private Request Builder

    private func request<B: Encodable>(
        _ path: String,
        method: String,
        body: B?,
        queryItems: [URLQueryItem],
        timeout: TimeInterval = 30
    ) async throws -> Data {
        guard let token = await AuthService.shared.validAccessToken() else {
            throw APIError.unauthorized
        }

        var components = URLComponents(string: baseURL + path)
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }

        guard let url = components?.url else {
            throw APIError.networkError("Invalid URL: \(baseURL + path)")
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = timeout

        if let body {
            do {
                req.httpBody = try JSONEncoder().encode(body)
            } catch {
                throw APIError.networkError("Failed to encode request body: \(error.localizedDescription)")
            }
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch let urlError as URLError {
            throw APIError.networkError(urlError.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkError("Invalid response")
        }

        NSLog("[APIClient] \(method) \(path) → \(http.statusCode)")

        switch http.statusCode {
        case 200...204:
            return data
        case 401, 403:
            throw APIError.unauthorized
        default:
            // Try to decode a structured error body: { "error": "..." } or { "message": "..." }
            let message = extractErrorMessage(from: data)
            throw APIError.httpError(http.statusCode, message)
        }
    }

    // MARK: - Chat Request (extended timeout)

    func chat<T: Decodable>(_ path: String, body: some Encodable) async throws -> T {
        let data = try await request(path, method: "POST", body: body, queryItems: [], timeout: 90)
        return try decode(T.self, from: data, path: path)
    }

    // MARK: - Helpers

    private func decode<T: Decodable>(_ type: T.Type, from data: Data, path: String) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            let preview = String(data: data.prefix(200), encoding: .utf8) ?? "<binary>"
            NSLog("[APIClient] Decode error for \(path): \(error)\nBody: \(preview)")
            throw APIError.decodingError(error.localizedDescription)
        }
    }

    private func extractErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json["error"] as? String
            ?? json["message"] as? String
            ?? json["msg"] as? String
    }
}

// MARK: - Sentinel type for DELETE bodies

private struct EmptyBody: Encodable {}
