import Testing
import Foundation
@testable import PocketClaw

// MARK: - Session Decoding Tests

@Suite("Session Decoding")
struct SessionDecodingTests {
    @Test("Decodes basic session")
    func basicSession() throws {
        let json = """
        {"key": "agent:main:session-123", "title": "Test Chat", "createdAt": "2026-02-07T10:00:00Z", "updatedAt": "2026-02-07T11:00:00Z"}
        """
        let session = try JSONDecoder().decode(Session.self, from: Data(json.utf8))
        #expect(session.key == "agent:main:session-123")
        #expect(session.title == "Test Chat")
    }

    @Test("Label takes precedence over title and derivedTitle")
    func labelPrecedence() throws {
        let json = """
        {"key": "s1", "label": "My Label", "title": "Server Title", "derivedTitle": "AI Title"}
        """
        let session = try JSONDecoder().decode(Session.self, from: Data(json.utf8))
        #expect(session.title == "My Label")
    }

    @Test("Falls back to derivedTitle when no label or title")
    func derivedTitleFallback() throws {
        let json = """
        {"key": "s2", "derivedTitle": "AI Generated Title"}
        """
        let session = try JSONDecoder().decode(Session.self, from: Data(json.utf8))
        #expect(session.title == "AI Generated Title")
    }

    @Test("Falls back to displayName")
    func displayNameFallback() throws {
        let json = """
        {"key": "s3", "displayName": "Display Name"}
        """
        let session = try JSONDecoder().decode(Session.self, from: Data(json.utf8))
        #expect(session.title == "Display Name")
    }

    @Test("Falls back to key when no title fields")
    func keyFallback() throws {
        let json = """
        {"key": "agent:main:session-999"}
        """
        let session = try JSONDecoder().decode(Session.self, from: Data(json.utf8))
        #expect(session.title == "agent:main:session-999")
    }
}

// MARK: - Agent Decoding Tests

@Suite("Agent Decoding")
struct AgentDecodingTests {
    @Test("Decodes agent with identity fields")
    func identityFields() throws {
        let json = """
        {"id": "main", "identity": {"name": "Claude", "emoji": "🤖", "description": "AI assistant"}}
        """
        let agent = try JSONDecoder().decode(Agent.self, from: Data(json.utf8))
        #expect(agent.id == "main")
        #expect(agent.name == "Claude")
        #expect(agent.emoji == "🤖")
    }

    @Test("Defaults status to nil when not provided")
    func noStatus() throws {
        let json = """
        {"id": "test", "identity": {"name": "Test"}}
        """
        let agent = try JSONDecoder().decode(Agent.self, from: Data(json.utf8))
        #expect(agent.status == nil)
    }

    @Test("Filters invalid emoji via displayEmoji")
    func filterBadEmoji() throws {
        let json = """
        {"id": "test", "identity": {"name": "Test", "emoji": "none"}}
        """
        let agent = try JSONDecoder().decode(Agent.self, from: Data(json.utf8))
        // Raw emoji stores "none", but displayEmoji filters it to fallback
        #expect(agent.emoji == "none")
        #expect(agent.displayEmoji == "🤖")
    }

    @Test("Decodes flat agent structure")
    func flatStructure() throws {
        let json = """
        {"id": "flat", "name": "FlatAgent", "emoji": "⚡", "status": "online"}
        """
        let agent = try JSONDecoder().decode(Agent.self, from: Data(json.utf8))
        #expect(agent.name == "FlatAgent")
        #expect(agent.status == "online")
    }
}

// MARK: - Skill Decoding Tests

@Suite("Skill Decoding")
struct SkillDecodingTests {
    @Test("Inverts disabled to enabled")
    func disabledInversion() throws {
        let json = """
        {"skillKey": "test-skill", "name": "Test", "disabled": true}
        """
        let skill = try JSONDecoder().decode(Skill.self, from: Data(json.utf8))
        #expect(skill.isEnabled == false)
    }

    @Test("Treats nil disabled as enabled")
    func nilDisabledIsEnabled() throws {
        let json = """
        {"skillKey": "test-skill", "name": "Test"}
        """
        let skill = try JSONDecoder().decode(Skill.self, from: Data(json.utf8))
        #expect(skill.isEnabled == true)
    }
}

// MARK: - CronJob Decoding Tests

@Suite("CronJob Decoding")
struct CronJobDecodingTests {
    @Test("Decodes cron schedule with expr")
    func cronSchedule() throws {
        let json = """
        {"id": "job1", "name": "Daily", "schedule": {"kind": "cron", "expr": "0 2 * * *", "tz": "UTC"}, "enabled": true}
        """
        let job = try JSONDecoder().decode(CronJob.self, from: Data(json.utf8))
        #expect(job.schedule.displayExpression == "0 2 * * *")
        #expect(job.schedule.timezone == "UTC")
        #expect(job.isActive == true)
    }

    @Test("Decodes every-interval schedule")
    func everySchedule() throws {
        let json = """
        {"id": "job2", "name": "Ticker", "schedule": {"kind": "every", "everyMs": 900000}, "enabled": true}
        """
        let job = try JSONDecoder().decode(CronJob.self, from: Data(json.utf8))
        #expect(job.schedule.displayExpression == "Every 15m")
    }

    @Test("Decodes nextRunAtMs from state object")
    func nextRunFromState() throws {
        let json = """
        {"id": "job3", "name": "Test", "schedule": {"kind": "every", "everyMs": 60000}, "enabled": true, "state": {"nextRunAtMs": 1770575654503}}
        """
        let job = try JSONDecoder().decode(CronJob.self, from: Data(json.utf8))
        #expect(job.nextRunAtMs == 1770575654503)
    }

    @Test("Decodes payload message")
    func payloadMessage() throws {
        let json = """
        {"id": "job4", "name": "Run script", "schedule": {"kind": "every", "everyMs": 60000}, "enabled": true, "payload": {"message": "Do the thing", "kind": "agentTurn"}}
        """
        let job = try JSONDecoder().decode(CronJob.self, from: Data(json.utf8))
        #expect(job.content == "Do the thing")
        #expect(job.payload?.kind == "agentTurn")
    }

    @Test("Enabled false means inactive")
    func disabledJob() throws {
        let json = """
        {"id": "job5", "name": "Paused", "schedule": {"kind": "cron", "expr": "0 0 * * *"}, "enabled": false}
        """
        let job = try JSONDecoder().decode(CronJob.self, from: Data(json.utf8))
        #expect(job.isActive == false)
    }

    @Test("Plain string schedule treated as cron")
    func plainStringSchedule() throws {
        let json = """
        {"id": "job6", "name": "Simple", "schedule": "*/5 * * * *", "enabled": true}
        """
        let job = try JSONDecoder().decode(CronJob.self, from: Data(json.utf8))
        #expect(job.schedule.displayExpression == "*/5 * * * *")
    }
}
