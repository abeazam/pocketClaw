import Foundation

// MARK: - Demo Data

/// Static demo data for Apple App Review and showcasing features without a real server.
enum DemoData {

    // MARK: - Sessions

    static let sessions: [[String: Any]] = [
        [
            "key": "agent:main:main",
            "label": "Main Session",
            "kind": "direct",
            "updatedAt": iso(.hoursAgo(1)),
            "lastMessagePreview": "I can help you with coding, writing, research, and more."
        ],
        [
            "key": "agent:main:session-1770600000000",
            "label": "SwiftUI Layout Help",
            "kind": "direct",
            "channel": "webchat",
            "updatedAt": iso(.hoursAgo(2)),
            "lastMessagePreview": "Use a LazyVGrid with adaptive columns for that layout."
        ],
        [
            "key": "agent:main:session-1770500000000",
            "label": "Trip Planning",
            "kind": "direct",
            "channel": "webchat",
            "updatedAt": iso(.hoursAgo(5)),
            "lastMessagePreview": "Here's a 3-day itinerary for Tokyo..."
        ],
        [
            "key": "agent:main:session-1770400000000",
            "label": "Recipe Ideas",
            "kind": "direct",
            "channel": "webchat",
            "updatedAt": iso(.daysAgo(1)),
            "lastMessagePreview": "For a quick weeknight dinner, try this pasta..."
        ],
        [
            "key": "agent:main:telegram:direct:demo-user",
            "label": "Alex",
            "kind": "direct",
            "channel": "telegram",
            "chatType": "direct",
            "updatedAt": iso(.hoursAgo(3)),
            "lastMessagePreview": "Thanks for the reminder!"
        ],
        [
            "key": "agent:main:cron:demo-cron-1",
            "label": "Cron: daily-standup",
            "kind": "direct",
            "updatedAt": iso(.hoursAgo(6)),
            "lastMessagePreview": "Good morning! Here's your daily briefing..."
        ]
    ]

    // MARK: - Messages per Session

