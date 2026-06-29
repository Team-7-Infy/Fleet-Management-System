import Foundation

struct APIEndpoint: Hashable {
    enum Method: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
        case patch = "PATCH"
    }

    let path: String
    let method: Method

    init(path: String, method: Method = .get) {
        self.path = path
        self.method = method
    }
}
