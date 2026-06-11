//
//  PetSpeciesKey.swift
//  Ohana
//
//  Stable species keys for business matching without depending on localized display text.
//

import Foundation

enum PetSpeciesKey {
    static func normalized(_ value: String) -> String {
        let raw = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = raw.lowercased()
        guard !text.isEmpty else { return "" }

        if containsAny(text, ["龙猫", "chinchilla"]) { return "chinchilla" }
        if containsAny(text, ["豚鼠", "guinea pig", "guineapig"]) { return "guinea_pig" }
        if containsAny(text, ["仓鼠", "hamster"]) { return "hamster" }
        if containsAny(text, ["兔", "rabbit", "bunny"]) { return "rabbit" }
        if containsAny(text, ["乌龟", "水龟", "龟", "turtle", "tortoise"]) { return "turtle" }
        if containsAny(text, ["守宫", "gecko"]) { return "gecko" }
        if containsAny(text, ["蜥", "lizard"]) { return "lizard" }
        if containsAny(text, ["蛇", "snake"]) { return "snake" }
        if containsAny(text, ["猫", "cat"]) { return "cat" }
        if containsAny(text, ["狗", "犬", "dog"]) { return "dog" }
        if containsAny(text, ["金鱼", "锦鲤", "鱼", "fish", "koi", "aquarium"]) { return "fish" }
        if containsAny(text, ["鹦鹉", "文鸟", "鸟", "bird", "parrot"]) { return "bird" }

        return text
    }

    private static func containsAny(_ text: String, _ tokens: [String]) -> Bool {
        tokens.contains { text.contains($0) }
    }
}
