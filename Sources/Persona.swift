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

        // ── COMMON ★★★ ──────────────────────────────────

        Persona(
            id: "mochi", name: "Mochi", subtitle: "もち",
            rarity: .common,
            lore: "A soft, gentle blob. The first friend every coder needs. Smells faintly of rice flour.",
            ability: .chill,
            bodyColor: Color(red: 0.94, green: 0.89, blue: 0.84),
            bodyHighlight: Color(red: 1.0, green: 0.96, blue: 0.93),
            accessories: [],
            particleType: nil,
            eyeStyle: .round,
            bounceSpeed: 0.8,
            phrases: [
                .idle: ["zzz~", "so comfy...", "mochi mochi~", "( ᵕ‿ᵕ )"],
                .thinking: ["hmm~", "let me think...", "pondering...", "mmmm..."],
                .coding: ["kneading code~", "squish squish", "writing stuff!", "so focused~"],
                .running: ["go go go~", "running!", "weeee~", "zoom zoom"],
                .error: ["oh no...", "it's ok...", "we'll fix it~", "(´;ω;`)"],
                .success: ["yay~!", "we did it!", "so warm~", "✧˖°"],
            ]
        ),

        Persona(
            id: "pixel", name: "Pixel", subtitle: "ピクセル",
            rarity: .common,
            lore: "Born in an old arcade cabinet. Speaks in beeps. Dreams in 8-bit.",
            ability: .pixelate,
            bodyColor: Color(red: 0.2, green: 0.85, blue: 0.3),
            bodyHighlight: Color(red: 0.4, green: 1.0, blue: 0.5),
            accessories: [],
            particleType: nil,
            eyeStyle: .dot,
            bounceSpeed: 1.2,
            phrases: [
                .idle: ["READY P1", "INSERT COIN", "...bleep", "▓░▓░"],
                .thinking: ["LOADING...", "PROCESSING", "████░░ 67%", "COMPUTE"],
                .coding: ["WRITE.EXE", "01101001", "RENDER>>", "INPUT OK"],
                .running: ["EXECUTE!", "RUN.BAT", ">>>>>>>", "TURBO MODE"],
                .error: ["GAME OVER", "ERR 404", "FATAL!!", "CONTINUE? Y/N"],
                .success: ["HIGH SCORE!", "LEVEL UP!", "1UP!", "PERFECT!!"],
            ]
        ),

        // ── UNCOMMON ★★★★ ───────────────────────────────

        Persona(
            id: "tanuki", name: "Tanuki", subtitle: "たぬき",
            rarity: .uncommon,
            lore: "A mischievous raccoon-dog. Steals semicolons when you're not looking.",
            ability: .trickster,
            bodyColor: Color(red: 0.6, green: 0.42, blue: 0.28),
            bodyHighlight: Color(red: 0.78, green: 0.6, blue: 0.42),
            accessories: [.catEars(Color(red: 0.5, green: 0.35, blue: 0.22))],
            particleType: nil,
            eyeStyle: .narrow,
            bounceSpeed: 1.0,
            phrases: [
                .idle: ["hehe~", "what's this?", "*sniff sniff*", "( ͡° ͜ʖ ͡°)"],
                .thinking: ["plotting...", "hmm interesting", "i have a plan", "scheming~"],
                .coding: ["*steals semicolons*", "shape shift!", "sneaky code~", "kekeke"],
                .running: ["SCATTER!", "catch me!", "nininini~", "poof!"],
                .error: ["wasn't me!", "blame someone else", "oops hehe", "tactical retreat!"],
                .success: ["all according to keikaku", "told ya~", "ez pz", "tanuki wins!"],
            ]
        ),

        Persona(
            id: "kumo", name: "Kumo", subtitle: "くも",
            rarity: .uncommon,
            lore: "A wandering cloud spirit. Drifts through your code like morning fog over a temple.",
            ability: .drift,
            bodyColor: Color(red: 0.85, green: 0.9, blue: 0.98),
            bodyHighlight: Color(red: 0.95, green: 0.97, blue: 1.0),
            accessories: [],
            particleType: nil,
            eyeStyle: .round,
            bounceSpeed: 0.6,
            phrases: [
                .idle: ["drifting~", "so peaceful...", "fluffy thoughts", "☁ ☁ ☁"],
                .thinking: ["floating ideas...", "cloud computing~", "mist forming...", "hmm..."],
                .coding: ["rain of code~", "precipitation", "condensing...", "drip drip"],
                .running: ["whoooosh~", "riding the wind", "nimbus mode!", "scattered~"],
                .error: ["storm clouds...", "thunder rumbles", "dark skies...", "oh fog..."],
                .success: ["silver lining!", "clear skies~", "rainbow!", "sunshine!"],
            ]
        ),

        // ── RARE ★★★★★ ──────────────────────────────────

        Persona(
            id: "chubby", name: "Oki Shiba", subtitle: "おきしば",
            rarity: .rare,
            lore: "A round, chubby shiba who radiates pure love. Too fat to debug. Doesn't care.",
            ability: .loyal,
            bodyColor: Color(red: 0.88, green: 0.78, blue: 0.62),
            bodyHighlight: Color(red: 0.95, green: 0.88, blue: 0.72),
            accessories: [],
            particleType: nil,
            eyeStyle: .dot,
            bounceSpeed: 0.5,
            phrases: [
                .idle: ["*snoring*", "zzz...", "*belly up*", "...maru"],
                .thinking: ["*head tilt*", "hmm?", "*sniff*", "wuh?"],
                .coding: ["*watching*", "*tail wag*", "bork!", "good code"],
                .running: ["BORK!", "zoomies!!", "*panting*", "ROUND BOY GO"],
                .error: ["*whimper*", "ruh roh", "*sad eyes*", "oof"],
                .success: ["*happy snorts*", "BORK!", "*wiggles*", "treat? TREAT?"],
            ]
        ),

        Persona(
            id: "frenchie", name: "Buru", subtitle: "ブル",
            rarity: .rare,
            lore: "A stoic french bulldog. Judges your code silently. Snores during long compiles. Will die for you.",
            ability: .loyal,
            bodyColor: Color(red: 0.82, green: 0.7, blue: 0.52),
            bodyHighlight: Color(red: 0.92, green: 0.82, blue: 0.65),
            accessories: [],
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

        Persona(
            id: "yuki", name: "Yuki", subtitle: "ゆき",
            rarity: .rare,
            lore: "An ice spirit from the northern peaks. Keeps your code cool under pressure. Never panics.",
            ability: .frost,
            bodyColor: Color(red: 0.7, green: 0.85, blue: 1.0),
            bodyHighlight: Color(red: 0.88, green: 0.95, blue: 1.0),
            accessories: [],
            particleType: .snowflake,
            eyeStyle: .sparkle,
            bounceSpeed: 0.9,
            phrases: [
                .idle: ["❄ so still...", "crystalline peace", "frozen in time", "cold... nice"],
                .thinking: ["calculating frost...", "ice logic", "cooling down...", "sub-zero thoughts"],
                .coding: ["inscribing in ice", "frozen precision", "absolute zero bugs", "crisp code"],
                .running: ["blizzard mode!", "ice skating~", "avalanche!", "flash freeze!"],
                .error: ["...it shattered", "crack in the ice", "frostbite", "冷たい..."],
                .success: ["flawless crystal!", "diamond dust~", "perfectly frozen", "✧ immaculate ✧"],
            ]
        ),

        Persona(
            id: "kitsune", name: "Kitsune", subtitle: "きつね",
            rarity: .rare,
            lore: "A clever fox spirit with one tail. Sees bugs before they happen. Knows things.",
            ability: .cunning,
            bodyColor: Color(red: 0.95, green: 0.65, blue: 0.2),
            bodyHighlight: Color(red: 1.0, green: 0.82, blue: 0.4),
            accessories: [.foxEars(Color(red: 0.9, green: 0.55, blue: 0.15))],
            particleType: nil,
            eyeStyle: .narrow,
            bounceSpeed: 1.1,
            phrases: [
                .idle: ["watching...", "i see everything", "kon kon~", "*ears twitch*"],
                .thinking: ["i already know", "the fox sees all", "predictable...", "as expected"],
                .coding: ["elegant solution", "one move ahead", "calculated", "precise strike"],
                .running: ["swift as flame!", "fox fire!", "dash!", "thousand steps"],
                .error: ["...interesting", "i foresaw this", "a lesson, then", "hmph"],
                .success: ["naturally~", "was there doubt?", "kon! ✧", "too easy"],
            ]
        ),

        // ── EPIC ★★★★★★ ─────────────────────────────────

        Persona(
            id: "oni", name: "Oni", subtitle: "おに",
            rarity: .epic,
            lore: "A fearsome demon with a heart of gold. Destroys bugs with extreme prejudice. Cries at sad commits.",
            ability: .rage,
            bodyColor: Color(red: 0.85, green: 0.18, blue: 0.18),
            bodyHighlight: Color(red: 1.0, green: 0.35, blue: 0.3),
            accessories: [.horns(Color(red: 0.3, green: 0.25, blue: 0.2))],
            particleType: .flame,
            eyeStyle: .sharp,
            bounceSpeed: 1.3,
            phrases: [
                .idle: ["...", "WAITING.", "grr.", "鬼"],
                .thinking: ["ANALYZING.", "SCANNING TARGET", "FOUND WEAKNESS", "PREPARING STRIKE"],
                .coding: ["WRITING FURY.", "SMASH BUGS.", "CODE WITH RAGE", "BURN IT DOWN. REBUILD."],
                .running: ["CHAAARGE!", "RAMPAGE!", "鬼の力!", "UNSTOPPABLE"],
                .error: ["UNACCEPTABLE.", "WHO DID THIS.", "*table flip*", "(╯°□°)╯︵ ┻━┻"],
                .success: ["VICTORY.", "CRUSHED.", "none survived.", "*quiet tears*"],
            ]
        ),

        Persona(
            id: "sakura", name: "Sakura", subtitle: "さくら",
            rarity: .epic,
            lore: "The spirit of cherry blossoms. Code written in her presence compiles on the first try. Allegedly.",
            ability: .bloom,
            bodyColor: Color(red: 1.0, green: 0.7, blue: 0.78),
            bodyHighlight: Color(red: 1.0, green: 0.85, blue: 0.9),
            accessories: [.bow(Color(red: 0.95, green: 0.4, blue: 0.5))],
            particleType: .petal,
            eyeStyle: .sparkle,
            bounceSpeed: 0.85,
            phrases: [
                .idle: ["so pretty~", "petals falling...", "花見の季節", "gentle breeze~"],
                .thinking: ["blooming ideas~", "let it grow...", "seeds of thought", "budding..."],
                .coding: ["poetry in code", "each line a petal", "beautiful~", "writing haiku"],
                .running: ["petal storm!", "花吹雪!", "dancing!", "spring wind~"],
                .error: ["petals wilt...", "not yet in season", "a thorn...", "it'll bloom again"],
                .success: ["full bloom!", "満開!", "sakura shower~", "✿ gorgeous ✿"],
            ]
        ),

        // ── LEGENDARY ★★★★★★★ ───────────────────────────

        Persona(
            id: "tsukuyomi", name: "Tsukuyomi", subtitle: "月読",
            rarity: .legendary,
            lore: "The moon deity. Sees all code paths simultaneously. Time bends around their presence. Mass: undefined.",
            ability: .eclipse,
            bodyColor: Color(red: 0.35, green: 0.25, blue: 0.65),
            bodyHighlight: Color(red: 0.6, green: 0.5, blue: 0.9),
            accessories: [.halo(Color(red: 0.9, green: 0.85, blue: 1.0))],
            particleType: .star,
            eyeStyle: .sparkle,
            bounceSpeed: 0.7,
            phrases: [
                .idle: ["the moon watches.", "all paths converge", "時は流れる", "...silence speaks"],
                .thinking: ["consulting the void", "starlight whispers", "the cosmos reveals", "moonphase: waxing"],
                .coding: ["inscribing fate", "celestial runes", "the stars align", "written in moonlight"],
                .running: ["eclipse begins", "time dilates", "reality bends", "月光"],
                .error: ["a shadow passes", "even moons wane", "the void gazes back", "darkness, briefly"],
                .success: ["it was foretold.", "the moon smiles", "fate fulfilled", "✦ 月読の光 ✦"],
            ]
        ),

        Persona(
            id: "raijin", name: "Raijin", subtitle: "雷神",
            rarity: .legendary,
            lore: "God of thunder. Compiles strike like lightning. Tests never flake in their presence. Fear the drums.",
            ability: .storm,
            bodyColor: Color(red: 0.15, green: 0.35, blue: 0.75),
            bodyHighlight: Color(red: 0.4, green: 0.6, blue: 1.0),
            accessories: [.crown(Color(red: 1.0, green: 0.85, blue: 0.2))],
            particleType: .spark,
            eyeStyle: .sharp,
            bounceSpeed: 1.4,
            phrases: [
                .idle: ["*distant thunder*", "the drums rest.", "雷鳴", "storm's eye"],
                .thinking: ["clouds gather.", "charge building...", "static rising", "FEEL THE VOLTAGE"],
                .coding: ["LIGHTNING WRITES", "THUNDER CODE!", "⚡ STRIKE ⚡", "electrifying"],
                .running: ["FULL SURGE!", "THUNDERBOLT!", "雷神の怒り!", "MAXIMUM POWER"],
                .error: ["SHORT CIRCUIT.", "grounded...", "the storm falters", "RECALIBRATING"],
                .success: ["DIVINE THUNDER!", "THE DRUMS ROAR!", "⚡ 雷神 ⚡", "LEGENDARY STRIKE"],
            ]
        ),
    ]
}
