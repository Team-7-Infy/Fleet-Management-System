import Foundation

struct APIClient {
    func request<Response: Decodable>(_ endpoint: APIEndpoint) async throws -> Response {
        guard let url = URL(string: "\(EnvironmentConfig.supabaseURL.absoluteString)\(endpoint.path)") else {
            throw AppError.networkUnavailable
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        
        // Supabase required headers
        request.setValue(EnvironmentConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(EnvironmentConfig.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AppError.networkUnavailable
        }
        
        do {
            let decoder = JSONDecoder()
            // Optional: If Supabase returns dates in ISO8601
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(Response.self, from: data)
        } catch {
            print("Decoding error: \(error)")
            throw AppError.networkUnavailable
        }
    }
}
