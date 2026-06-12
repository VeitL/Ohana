import SwiftUI
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct ExecutorPickerBarTests {
    @Test func emptyHumansRenderNoPickerChrome() {
        UserDefaults.standard.removeObject(forKey: "currentActiveHumanId")

        let host = UIHostingController(rootView: ExecutorPickerBar(humans: []))
        let size = host.sizeThatFits(in: CGSize(width: 320, height: 80))

        #expect(size.width == 0)
        #expect(size.height == 0)
    }

    @Test func multipleHumansRenderPickerChrome() {
        UserDefaults.standard.removeObject(forKey: "currentActiveHumanId")

        let host = UIHostingController(
            rootView: ExecutorPickerBar(
                humans: [
                    Human(name: "Guan"),
                    Human(name: "Li")
                ],
                tint: .goYellow
            )
            .frame(width: 180)
        )
        let size = host.sizeThatFits(in: CGSize(width: 220, height: 80))

        #expect(size.width > 0)
        #expect(size.height > 0)
    }
}
