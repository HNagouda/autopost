import Foundation

extension KeyedDecodingContainer {
    /// Lets a library saved by an older version load after new settings were added, instead of failing as a whole.
    func decode<T: Decodable>(_ key: Key, default value: T) throws -> T {
        try decodeIfPresent(T.self, forKey: key) ?? value
    }
}
