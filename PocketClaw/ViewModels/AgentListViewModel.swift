import Foundation

// MARK: - Agent List ViewModel

@Observable
final class AgentListViewModel {
    // MARK: - State

    var agents: [Agent] = []
    var isLoading = false
    var errorMessage: String?
    var hasLoadedOnce = false

    /// Client-side active agent (not server-persisted, auto-selects first agent)
    var currentAgentId: String?

    // MARK: - Detail State

    var selectedAgent: Agent?
    var agentFiles: [AgentFile] = []
    var agentWorkspace: String = ""
    var isLoadingFiles = false

    // MARK: - Private

    private let client: OpenClawClient

    // MARK: - Init

    init(client: OpenClawClient) {
        self.client = client
    }

    // MARK: - Computed

    var currentAgent: Agent? {
        agents.first { $0.id == currentAgentId }
    }

    var otherAgents: [Agent] {
        agents.filter { $0.id != currentAgentId }
    }

    // MARK: - Fetch Agents

    func fetchAgents() async {
        isLoading = true
        errorMessage = nil

        do {
            let raw = try await client.sendRequestRaw(
                method: "agents.list",
                params: [:]
            )

            // Server may return array directly, or { agents: [...] }, or { items: [...] }
            let agentsArray: [Any]
            if let arr = raw as? [Any] {
                agentsArray = arr
            } else if let dict = raw as? [String: Any] {
                agentsArray = (dict["agents"] as? [Any])
                    ?? (dict["items"] as? [Any])
                    ?? (dict["list"] as? [Any])
                    ?? []
            } else {
                agentsArray = []
            }

            // Decode agents individually
            var decoded: [Agent] = []
            for item in agentsArray {
                guard let itemData = try? JSONSerialization.data(withJSONObject: item),
                      var agent = try? JSONDecoder().decode(Agent.self, from: itemData) else {
                    continue
                }
                // Default to "online" when server doesn't provide status (matches ClawControl)
                if agent.status == nil {
                    agent.status = "online"
                }
                decoded.append(agent)
            }

            agents = decoded
            hasLoadedOnce = true

            // Auto-select first agent if none selected
            if currentAgentId == nil, let first = agents.first {
                currentAgentId = first.id
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Set Active Agent

    func setActiveAgent(_ agent: Agent) {
        currentAgentId = agent.id
    }

    // MARK: - Load Agent Detail (files)

    func loadAgentDetail(_ agent: Agent) async {
        selectedAgent = agent
        agentFiles = []
        agentWorkspace = ""
        isLoadingFiles = true

        do {
            // 1. Fetch file listing
            let filesResult = try await client.sendRequestPayload(
                method: "agents.files.list",
                params: ["agentId": agent.id]
            )

            agentWorkspace = (filesResult["workspace"] as? String) ?? ""

            let filesArray = (filesResult["files"] as? [[String: Any]]) ?? []
            var files: [AgentFile] = []

            for fileDict in filesArray {
                guard let fileData = try? JSONSerialization.data(withJSONObject: fileDict),
                      var file = try? JSONDecoder().decode(AgentFile.self, from: fileData) else {
                    continue
                }

                // 2. For non-missing files, fetch content
                if !file.isMissing {
                    if let content = await loadFileContent(agentId: agent.id, fileName: file.name) {
                        file.content = content
                    }
                }

                files.append(file)
            }

            agentFiles = files
        } catch {
            errorMessage = "Failed to load files: \(error.localizedDescription)"
        }

        isLoadingFiles = false
    }

    // MARK: - Load Single File Content

    private func loadFileContent(agentId: String, fileName: String) async -> String? {
        do {
            let result = try await client.sendRequestPayload(
                method: "agents.files.get",
                params: ["agentId": agentId, "name": fileName]
            )
            // Server may wrap in { file: { content, missing } } or return directly
            if let fileDict = result["file"] as? [String: Any] {
                return fileDict["content"] as? String
            }
            return result["content"] as? String
        } catch {
            return nil
        }
    }

    // MARK: - Save File

    func saveFile(agentId: String, fileName: String, content: String) async -> Bool {
        do {
            _ = try await client.sendRequestPayload(
                method: "agents.files.set",
                params: ["agentId": agentId, "name": fileName, "content": content]
            )

            // Update local state
            if let index = agentFiles.firstIndex(where: { $0.name == fileName }) {
                agentFiles[index].content = content
            }

            // Refresh agents list — editing IDENTITY.md can change name/emoji/avatar
            await fetchAgents()

            return true
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Refresh Files

    func refreshFiles() async {
        guard let agent = selectedAgent else { return }
        await loadAgentDetail(agent)
    }
}
