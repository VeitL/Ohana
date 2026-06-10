// Audit fixture: every marked line must trigger the named audit-smoothness-risk rule.
// The file lives under a Views/ path and is named *SnapshotBuilder.swift on purpose,
// so both the path-scoped and filename-scoped rules apply.
import SwiftData
import SwiftUI

struct SmoothnessBadFixture: View {
    @Query private var pets: [Pet] // rule: broad-query-high-frequency

    var body: some View {
        let image = UIImage(data: Data()) // rule: sync-image-decode-in-view
        let timer = Timer.publish(every: 1, on: .main, in: .common) // rule: runtime-loop-in-view
        _ = (image, timer)
        return Text("bad")
            .onAppear {
                Task { @MainActor in // rule: main-actor-aggregation
                    let descriptor = FetchDescriptor<Pet>()
                    _ = try? modelContext.fetch(descriptor) // rule: view-imperative-fetch
                }
                Task.detached { // rule: detached-task-in-view
                    print("escapes route cancellation")
                }
            }
    }
}
