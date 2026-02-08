import Foundation

// MARK: - Skill List ViewModel

@Observable
final class SkillListViewModel {
    // MARK: - State

    var skills: [Skill] = []
    var isLoading = false
    var errorMessage: String?
    var hasLoadedOnce = false
    var searchText = ""
    var isInstalling = false

    // MARK: - Private

    private let client: OpenClawClient

    // MARK: - Init

    init(client: OpenClawClient) {
        self.client = client
    }

    // MARK: - Computed

    var filteredSkills: [Skill] {
        guard !searchText.isEmpty else { return skills }
        let query = searchText.lowercased()
        return skills.filter { skill in
            skill.name.lowercased().contains(query)
                || (skill.description?.lowercased().contains(query) ?? false)
        }
    }

    var enabledCount: Int {
        skills.filter(\.isEnabled).count
    }

    // MARK: - Fetch

    func fetchSkills() async {
        isLoading = true
        errorMessage = nil

        do {
            let raw = try await client.sendRequestRaw(
                method: "skills.status",
                params: [:]
            )

            // Server may return array directly or { skills: [...] }
            let skillsArray: [Any]
            if let arr = raw as? [Any] {
                skillsArray = arr
            } else if let dict = raw as? [String: Any] {
                skillsArray = (dict["skills"] as? [Any])
                    ?? (dict["items"] as? [Any])
                    ?? (dict["list"] as? [Any])
                    ?? []
            } else {
                skillsArray = []
            }

            var decoded: [Skill] = []
            for item in skillsArray {
                guard let itemData = try? JSONSerialization.data(withJSONObject: item),
                      let skill = try? JSONDecoder().decode(Skill.self, from: itemData) else {
                    continue
                }
                decoded.append(skill)
            }

            skills = decoded
            hasLoadedOnce = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Toggle Enable/Disable

    func toggleSkill(_ skill: Skill) async {
        let newEnabled = !skill.isEnabled

        do {
            _ = try await client.sendRequestPayload(
                method: "skills.update",
                params: ["skillKey": skill.id, "enabled": newEnabled]
            )

            // Optimistic local update
            if let index = skills.firstIndex(where: { $0.id == skill.id }) {
                skills[index].enabled = newEnabled
            }
        } catch {
            errorMessage = "Failed to update: \(error.localizedDescription)"
        }
    }

    // MARK: - Install Dependencies

    func installSkill(_ skill: Skill, installId: String) async -> Bool {
        isInstalling = true

        do {
            _ = try await client.sendRequestPayload(
                method: "skills.install",
                params: [
                    "name": skill.name,
                    "installId": installId,
                    "timeoutMs": 60000
                ]
            )
            // Refresh skills list to update requirements/missing status
            await fetchSkills()
            isInstalling = false
            return true
        } catch {
            errorMessage = "Install failed: \(error.localizedDescription)"
            isInstalling = false
            return false
        }
    }
}
