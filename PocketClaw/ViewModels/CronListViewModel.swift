import Foundation

// MARK: - Cron List ViewModel

@Observable
final class CronListViewModel {
    // MARK: - State

    var cronJobs: [CronJob] = []
    var isLoading = false
    var errorMessage: String?
    var hasLoadedOnce = false
    var searchText = ""

    // MARK: - Private

    private let client: OpenClawClient

    // MARK: - Init

    init(client: OpenClawClient) {
        self.client = client
    }

    // MARK: - Computed

    var filteredJobs: [CronJob] {
        guard !searchText.isEmpty else { return cronJobs }
        let query = searchText.lowercased()
        return cronJobs.filter { job in
            job.name.lowercased().contains(query)
                || job.schedule.displayExpression.lowercased().contains(query)
                || (job.payload?.message?.lowercased().contains(query) == true)
        }
    }

    var activeCount: Int {
        cronJobs.filter(\.isActive).count
    }

    // MARK: - Fetch

    func fetchCronJobs() async {
        isLoading = true
        errorMessage = nil

        do {
            let raw = try await client.sendRequestRaw(
                method: "cron.list",
                params: [:]
            )

            let jobsArray: [Any]
            if let arr = raw as? [Any] {
                jobsArray = arr
            } else if let dict = raw as? [String: Any] {
                jobsArray = (dict["cronJobs"] as? [Any])
                    ?? (dict["jobs"] as? [Any])
                    ?? (dict["cron"] as? [Any])
                    ?? (dict["items"] as? [Any])
                    ?? (dict["list"] as? [Any])
                    ?? []
            } else {
                jobsArray = []
            }

            var decoded: [CronJob] = []
            for item in jobsArray {
                guard let itemData = try? JSONSerialization.data(withJSONObject: item),
                      let job = try? JSONDecoder().decode(CronJob.self, from: itemData) else {
                    continue
                }
                decoded.append(job)
            }

            cronJobs = decoded
            hasLoadedOnce = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Toggle (Enable/Disable)

    func toggleJob(_ job: CronJob) async {
        let newEnabled = !job.enabled

        do {
            _ = try await client.sendRequestPayload(
                method: "cron.update",
                params: ["id": job.id, "enabled": newEnabled]
            )
            // Refresh from server
            await fetchCronJobs()
        } catch {
            errorMessage = "Failed to update: \(error.localizedDescription)"
        }
    }
}
