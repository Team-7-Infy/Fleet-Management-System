import Foundation
import Supabase

protocol SupabaseServiceProtocol: AnyObject, Sendable {
    var client: SupabaseClient { get }
    var decoder: JSONDecoder { get }
    var encoder: JSONEncoder { get }
}

final actor SupabaseService: SupabaseServiceProtocol {
    nonisolated let client: SupabaseClient

    nonisolated var decoder: JSONDecoder { SharedDecoder.json }
    nonisolated var encoder: JSONEncoder { SharedDecoder.encoder }

    init() {
        client = SupabaseClient(
            supabaseURL: EnvironmentConfig.supabaseURL,
            supabaseKey: EnvironmentConfig.supabaseAnonKey
        )
    }
}
