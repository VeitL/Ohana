// Audit fixture: snapshot-consuming view; audit-smoothness-risk must report zero warnings.
import SwiftUI

struct SmoothnessGoodFixture: View {
    let snapshot: [String]

    var body: some View {
        VStack {
            ForEach(snapshot, id: \.self) { line in
                Text(line)
            }
        }
        .task(id: snapshot.count) {
            // Route-scoped, cancellable refresh entry point.
        }
    }
}
