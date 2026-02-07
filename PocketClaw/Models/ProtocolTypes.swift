import Foundation

// MARK: - Protocol Frame Types

/// Incoming frame from WebSocket — could be a response or event
enum ServerFrame: Sendable {
    case response(ResponseFrame)
    case event(EventFrame)
    case unknown
}

// MARK: - Request Frame (Client → Server)

struct RequestFrame: Codable, Sendable {
    let type: String
    let id: String
    let method: String
    let params: [String: AnyCodable]?

    init(id: String, method: String, params: [String: AnyCodable]? = nil) {
        self.type = "req"
        self.id = id
        self.method = method
        self.params = params
    }
}

// MARK: - Response Frame (Server → Client)

struct ResponseFrame: Codable, Sendable {
    let type: String
    let id: String
    let ok: Bool
    let payload: AnyCodable?
    let error: ResponseError?
}

struct ResponseError: Codable, Sendable {
    let code: Int?
    let message: String?
    let details: String?
}

// MARK: - Event Frame (Server → Client)

struct EventFrame: Codable, Sendable {
    let type: String
    let event: String
    let payload: AnyCodable?
}

// MARK: - Raw Frame Discriminator

private struct FrameDiscriminator: Codable {
    let type: String
}

// MARK: - Frame Parsing

extension ServerFrame {
    static func parse(from data: Data) -> ServerFrame {
        guard let disc = try? JSONDecoder().decode(FrameDiscriminator.self, from: data) else {
            return .unknown
        }
        switch disc.type {
        case "res":
            guard let frame = try? JSONDecoder().decode(ResponseFrame.self, from: data) else {
                return .unknown
            }
            return .response(frame)
        case "event":
            guard let frame = try? JSONDecoder().decode(EventFrame.self, from: data) else {
                return .unknown
            }
            return .event(frame)
        default:
            return .unknown
        }
    }
}

// MARK: - AnyCodable (lightweight type-erased Codable)

struct AnyCodable: Codable, Sendable, @unchecked Sendable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map(\.value)
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues(\.value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "AnyCodable cannot decode value"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyCodable cannot encode value")
            )
        }
    }

    // MARK: - Convenience Accessors

    var stringValue: String? { value as? String }
    var intValue: Int? { value as? Int }
    var boolValue: Bool? { value as? Bool }
    var doubleValue: Double? { value as? Double }
    var dictValue: [String: Any]? { value as? [String: Any] }
    var arrayValue: [Any]? { value as? [Any] }
}
