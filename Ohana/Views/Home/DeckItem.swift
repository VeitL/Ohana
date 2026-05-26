//
//  DeckItem.swift
//  Ohana
//
//  Lightweight member card identity used by home wallet stacks.
//

enum DeckItem: Identifiable {
    case pet(Pet)
    case human(Human)

    var id: String {
        switch self {
        case .pet(let pet):
            return "pet-\(pet.id)"
        case .human(let human):
            return "human-\(human.id)"
        }
    }
}