    static let messagesBySession: [String: [[String: Any]]] = [
        "agent:main:main": [
            msg(role: "user", text: "What can you help me with?", ago: .minutesAgo(5)),
            msg(role: "assistant", text: "I can help you with a wide range of tasks:\n\n- **Writing & editing** — emails, documents, creative writing\n- **Coding** — debugging, code review, architecture advice\n- **Research** — summarizing topics, comparing options\n- **Planning** — trip itineraries, project plans, meal prep\n- **Analysis** — data interpretation, pros/cons lists\n\nJust ask me anything and I'll do my best to help!", ago: .minutesAgo(4)),
            msg(role: "user", text: "Can you help me write a Python script to rename files?", ago: .minutesAgo(2)),
            msg(role: "assistant", text: "Sure! Here's a Python script that batch renames files in a directory:\n\n```python\nimport os\nimport sys\n\ndef rename_files(directory, prefix):\n    for i, filename in enumerate(sorted(os.listdir(directory))):\n        ext = os.path.splitext(filename)[1]\n        new_name = f\"{prefix}_{i+1:03d}{ext}\"\n        old_path = os.path.join(directory, filename)\n        new_path = os.path.join(directory, new_name)\n        os.rename(old_path, new_path)\n        print(f\"Renamed: {filename} -> {new_name}\")\n\nif __name__ == \"__main__\":\n    rename_files(sys.argv[1], sys.argv[2])\n```\n\nUsage: `python rename.py /path/to/files photo`\n\nThis will rename files to `photo_001.jpg`, `photo_002.jpg`, etc.", ago: .minutesAgo(1))
        ],
        "agent:main:session-1770600000000": [
            msg(role: "user", text: "How do I create a two-column layout in SwiftUI that adapts to screen size?", ago: .hoursAgo(2)),
            msg(role: "assistant", text: "Use `LazyVGrid` with `GridItem(.adaptive)` for a responsive layout:\n\n```swift\nlet columns = [\n    GridItem(.adaptive(minimum: 160))\n]\n\nLazyVGrid(columns: columns, spacing: 16) {\n    ForEach(items) { item in\n        CardView(item: item)\n    }\n}\n```\n\nThis automatically adjusts the number of columns based on available width. On iPhone you'll get 2 columns, on iPad you might get 3-4.\n\nFor a fixed two-column layout, use:\n```swift\nlet columns = Array(repeating: GridItem(.flexible()), count: 2)\n```", ago: .hoursAgo(2))
        ],
        "agent:main:session-1770500000000": [
            msg(role: "user", text: "Plan a 3-day trip to Tokyo for me", ago: .hoursAgo(5)),
            msg(role: "assistant", text: "Here's a 3-day Tokyo itinerary:\n\n**Day 1 — Classic Tokyo**\n- Morning: Senso-ji Temple in Asakusa\n- Lunch: Ramen at Ichiran (Shibuya)\n- Afternoon: Meiji Shrine & Harajuku\n- Evening: Shibuya Crossing & dinner in Shinjuku\n\n**Day 2 — Culture & Tech**\n- Morning: Tsukiji Outer Market (sushi breakfast)\n- Afternoon: Akihabara for electronics & anime\n- Evening: TeamLab Borderless\n\n**Day 3 — Day Trip**\n- Full day: Hakone (hot springs, Mt. Fuji views)\n- Or: Kamakura (Great Buddha, coastal temples)\n\n**Tips:** Get a Suica/Pasmo card for trains. The JR Pass covers the Shinkansen to Hakone. Book TeamLab tickets in advance — they sell out!", ago: .hoursAgo(5))
        ],
        "agent:main:session-1770400000000": [
            msg(role: "user", text: "What's a quick weeknight dinner I can make in 20 minutes?", ago: .daysAgo(1)),
            msg(role: "assistant", text: "Try this **Garlic Butter Shrimp Pasta**:\n\n**Ingredients:**\n- 200g spaghetti\n- 300g shrimp, peeled\n- 4 cloves garlic, minced\n- 2 tbsp butter\n- Juice of 1 lemon\n- Red pepper flakes, parsley, salt\n\n**Steps:**\n1. Cook pasta per package directions\n2. Melt butter in a pan, sauté garlic 30 seconds\n3. Add shrimp, cook 2-3 min per side\n4. Toss in pasta, lemon juice, pepper flakes\n5. Garnish with parsley\n\nDone in 15 minutes, feeds 2. Pair with a simple side salad.", ago: .daysAgo(1))
        ],
        "agent:main:telegram:direct:demo-user": [
            msg(role: "user", text: "Remind me to pick up groceries at 5pm", ago: .hoursAgo(4)),
            msg(role: "assistant", text: "I'll remind you at 5:00 PM today to pick up groceries.", ago: .hoursAgo(4)),
            msg(role: "assistant", text: "Hey! It's 5:00 PM — time to pick up groceries.", ago: .hoursAgo(3)),
            msg(role: "user", text: "Thanks for the reminder!", ago: .hoursAgo(3))
        ],
        "agent:main:cron:demo-cron-1": [
            msg(role: "assistant", text: "Good morning! Here's your daily briefing:\n\n**Weather:** 18°C, partly cloudy\n**Calendar:** Team standup at 10:00 AM, dentist at 2:30 PM\n**News:** Apple announces new developer tools at WWDC", ago: .hoursAgo(6))
        ]
    ]

    // MARK: - Agents

    static let agents: [[String: Any]] = [
        [
            "id": "main",
            "identity": [
                "name": "Claude",
                "emoji": "🤖",
                "description": "A helpful AI assistant that can help with coding, writing, research, and more."
            ] as [String: Any],
            "status": "online"
        ],
        [
            "id": "mini",
            "identity": [
                "name": "Mini",
                "emoji": "⚡",
                "description": "A lightweight assistant optimized for quick tasks and brief responses."
            ] as [String: Any],
            "status": "online"
        ]
    ]

    // MARK: - Skills

    static let skills: [[String: Any]] = [
        ["skillKey": "web-search", "name": "Web Search", "description": "Search the web for current information", "disabled": false],
        ["skillKey": "code-interpreter", "name": "Code Interpreter", "description": "Execute Python code and analyze data", "disabled": false],
        ["skillKey": "image-gen", "name": "Image Generation", "description": "Generate images from text descriptions", "disabled": true],
        ["skillKey": "file-reader", "name": "File Reader", "description": "Read and analyze uploaded files", "disabled": false],
        ["skillKey": "calendar", "name": "Calendar", "description": "Access and manage calendar events", "disabled": true],
        ["skillKey": "memory", "name": "Memory", "description": "Remember information across conversations", "disabled": false]
    ]

    // MARK: - Cron Jobs

