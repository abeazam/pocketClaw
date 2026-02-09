import Testing
import Foundation
@testable import PocketClaw

// MARK: - Message Properties Tests

@Suite("Message Properties")
struct MessagePropertiesTests {
    @Test("Role checks: isUser, isAssistant, isSystem")
    func roleChecks() {
        let user = Message(id: "1", role: "user", content: "hi")
        #expect(user.isUser == true)
        #expect(user.isAssistant == false)
        #expect(user.isSystem == false)

        let assistant = Message(id: "2", role: "assistant", content: "hello")
        #expect(assistant.isUser == false)
        #expect(assistant.isAssistant == true)

        let system = Message(id: "3", role: "system", content: "init")
        #expect(system.isSystem == true)
    }

    @Test("Heartbeat detection: HEARTBEAT_OK")
    func heartbeatOK() {
        let msg = Message(id: "1", role: "assistant", content: "HEARTBEAT_OK - all good")
        #expect(msg.isHeartbeat == true)
    }

    @Test("Heartbeat detection: READ HEARTBEAT.MD")
    func heartbeatMD() {
        let msg = Message(id: "2", role: "assistant", content: "Please read heartbeat.md for status")
        #expect(msg.isHeartbeat == true)
    }

    @Test("Heartbeat detection: event-driven status header")
    func heartbeatEventDriven() {
        let msg = Message(id: "3", role: "assistant", content: "# Heartbeat - Event-Driven Status\nAll systems go")
        #expect(msg.isHeartbeat == true)
    }

    @Test("Normal message is not heartbeat")
    func notHeartbeat() {
        let msg = Message(id: "4", role: "assistant", content: "Here is your code review...")
        #expect(msg.isHeartbeat == false)
    }

    @Test("Case-insensitive heartbeat detection")
    func caseInsensitive() {
        let msg = Message(id: "5", role: "assistant", content: "heartbeat_ok")
        #expect(msg.isHeartbeat == true)
    }
}

// MARK: - Message.fromServerPayload Tests

@Suite("Message.fromServerPayload")
struct MessageFromServerPayloadTests {
    @Test("Parses simple string content")
    func simpleContent() {
        let payload: [String: Any] = [
            "id": "msg-1",
            "role": "assistant",
            "content": "Hello world"
        ]
        let msg = Message.fromServerPayload(payload)
        #expect(msg?.id == "msg-1")
        #expect(msg?.role == "assistant")
        #expect(msg?.content == "Hello world")
    }

    @Test("Parses nested message object")
    func nestedMessage() {
        let payload: [String: Any] = [
            "message": [
                "id": "msg-2",
                "role": "user",
                "content": "Tell me a joke"
            ] as [String: Any],
            "runId": "run-1"
        ]
        let msg = Message.fromServerPayload(payload)
        #expect(msg?.id == "msg-2")
        #expect(msg?.role == "user")
        #expect(msg?.content == "Tell me a joke")
    }

    @Test("Uses runId as fallback id")
    func runIdFallback() {
        let payload: [String: Any] = [
            "role": "assistant",
            "content": "hi",
            "runId": "run-42"
        ]
        let msg = Message.fromServerPayload(payload)
        #expect(msg?.id == "run-42")
    }

    @Test("Defaults role to assistant")
    func defaultRole() {
        let payload: [String: Any] = [
            "id": "msg-3",
            "content": "Something"
        ]
        let msg = Message.fromServerPayload(payload)
        #expect(msg?.role == "assistant")
    }

    @Test("Parses content blocks with text")
    func contentBlocks() {
        let payload: [String: Any] = [
            "id": "msg-4",
            "role": "assistant",
            "content": [
                ["type": "text", "text": "Part one. "],
                ["type": "text", "text": "Part two."]
            ] as [[String: Any]]
        ]
        let msg = Message.fromServerPayload(payload)
        #expect(msg?.content == "Part one. Part two.")
    }

    @Test("Parses thinking content blocks")
    func thinkingBlocks() {
        let payload: [String: Any] = [
            "id": "msg-5",
            "role": "assistant",
            "content": [
                ["type": "thinking", "thinking": "Let me think about this..."],
                ["type": "text", "text": "The answer is 42."]
            ] as [[String: Any]]
        ]
        let msg = Message.fromServerPayload(payload)
        #expect(msg?.content == "The answer is 42.")
        #expect(msg?.thinking == "Let me think about this...")
    }

    @Test("Parses top-level thinking field")
    func topLevelThinking() {
        let payload: [String: Any] = [
            "id": "msg-6",
            "role": "assistant",
            "content": "Result",
            "thinking": "Reasoning here"
        ]
        let msg = Message.fromServerPayload(payload)
        #expect(msg?.thinking == "Reasoning here")
    }

    @Test("Parses timestamp from various fields")
    func timestampParsing() {
        // From inner "timestamp"
        let payload1: [String: Any] = [
            "id": "t1", "role": "user", "content": "hi",
            "timestamp": "2026-02-07T10:00:00Z"
        ]
        #expect(Message.fromServerPayload(payload1)?.timestamp == "2026-02-07T10:00:00Z")

        // From "ts"
        let payload2: [String: Any] = [
            "id": "t2", "role": "user", "content": "hi",
            "ts": "2026-02-07T11:00:00Z"
        ]
        #expect(Message.fromServerPayload(payload2)?.timestamp == "2026-02-07T11:00:00Z")
    }

    @Test("Parses content object with text field")
    func contentObjectWithText() {
        let payload: [String: Any] = [
            "id": "msg-7",
            "role": "assistant",
            "content": ["text": "Object text"] as [String: Any]
        ]
        let msg = Message.fromServerPayload(payload)
        #expect(msg?.content == "Object text")
    }

    @Test("Generates UUID id when no id or runId")
    func generatedId() {
        let payload: [String: Any] = [
            "role": "assistant",
            "content": "hi"
        ]
        let msg = Message.fromServerPayload(payload)
        #expect(msg?.id.hasPrefix("history-") == true)
    }
}
