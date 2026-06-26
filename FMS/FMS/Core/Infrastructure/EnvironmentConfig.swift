import Foundation

enum EnvironmentConfig {
    enum Key: String {
        case supabaseURL = "SUPABASE_URL"
        case supabaseAnonKey = "SUPABASE_ANON_KEY"
    }

    static var supabaseURL: URL {
        guard let string = Bundle.main.object(forInfoDictionaryKey: Key.supabaseURL.rawValue) as? String,
              let url = URL(string: string)
        else {
            fatalError("Missing or invalid SUPABASE_URL in Info.plist")
        }
        return url
    }

    static var supabaseAnonKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: Key.supabaseAnonKey.rawValue) as? String,
              !key.isEmpty
        else {
            fatalError("Missing SUPABASE_ANON_KEY in Info.plist")
        }
        return key
    }
}