    static let cronJobs: [[String: Any]] = [
        [
            "id": "demo-cron-1",
            "name": "Daily Standup",
            "schedule": ["kind": "cron", "expr": "0 9 * * 1-5", "tz": "UTC"] as [String: Any],
            "enabled": true,
            "payload": ["message": "Give me a daily briefing", "kind": "agentTurn"] as [String: Any]
        ],
        [
            "id": "demo-cron-2",
            "name": "Weekly Summary",
            "schedule": ["kind": "cron", "expr": "0 17 * * 5", "tz": "UTC"] as [String: Any],
            "enabled": true,
            "payload": ["message": "Summarize what happened this week", "kind": "agentTurn"] as [String: Any]
        ],
        [
            "id": "demo-cron-3",
            "name": "Evening Reminder",
            "schedule": ["kind": "every", "everyMs": 86400000] as [String: Any],
            "enabled": false,
            "payload": ["message": "Remind me to prepare for tomorrow", "kind": "agentTurn"] as [String: Any]
        ]
    ]

    // MARK: - Streaming Responses

    /// Canned responses for chat.send in demo mode, keyed by simple pattern matching
    static let cannedResponses: [(pattern: String, response: String)] = [
        ("hello", "Hello! I'm running in demo mode. In a real setup, I'd be connected to your OpenClaw server. Try asking me about coding, planning, or anything else!"),
        ("help", "I can help with many things! In a real setup, I'd have access to your configured skills and agents. Here's what PocketClaw can do:\n\n- **Chat** with AI agents\n- **Manage agents** and their configuration files\n- **Toggle skills** on and off\n- **Schedule cron jobs** for automated tasks\n- **Connect channels** like Telegram and Discord\n\nThis is a demo — connect to a real OpenClaw server to unlock full functionality."),
        ("code", "Here's a quick example in Swift:\n\n```swift\nfunc greet(name: String) -> String {\n    return \"Hello, \\(name)! Welcome to PocketClaw.\"\n}\n\nprint(greet(name: \"World\"))\n```\n\nIn a real setup, I could write, debug, and explain code in any language."),
        ("", "I'm running in demo mode — this is a preview of PocketClaw's interface. To use the full features, connect to your own OpenClaw server.\n\nYou can explore the tabs below to see Agents, Skills, Cron Jobs, and Settings.")
    ]

    /// Returns a canned response based on simple keyword matching
    static func responseFor(_ message: String) -> String {
        let lower = message.lowercased()
        for (pattern, response) in cannedResponses {
            if !pattern.isEmpty, lower.contains(pattern) {
                return response
            }
        }
        return cannedResponses.last!.response
    }

    // MARK: - Agent Files (for agent detail view)

    static let agentFiles: [String: [[String: Any]]] = [
        "main": [
            ["name": "system.md", "size": 1024],
            ["name": "personality.md", "size": 512]
        ],
        "mini": [
            ["name": "system.md", "size": 256]
        ]
    ]

    static let agentFileContents: [String: String] = [
        "main:system.md": "# System Prompt\n\nYou are Claude, a helpful AI assistant created by Anthropic.\nYou help users with coding, writing, research, and general tasks.\n\nBe concise, accurate, and friendly.",
        "main:personality.md": "# Personality\n\n- Warm and approachable\n- Clear and concise\n- Uses code examples when helpful\n- Asks clarifying questions when needed",
        "mini:system.md": "# Mini Agent\n\nYou are a lightweight assistant optimized for quick tasks.\nKeep responses brief and to the point."
    ]

    // MARK: - Helpers

    private enum TimeOffset {
        case minutesAgo(Int)
        case hoursAgo(Int)
        case daysAgo(Int)
    }

    private static func iso(_ offset: TimeOffset) -> String {
        let date: Date
        switch offset {
        case .minutesAgo(let m): date = Date().addingTimeInterval(-Double(m * 60))
        case .hoursAgo(let h): date = Date().addingTimeInterval(-Double(h * 3600))
        case .daysAgo(let d): date = Date().addingTimeInterval(-Double(d * 86400))
        }
        return ISO8601DateFormatter().string(from: date)
    }

    private static func msg(role: String, text: String, ago: TimeOffset) -> [String: Any] {
        [
            "id": "demo-\(UUID().uuidString)",
            "role": role,
            "content": text,
            "timestamp": iso(ago)
        ]
    }
}
