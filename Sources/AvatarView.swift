import SwiftUI

// MARK: - Main Avatar

struct AvatarView: View {
    @ObservedObject var state: BuddyState
    @State private var bounce: CGFloat = 0
    @State private var isBlinking = false
    @State private var currentPhrase: String?
    @State private var showPhrase = false
    @State private var jiggleTrigger = 0

    let blinkTimer = Timer.publish(every: 3.5, on: .main, in: .common).autoconnect()
    private let voice = BuddyVoice()
    private let snarky = SnarkyGenerator()

    private var persona: Persona { state.selectedPersona }

    var body: some View {
        ZStack(alignment: .bottom) {
            // ── Character (pinned to bottom) ──
            LowPolyHead(
                personaId: persona.id,
                bodyColor: persona.bodyColor,
                highlightColor: persona.bodyHighlight,
                hairColor: persona.hairColor,
                eyeColor: persona.eyeColor,
                subtitle: persona.subtitle,
                activity: state.currentState,
                isBlinking: isBlinking,
                bounceSpeed: persona.bounceSpeed,
                jiggleTrigger: jiggleTrigger
            )
            .frame(width: 180, height: 180)
            .onTapGesture { jiggleTrigger += 1 }

            // ── Speech Bubble (floats above, doesn't push) ──
            if showPhrase, let phrase = currentPhrase {
                SpeechBubble(text: phrase)
                    .offset(y: -115)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .frame(width: 180, height: 180)
        .animation(.easeInOut(duration: 0.4), value: state.currentState)
        .onReceive(blinkTimer) { _ in blink() }
        .onChange(of: state.currentState) { _ in updatePhrase() }
    }

    // MARK: - Tint

    private var activityTint: Color {
        switch state.currentState {
        case .idle:     return .clear
        case .thinking: return .yellow
        case .coding:   return .green
        case .running:  return .cyan
        case .error:    return .red
        case .success:  return .green
        }
    }

    // MARK: - Animations

    private func blink() {
        withAnimation(.easeInOut(duration: 0.08)) { isBlinking = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeInOut(duration: 0.1)) { isBlinking = false }
        }
    }

    private func updatePhrase() {
        // Try AI-generated snarky response first
        if snarky.isAvailable {
            snarky.generate(activity: state.currentState, context: state.lastContext) { [self] text in
                if let text = text {
                    showBubble(text)
                } else {
                    // Fallback to canned phrase
                    if let phrase = persona.randomPhrase(for: state.currentState) {
                        showBubble(phrase)
                    }
                }
            }
        } else {
            // No API key — use canned phrases
            if let phrase = persona.randomPhrase(for: state.currentState) {
                showBubble(phrase)
            }
        }
    }

    private func showBubble(_ text: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            currentPhrase = text
            showPhrase = true
        }
        voice.speak(text, persona: persona.id, activity: state.currentState)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                showPhrase = false
            }
        }
    }
}

// MARK: - Speech Bubble

struct SpeechBubble: View {
    let text: String

    var body: some View {
        VStack(spacing: 0) {
            Text(text)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.black.opacity(0.75))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(.white.opacity(0.15), lineWidth: 0.5)
                        )
                )

            // Tail
            Triangle()
                .fill(.black.opacity(0.75))
                .frame(width: 10, height: 6)
                .rotationEffect(.degrees(180))
        }
    }
}

// MARK: - Shimmer

struct ShimmerSweep: View {
    @State private var offset: CGFloat = -120

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.25), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: 30)
            .offset(x: offset)
            .onAppear {
                withAnimation(.linear(duration: 2.8).repeatForever(autoreverses: false)) {
                    offset = 120
                }
            }
    }
}

// MARK: - Ambient Sparkle

struct AmbientSparkle: View {
    let count: Int

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { i in
                SparkleUnit(seed: i, total: count)
            }
        }
        .frame(width: 120, height: 120)
    }
}

struct SparkleUnit: View {
    let seed: Int
    let total: Int
    @State private var phase = false

    private var angle: Double { Double(seed) * (2 * .pi / Double(total)) }
    private var radius: CGFloat { 48 + CGFloat(seed % 3) * 6 }
    private var x: CGFloat { CGFloat(cos(angle)) * radius }
    private var y: CGFloat { CGFloat(sin(angle)) * radius }
    private var delay: Double { Double(seed) * 0.25 }

    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: phase ? 7 : 2))
            .foregroundColor(.white.opacity(phase ? 0.9 : 0.05))
            .offset(x: x + (phase ? 4 : -4), y: y + (phase ? -3 : 3))
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.3)
                    .repeatForever(autoreverses: true)
                    .delay(delay)
                ) {
                    phase = true
                }
            }
    }
}

// MARK: - Thinking Bubble

struct ThinkingBubble: View {
    @State private var phase = 0
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.white.opacity(phase == i ? 1.0 : 0.3))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.black.opacity(0.3)))

            HStack(spacing: 3) {
                Circle().fill(Color.black.opacity(0.2)).frame(width: 5, height: 5)
                Circle().fill(Color.black.opacity(0.12)).frame(width: 3, height: 3)
            }
            .offset(x: -4)
        }
        .onReceive(timer) { _ in phase = (phase + 1) % 3 }
    }
}

// MARK: - Shapes

struct SmileCurve: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.maxY)
        )
        return p
    }
}

struct FrownCurve: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.midX, y: rect.minY)
        )
        return p
    }
}

struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        p.closeSubpath()
        return p
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
