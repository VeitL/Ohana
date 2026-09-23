//
//  PlantGrowthDiaryShareSheet.swift
//  Ohana
//
//  One-shot system sharing for a growth diary generated after user intent.
//

import SwiftUI
import UIKit

struct PlantGrowthDiaryShareItem: Identifiable {
    let id = UUID()
    let markdown: String
}

struct PlantGrowthDiaryShareSheet: UIViewControllerRepresentable {
    let markdown: String

    func makeUIViewController(context _: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [markdown], applicationActivities: nil)
    }

    func updateUIViewController(_: UIActivityViewController, context _: Context) {}
}
