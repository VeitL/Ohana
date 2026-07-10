//
//  WalkMapSnapshotWork.swift
//  Ohana
//
//  Bounded, cancellable derived-map rendering for completed walks.
//

import Foundation
import MapKit
import SwiftData
import UIKit

nonisolated struct WalkMapSnapshotPoint: Equatable, Sendable {
    let latitude: Double
    let longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    init(_ location: CLLocation) {
        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

nonisolated struct WalkMapSnapshotMarker: Equatable, Sendable {
    let latitude: Double
    let longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    init?(marker: WalkPoopMarker) {
        guard let latitude = marker.latitude, let longitude = marker.longitude else { return nil }
        self.latitude = latitude
        self.longitude = longitude
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

nonisolated enum WalkMapSnapshotQuality: Equatable, Sendable {
    case standard
    case reduced

    var maximumRoutePointCount: Int {
        switch self {
        case .standard: 240
        case .reduced: 64
        }
    }

    var maximumMarkerCount: Int {
        switch self {
        case .standard: 24
        case .reduced: 8
        }
    }

    var imageSize: CGSize {
        switch self {
        case .standard: CGSize(width: 400, height: 300)
        case .reduced: CGSize(width: 280, height: 210)
        }
    }

    var compressionQuality: CGFloat {
        switch self {
        case .standard: 0.7
        case .reduced: 0.55
        }
    }
}

nonisolated struct WalkMapSnapshotRequest: Sendable {
    let walkLogIDs: [UUID]
    let route: [WalkMapSnapshotPoint]
    let poopMarkers: [WalkMapSnapshotMarker]
    let routeCursorStride: Int
    let poopMarkerCursorStride: Int
    let quality: WalkMapSnapshotQuality
    let isRainbowRoute: Bool
    let isRainbowPoop: Bool
}

/// Keeps a map image within a finite point budget while retaining both route
/// endpoints. `routeCursorStride` is persisted in the request for
/// observability, so dense 30–60 minute walks never turn into an unbounded map
/// render.
nonisolated enum WalkMapSnapshotPointCursor {
    static func sample(
        locations: [CLLocation],
        maximumPointCount: Int
    ) -> (points: [WalkMapSnapshotPoint], stride: Int) {
        let maximumPointCount = max(2, maximumPointCount)
        guard locations.count > maximumPointCount else {
            return (locations.map(WalkMapSnapshotPoint.init), 1)
        }

        let stride = max(1, Int(ceil(Double(locations.count - 1) / Double(maximumPointCount - 1))))
        var points: [WalkMapSnapshotPoint] = []
        points.reserveCapacity(maximumPointCount)
        var cursor = 0
        while cursor < locations.count {
            points.append(WalkMapSnapshotPoint(locations[cursor]))
            cursor += stride
        }
        if let lastLocation = locations.last {
            let lastPoint = WalkMapSnapshotPoint(lastLocation)
            if points.last != lastPoint {
                points.append(lastPoint)
            }
        }
        return (points, stride)
    }
}

/// Keeps repeated potty markers from turning the snapshot overlay into an
/// unbounded draw loop. Like the route cursor, it preserves the first and last
/// marker so a long walk retains its visual time range.
nonisolated enum WalkMapSnapshotMarkerCursor {
    static func sample(
        markers: [WalkMapSnapshotMarker],
        maximumMarkerCount: Int
    ) -> (markers: [WalkMapSnapshotMarker], stride: Int) {
        let maximumMarkerCount = max(2, maximumMarkerCount)
        guard markers.count > maximumMarkerCount else {
            return (markers, 1)
        }

        let stride = max(1, Int(ceil(Double(markers.count - 1) / Double(maximumMarkerCount - 1))))
        var sampledMarkers: [WalkMapSnapshotMarker] = []
        sampledMarkers.reserveCapacity(maximumMarkerCount)
        var cursor = 0
        while cursor < markers.count {
            sampledMarkers.append(markers[cursor])
            cursor += stride
        }
        if let lastMarker = markers.last, sampledMarkers.last != lastMarker {
            sampledMarkers.append(lastMarker)
        }
        return (sampledMarkers, stride)
    }
}

@ModelActor
actor WalkMapSnapshotPersistenceActor {
    func persist(jpegData: Data, to walkLogIDs: [UUID], deadline: Date) throws {
        guard !jpegData.isEmpty else { return }
        guard Date() < deadline else { throw CancellationError() }
        var didChange = false
        for walkLogID in walkLogIDs {
            try Task.checkCancellation()
            guard Date() < deadline else {
                modelContext.rollback()
                throw CancellationError()
            }
            var descriptor = FetchDescriptor<PetWalkLog>(
                predicate: #Predicate { candidate in
                    candidate.id == walkLogID
                }
            )
            descriptor.fetchLimit = 1
            guard let walkLog = try modelContext.fetch(descriptor).first else { continue }
            walkLog.mapSnapshotData = jpegData
            didChange = true
        }
        guard didChange else { return }
        try Task.checkCancellation()
        guard Date() < deadline else {
            modelContext.rollback()
            throw CancellationError()
        }
        let saveResult = modelContext.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            modelContext.rollback()
            throw WalkMapSnapshotPersistenceFailure(errorDescription: saveResult.errorDescription)
        }
    }
}

private nonisolated struct WalkMapSnapshotPersistenceFailure: LocalizedError {
    let errorDescription: String?
}

/// Coordinates cancellation and continuation resumption independently from
/// MapKit. `MKMapSnapshotter.cancel()` is best-effort and may not call its
/// completion handler, so cancellation itself must always release the task.
private final nonisolated class WalkMapSnapshotOperation: @unchecked Sendable {
    private let lock = NSLock()
    private var snapshotter: MKMapSnapshotter?
    private var continuation: CheckedContinuation<Data?, Never>?
    private var didFinish = false

    @MainActor
    func install(
        snapshotter: MKMapSnapshotter,
        continuation: CheckedContinuation<Data?, Never>
    ) {
        lock.lock()
        guard !didFinish else {
            lock.unlock()
            snapshotter.cancel()
            continuation.resume(returning: nil)
            return
        }
        self.snapshotter = snapshotter
        self.continuation = continuation
        lock.unlock()
    }

    /// May run from a task cancellation handler. It never touches MapKit;
    /// the main-actor helper below cancels the snapshotter safely.
    func cancel() {
        lock.lock()
        guard !didFinish else {
            lock.unlock()
            return
        }
        didFinish = true
        let continuation = continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(returning: nil)
    }

    var isFinished: Bool {
        lock.lock()
        defer { lock.unlock() }
        return didFinish
    }

    @MainActor
    func cancelSnapshotterIfInstalled() {
        lock.lock()
        let snapshotter = snapshotter
        self.snapshotter = nil
        lock.unlock()
        snapshotter?.cancel()
    }

    func finish(_ data: Data?) {
        lock.lock()
        guard !didFinish else {
            lock.unlock()
            return
        }
        didFinish = true
        let continuation = continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(returning: data)
    }
}

@MainActor
enum WalkMapSnapshotRenderer {
    static func render(request: WalkMapSnapshotRequest, deadline: Date) async -> Data? {
        guard request.route.count >= 2,
              !Task.isCancelled,
              Date() < deadline
        else { return nil }
        let coordinates = request.route.map(\.coordinate)
        let markerCoordinates = request.poopMarkers.map(\.coordinate)
        let regionCoordinates = coordinates + markerCoordinates
        guard let first = regionCoordinates.first else { return nil }

        let latitudes = regionCoordinates.map(\.latitude)
        let longitudes = regionCoordinates.map(\.longitude)
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (latitudes.min()! + latitudes.max()!) / 2,
                longitude: (longitudes.min()! + longitudes.max()!) / 2
            ),
            span: MKCoordinateSpan(
                latitudeDelta: max(0.005, (latitudes.max()! - latitudes.min()!) * 1.5),
                longitudeDelta: max(0.005, (longitudes.max()! - longitudes.min()!) * 1.5)
            )
        )
        _ = first // establishes a non-empty route before force-unwrapping extrema above.

        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = request.quality.imageSize
        options.mapType = .standard
        let operation = WalkMapSnapshotOperation()
        let deadlineTask = Task { @MainActor [operation, deadline] in
            let remaining = max(0, deadline.timeIntervalSinceNow)
            if remaining > 0 {
                try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            }
            guard !Task.isCancelled else { return }
            operation.cancel()
            operation.cancelSnapshotterIfInstalled()
        }

        let data = await withTaskCancellationHandler(operation: {
            await withCheckedContinuation { (continuation: CheckedContinuation<Data?, Never>) in
                guard !Task.isCancelled else {
                    continuation.resume(returning: nil)
                    return
                }
                let snapshotter = MKMapSnapshotter(options: options)
                operation.install(snapshotter: snapshotter, continuation: continuation)
                snapshotter.start(with: DispatchQueue.global(qos: .utility)) { snapshot, error in
                    Task { @MainActor in
                        guard !operation.isFinished, Date() < deadline else {
                            operation.cancel()
                            operation.cancelSnapshotterIfInstalled()
                            return
                        }
                        guard let snapshot, error == nil else {
                            operation.finish(nil)
                            return
                        }

                        let image = UIGraphicsImageRenderer(size: snapshot.image.size).image { context in
                            snapshot.image.draw(at: .zero)
                            MapSnapshotRainbowRenderer.drawRoute(
                                coordinates: coordinates,
                                on: snapshot,
                                in: context.cgContext,
                                isRainbow: request.isRainbowRoute,
                                lineWidth: request.quality == .standard ? 3 : 2
                            )

                            let startPoint = snapshot.point(for: coordinates[0])
                            UIColor.green.setFill()
                            UIBezierPath(arcCenter: startPoint, radius: request.quality == .standard ? 5 : 4, startAngle: 0, endAngle: .pi * 2, clockwise: true).fill()

                            let endPoint = snapshot.point(for: coordinates[coordinates.count - 1])
                            UIColor.blue.setFill()
                            UIBezierPath(arcCenter: endPoint, radius: request.quality == .standard ? 6 : 5, startAngle: 0, endAngle: .pi * 2, clockwise: true).fill()

                            for marker in markerCoordinates {
                                MapSnapshotRainbowRenderer.drawPoopMarker(
                                    at: snapshot.point(for: marker),
                                    in: context.cgContext,
                                    isRainbow: request.isRainbowPoop
                                )
                            }
                        }
                        guard !operation.isFinished, Date() < deadline else {
                            operation.cancel()
                            operation.cancelSnapshotterIfInstalled()
                            return
                        }
                        operation.finish(image.jpegData(compressionQuality: request.quality.compressionQuality))
                    }
                }
            }
        }, onCancel: {
            operation.cancel()
            Task { @MainActor in
                operation.cancelSnapshotterIfInstalled()
            }
        })
        deadlineTask.cancel()
        return data
    }
}
