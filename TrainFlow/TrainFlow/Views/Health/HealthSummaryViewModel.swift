import Foundation
import SwiftUI

struct HealthSummaryData: Codable {
    let overallScore: Int?
    let overallSummary: String?
    let vitals: String?
    let sleep: String?
    let activity: String?
    let keyRecommendation: String?
    let generatedAt: String?
}

@MainActor
final class HealthSummaryViewModel: ObservableObject {
    @Published var summary: HealthSummaryData?
    @Published var isLoading = false
    @Published var overallScore: Int = 0

    private let cacheKey = "tf_health_summary_cache"
    private let cacheDateKey = "tf_health_summary_date"

    var vitals: String? { summary?.vitals }
    var sleep: String? { summary?.sleep }
    var activity: String? { summary?.activity }

    func load() async {
        let today = ISO8601DateFormatter().string(from: Date()).prefix(10)
        if let cached = UserDefaults.standard.string(forKey: cacheDateKey),
           cached == today,
           let data = UserDefaults.standard.data(forKey: cacheKey),
           let decoded = try? JSONDecoder().decode(HealthSummaryData.self, from: data) {
            summary = decoded
            overallScore = decoded.overallScore ?? 0
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            struct Wrapper: Decodable { let summary: HealthSummaryData }
            let wrapper: Wrapper = try await APIClient.shared.get("/health/ai-summary")
            summary = wrapper.summary
            overallScore = wrapper.summary.overallScore ?? 0
            if let encoded = try? JSONEncoder().encode(wrapper.summary) {
                UserDefaults.standard.set(encoded, forKey: cacheKey)
                UserDefaults.standard.set(String(today), forKey: cacheDateKey)
            }
        } catch {
            NSLog("[HealthSummaryVM] Failed to load summary: %@", error.localizedDescription)
        }
    }

    func refresh() async {
        UserDefaults.standard.removeObject(forKey: cacheDateKey)
        await load()
    }
}
