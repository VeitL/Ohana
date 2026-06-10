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
        case let .pet(pet):
            "pet-\(pet.id)"
        case let .human(human):
            "human-\(human.id)"
        }
    }
}
