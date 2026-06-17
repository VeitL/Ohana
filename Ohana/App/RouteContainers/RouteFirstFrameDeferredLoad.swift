//
//  RouteFirstFrameDeferredLoad.swift
//  Ohana
//
//  A tiny route-scoped loader for new route/data containers.
//

import SwiftUI

struct RouteFirstFrameDeferredLoad<Data, Content: View>: View {
    @State private var data: Data
    @State private var loadTask: Task<Void, Never>?

    private let refreshToken: AnyHashable?
    private let loadDelayMilliseconds: UInt64
    private let reloadDelayMilliseconds: UInt64
    private let shouldLoad: (Data) -> Bool
    private let load: @MainActor () -> Data
    private let content: (Data) -> Content

    init(
        initialData: Data,
        refreshToken: AnyHashable? = nil,
        loadDelayMilliseconds: UInt64 = 120,
        reloadDelayMilliseconds: UInt64 = 120,
        shouldLoad: @escaping (Data) -> Bool = { _ in true },
        load: @escaping @MainActor () -> Data,
        @ViewBuilder content: @escaping (Data) -> Content
    ) {
        _data = State(initialValue: initialData)
        self.refreshToken = refreshToken
        self.loadDelayMilliseconds = loadDelayMilliseconds
        self.reloadDelayMilliseconds = reloadDelayMilliseconds
        self.shouldLoad = shouldLoad
        self.load = load
        self.content = content
    }

    var body: some View {
        content(data)
            .onAppear {
                scheduleLoad(force: false, delayMilliseconds: loadDelayMilliseconds)
            }
            .onChange(of: refreshToken) { _, _ in
                scheduleLoad(force: true, delayMilliseconds: reloadDelayMilliseconds)
            }
            .onDisappear {
                cancelLoad()
            }
    }

    @MainActor
    private func scheduleLoad(force: Bool, delayMilliseconds: UInt64) {
        guard force || shouldLoad(data) else { return }
        guard loadTask == nil else { return }
        loadTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delayMilliseconds) {
            data = load()
            loadTask = nil
        }
    }

    @MainActor
    private func cancelLoad() {
        loadTask?.cancel()
        loadTask = nil
    }
}

struct RouteFirstFrameDeferredMount<Placeholder: View, Content: View>: View {
    @State private var isMounted = false
    @State private var mountTask: Task<Void, Never>?

    private let delayMilliseconds: UInt64
    private let placeholder: () -> Placeholder
    private let content: () -> Content

    init(
        delayMilliseconds: UInt64 = 96,
        @ViewBuilder placeholder: @escaping () -> Placeholder,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.delayMilliseconds = delayMilliseconds
        self.placeholder = placeholder
        self.content = content
    }

    var body: some View {
        Group {
            if isMounted {
                content()
            } else {
                placeholder()
            }
        }
        .onAppear {
            scheduleMount()
        }
        .onDisappear {
            mountTask?.cancel()
            mountTask = nil
        }
    }

    @MainActor
    private func scheduleMount() {
        guard !isMounted, mountTask == nil else { return }
        mountTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delayMilliseconds) {
            isMounted = true
            mountTask = nil
        }
    }
}
