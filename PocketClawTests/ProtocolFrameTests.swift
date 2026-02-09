import Testing
import Foundation
@testable import PocketClaw

// MARK: - RequestFrame Encoding Tests

@Suite("RequestFrame Encoding")
struct RequestFrameEncodingTests {
    @Test("Encodes with type=req")
    func typeIsReq() throws {
        let frame = RequestFrame(id: "1", method: "sessions.list")
        let data = try JSONEncoder().encode(frame)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(dict["type"] as? String == "req")
    }

    @Test("Includes method and id")
    func methodAndId() throws {
        let frame = RequestFrame(id: "abc", method: "chat.send")
        let data = try JSONEncoder().encode(frame)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(dict["id"] as? String == "abc")
        #expect(dict["method"] as? String == "chat.send")
    }

    @Test("Encodes params when provided")
    func withParams() throws {
        let frame = RequestFrame(
            id: "2",
            method: "chat.send",
            params: ["sessionKey": AnyCodable("s1"), "message": AnyCodable("hello")]
        )
        let data = try JSONEncoder().encode(frame)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let params = dict["params"] as? [String: Any]
        #expect(params?["sessionKey"] as? String == "s1")
        #expect(params?["message"] as? String == "hello")
    }

    @Test("Omits params when nil")
    func noParams() throws {
        let frame = RequestFrame(id: "3", method: "sessions.list")
        let data = try JSONEncoder().encode(frame)
        let str = String(data: data, encoding: .utf8)!
        // params should not appear or should be null
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(dict["params"] == nil || dict["params"] is NSNull)
    }
}

// MARK: - ServerFrame Parsing Tests

@Suite("ServerFrame Parsing")
struct ServerFrameParsing {
    @Test("Parses response frame")
    func parseResponse() {
        let json = """
        {"type": "res", "id": "req-1", "ok": true, "payload": {"sessions": []}}
        """
        let frame = ServerFrame.parse(from: Data(json.utf8))
        if case .response(let res) = frame {
            #expect(res.id == "req-1")
            #expect(res.ok == true)
        } else {
            Issue.record("Expected .response, got \(frame)")
        }
    }

    @Test("Parses error response")
    func parseErrorResponse() {
        let json = """
        {"type": "res", "id": "req-2", "ok": false, "error": {"code": 404, "message": "Not found"}}
        """
        let frame = ServerFrame.parse(from: Data(json.utf8))
        if case .response(let res) = frame {
            #expect(res.ok == false)
            #expect(res.error?.code == 404)
            #expect(res.error?.message == "Not found")
        } else {
            Issue.record("Expected .response")
        }
    }

    @Test("Parses event frame")
    func parseEvent() {
        let json = """
        {"type": "event", "event": "chat", "payload": {"state": "delta", "text": "Hello"}}
        """
        let frame = ServerFrame.parse(from: Data(json.utf8))
        if case .event(let evt) = frame {
            #expect(evt.event == "chat")
            #expect(evt.payload?.dictValue?["state"] as? String == "delta")
        } else {
            Issue.record("Expected .event")
        }
    }

    @Test("Returns unknown for unrecognized type")
    func unknownType() {
        let json = """
        {"type": "ping"}
        """
        let frame = ServerFrame.parse(from: Data(json.utf8))
        if case .unknown = frame {
            // expected
        } else {
            Issue.record("Expected .unknown")
        }
    }

    @Test("Returns unknown for invalid JSON")
    func invalidJson() {
        let frame = ServerFrame.parse(from: Data("not json".utf8))
        if case .unknown = frame {
            // expected
        } else {
            Issue.record("Expected .unknown")
        }
    }
}

// MARK: - AnyCodable Tests

@Suite("AnyCodable")
struct AnyCodableTests {
    @Test("Decodes string")
    func decodeString() throws {
        let json = Data("\"hello\"".utf8)
        let val = try JSONDecoder().decode(AnyCodable.self, from: json)
        #expect(val.stringValue == "hello")
    }

    @Test("Decodes int")
    func decodeInt() throws {
        let json = Data("42".utf8)
        let val = try JSONDecoder().decode(AnyCodable.self, from: json)
        #expect(val.intValue == 42)
    }

    @Test("Decodes bool")
    func decodeBool() throws {
        let json = Data("true".utf8)
        let val = try JSONDecoder().decode(AnyCodable.self, from: json)
        #expect(val.boolValue == true)
    }

    @Test("Decodes double")
    func decodeDouble() throws {
        let json = Data("3.14".utf8)
        let val = try JSONDecoder().decode(AnyCodable.self, from: json)
        #expect(val.doubleValue == 3.14)
    }

    @Test("Decodes null")
    func decodeNull() throws {
        let json = Data("null".utf8)
        let val = try JSONDecoder().decode(AnyCodable.self, from: json)
        #expect(val.value is NSNull)
    }

    @Test("Decodes nested dictionary")
    func decodeDict() throws {
        let json = Data("{\"key\": \"value\", \"num\": 5}".utf8)
        let val = try JSONDecoder().decode(AnyCodable.self, from: json)
        let dict = val.dictValue
        #expect(dict?["key"] as? String == "value")
        #expect(dict?["num"] as? Int == 5)
    }

    @Test("Decodes array")
    func decodeArray() throws {
        let json = Data("[1, 2, 3]".utf8)
        let val = try JSONDecoder().decode(AnyCodable.self, from: json)
        let arr = val.arrayValue
        #expect(arr?.count == 3)
    }

    @Test("Round-trips through encode/decode")
    func roundTrip() throws {
        let original = AnyCodable(["name": "test", "count": 42] as [String: Any])
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: encoded)
        #expect(decoded.dictValue?["name"] as? String == "test")
    }
}
