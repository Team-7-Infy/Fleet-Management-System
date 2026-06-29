import Foundation

struct LocalStore {
    func save<Value>(_ value: Value, forKey key: String) async throws where Value: Encodable {
        let data = try JSONEncoder().encode(value)
        UserDefaults.standard.set(data, forKey: key)
    }

    func load<Value>(_ type: Value.Type, forKey key: String) async throws -> Value? where Value: Decodable {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try JSONDecoder().decode(type, from: data)
    }
    
    func remove(forKey key: String) async {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
