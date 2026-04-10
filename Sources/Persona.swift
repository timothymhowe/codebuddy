import SwiftUI

// MARK: - Rarity

enum Rarity: Int, CaseIterable, Comparable, Hashable {
    case common = 3
    case uncommon = 4
    case rare = 5
    case epic = 6
    case legendary = 7

    var stars: Int { rawValue }

    var label: String {
        switch self {
        case .common:    return "Common"
        case .uncommon:  return "Uncommon"
        case .rare:      return "Rare"
        case .epic:      return "Epic"
        case .legendary: return "Legendary"
        }
    }

    var color: Color {
        switch self {
        case .common:    return Color(red: 0.6, green: 0.6, blue: 0.6)
        case .uncommon:  return Color(red: 0.3, green: 0.8, blue: 0.4)
        case .rare:      return Color(red: 0.3, green: 0.5, blue: 1.0)
        case .epic:      return Color(red: 0.7, green: 0.3, blue: 0.9)
        case .legendary: return Color(red: 1.0, green: 0.8, blue: 0.2)
        }
    }

    static func < (lhs: Rarity, rhs: Rarity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Ability

enum PersonaAbility: String {
    case chill, pixelate, trickster, drift, frost
    case cunning, rage, bloom, eclipse, storm, loyal

    var label: String {
        switch self {
        case .chill:     return "Chill"
        case .pixelate:  return "Pixelate"
        case .trickster: return "Trickster"
        case .drift:     return "Drift"
        case .frost:     return "Frost"
        case .cunning:   return "Cunning"
        case .rage:      return "Rage"
        case .bloom:     return "Bloom"
        case .eclipse:   return "Eclipse"
        case .storm:     return "Storm"
        case .loyal:     return "Loyal"
        }
    }

    var desc: String {
        switch self {
        case .chill:     return "Gentle, calming presence"
        case .pixelate:  return "Retro 8-bit energy"
        case .trickster: return "Mischievous shape-shifting"
        case .drift:     return "Floats like a cloud"
        case .frost:     return "Emanates ice crystals"
        case .cunning:   return "Watchful fox eyes"
        case .rage:      return "Burns with fiery passion"
        case .bloom:     return "Cherry blossoms trail behind"
        case .eclipse:   return "Cosmic moonlight aura"
        case .storm:     return "Crackles with lightning"
        case .loyal:     return "Unconditional love and snoring"
        }
    }
}

// MARK: - Visual types

enum ParticleType {
    case snowflake, petal, star, spark, flame
}

enum AccessoryType {
    case catEars(Color)
    case foxEars(Color)
    case horns(Color)
    case halo(Color)
    case crown(Color)
    case bow(Color)
}

enum EyeStyle {
    case round
    case narrow
    case dot
    case sharp
    case sparkle
}

// MARK: - Persona

struct Persona: Identifiable {
    let id: String
    let name: String
    let subtitle: String
    let rarity: Rarity
    let lore: String
    let ability: PersonaAbility
    let bodyColor: Color
    let bodyHighlight: Color
    let accessories: [AccessoryType]
    let particleType: ParticleType?
    let eyeStyle: EyeStyle
    let bounceSpeed: Double
    let phrases: [BuddyActivity: [String]]

    static func find(_ id: String) -> Persona {
        all.first { $0.id == id } ?? all[0]
    }

    func randomPhrase(for activity: BuddyActivity) -> String? {
        phrases[activity]?.randomElement()
    }

    /// Derived eye color per persona (AC-style colorful iris)
    var eyeColor: Color {
        switch id {
        case "mochi":     return Color(red: 0.35, green: 0.22, blue: 0.12)
        case "pixel":     return Color(red: 0.1, green: 0.7, blue: 0.2)
        case "tanuki":    return Color(red: 0.6, green: 0.4, blue: 0.1)
        case "kumo":      return Color(red: 0.4, green: 0.6, blue: 0.85)
        case "yuki":      return Color(red: 0.5, green: 0.78, blue: 0.95)
        case "kitsune":   return Color(red: 0.8, green: 0.55, blue: 0.1)
        case "oni":       return Color(red: 0.8, green: 0.12, blue: 0.1)
        case "sakura":    return Color(red: 0.85, green: 0.35, blue: 0.5)
        case "tsukuyomi": return Color(red: 0.5, green: 0.28, blue: 0.82)
        case "raijin":    return Color(red: 0.15, green: 0.4, blue: 0.92)
        case "frenchie":  return Color(red: 0.2, green: 0.12, blue: 0.06)
        case "chubby":    return Color(red: 0.18, green: 0.1, blue: 0.05)
        default:          return Color(red: 0.3, green: 0.2, blue: 0.15)
        }
    }

    /// Derived hair color per persona
    var hairColor: Color {
        switch id {
        case "mochi":     return Color(red: 0.12, green: 0.08, blue: 0.06)
        case "pixel":     return Color(red: 0.08, green: 0.45, blue: 0.12)
        case "tanuki":    return Color(red: 0.25, green: 0.18, blue: 0.12)
        case "kumo":      return Color(red: 0.7, green: 0.75, blue: 0.85)
        case "yuki":      return Color(red: 0.75, green: 0.85, blue: 0.95)
        case "kitsune":   return Color(red: 0.55, green: 0.3, blue: 0.08)
        case "oni":       return Color(red: 0.08, green: 0.05, blue: 0.05)
        case "sakura":    return Color(red: 0.5, green: 0.15, blue: 0.25)
        case "tsukuyomi": return Color(red: 0.2, green: 0.12, blue: 0.4)
        case "raijin":    return Color(red: 0.06, green: 0.08, blue: 0.3)
        case "frenchie":  return Color(red: 0.45, green: 0.35, blue: 0.25)
        case "chubby":    return Color(red: 0.5, green: 0.38, blue: 0.25)
        default:          return Color(red: 0.1, green: 0.08, blue: 0.06)
        }
    }

    // MARK: - All Personas

    static let all: [Persona] = [

        Persona(
            id: "chubby", name: "Oki Shiba", subtitle: "おきしば",
            rarity: .rare,
            lore: "A round, chubby shiba who radiates pure love. Too fat to debug. Doesn't care.",
            ability: .loyal,
            bodyColor: Color(red: 0.88, green: 0.78, blue: 0.62),
            bodyHighlight: Color(red: 0.95, green: 0.88, blue: 0.72),
            accessories: [.catEars(Color(red: 0.5, green: 0.35, blue: 0.22))],
            particleType: nil,
            eyeStyle: .dot,
            bounceSpeed: 0.65,
            phrases: [
                .idle: ["*snoring*", "...", "*heavy breathing*", "woof."],
                .thinking: ["*head tilt*", "...hm?", "*sniff sniff*", "??"],
                .coding: ["*watches intently*", "good boy code", "*tail wag*", "bork"],
                .running: ["BORK BORK!", "zoomies!!", "*panting*", "WOOF!"],
                .error: ["*whimper*", "ruh roh", "*sad eyes*", "...woof"],
                .success: ["*happy snorts*", "BORK!", "*butt wiggles*", "good code! treat?"],
            ]
        ),
    ]
}

// Full persona roster is on feature/all-personas branch
