import CoreGraphics
import Testing
@testable import Ohana

struct VerticalSolidHomePlantRoomStackLayoutTests {
    @Test func roomStackGridFitsTwoColumnsAcrossPhoneWidths() {
        #expect(VerticalSolidHomePlantRoomStackLayout.gridCellWidth(containerWidth: 320) == 139)
        #expect(VerticalSolidHomePlantRoomStackLayout.gridCellWidth(containerWidth: 390) == 174)
        #expect(VerticalSolidHomePlantRoomStackLayout.cardWidth(containerWidth: 139) == 104)
        #expect(VerticalSolidHomePlantRoomStackLayout.cardWidth(containerWidth: 174) == 132)
        #expect(VerticalSolidHomePlantRoomStackLayout.cardWidth(containerWidth: 356) == 132)

        let fourStackHeight = VerticalSolidHomePlantRoomStackLayout.fourStackGridHeight(
            containerWidth: 390
        )
        #expect(abs(fourStackHeight - 479.12) < 0.001)
    }

    @Test func roomStackFansRealCardsAroundTheFrontCard() {
        let front = VerticalSolidHomePlantRoomStackLayout.transform(position: 0)
        let left = VerticalSolidHomePlantRoomStackLayout.transform(position: 1)
        let right = VerticalSolidHomePlantRoomStackLayout.transform(position: 2)
        let upperLeft = VerticalSolidHomePlantRoomStackLayout.transform(position: 3)
        let upperRight = VerticalSolidHomePlantRoomStackLayout.transform(position: 4)

        #expect(front.xOffset == 0)
        #expect(front.rotationDegrees == 0)
        #expect(front.scale == 1)
        #expect(left.xOffset < 0 && left.rotationDegrees < 0)
        #expect(right.xOffset > 0 && right.rotationDegrees > 0)
        #expect(upperLeft.yOffset < 0 && upperLeft.rotationDegrees < 0)
        #expect(upperRight.yOffset < 0 && upperRight.rotationDegrees > 0)
        #expect(VerticalSolidHomePlantRoomStackLayout.maxVisibleCards == 5)
    }

    @Test func roomStackHeightIncludesSpaceForTheFannedEdges() {
        let width = VerticalSolidHomePlantRoomStackLayout.cardWidth(containerWidth: 380)
        let cardHeight = width * FocusHomeVerticalSolidCollapsedLayoutPolicy.cardAspectRatio
        let stackHeight = VerticalSolidHomePlantRoomStackLayout.stackHeight(containerWidth: 380)

        #expect(stackHeight == cardHeight + VerticalSolidHomePlantRoomStackLayout.verticalOverflowAllowance)
        #expect(stackHeight > cardHeight)
    }

    @Test func allExpandedGridUsesCompactResponsiveColumns() {
        #expect(VerticalSolidHomePlantExpandedGridLayout.columnCount(containerWidth: 340) == 3)
        #expect(VerticalSolidHomePlantExpandedGridLayout.columnCount(containerWidth: 390) == 4)
        #expect(VerticalSolidHomePlantExpandedGridLayout.columnCount(containerWidth: 500) == 5)
        #expect(VerticalSolidHomePlantExpandedGridLayout.columnCount(containerWidth: 600) == 6)
        #expect(VerticalSolidHomePlantExpandedGridLayout.columnCount(containerWidth: 744) == 7)
        #expect(abs(VerticalSolidHomePlantExpandedGridLayout.cardWidth(containerWidth: 390) - 87) < 0.001)
    }

    @Test func selectedRoomReservesHeaderSpaceForTheAdaptiveCardLayout() {
        #expect(
            VerticalSolidHomePlantWalletScrollPolicy.selectedRoomCardViewportHeight(
                containerHeight: 798,
                bottomChromeHeight: 104
            ) == 630
        )
        #expect(
            VerticalSolidHomePlantWalletScrollPolicy.selectedRoomCardViewportHeight(
                containerHeight: 480,
                bottomChromeHeight: 104
            ) == VerticalSolidHomePlantWalletScrollPolicy.minimumSceneHeight
        )
    }
}
