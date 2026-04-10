import SwiftUI

// MARK: - Particle Field

struct ParticleField: View {
    let type: ParticleType
    let isActive: Bool
    private let count = 12

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { i in
                ParticleUnit(type: type, seed: i, total: count)
            }
        }
        .frame(width: 130, height: 130)
        .opacity(isActive ? 1.0 : 0.3)
        .animation(.easeInOut(duration: 0.5), value: isActive)
    }
}

struct ParticleUnit: View {
    let type: ParticleType
    let seed: Int
    let total: Int
    @State private var phase = false

    private var xBase: CGFloat { CGFloat(((seed * 7 + 3) % total) - total / 2) * 12 }
    private var drift: CGFloat { CGFloat((seed * 13 + 5) % 11) - 5 }
    private var delay: Double { Double(seed) * 0.22 }
    private var duration: Double { 2.0 + Double(seed % 4) * 0.4 }

    var body: some View {
        particleShape
            .offset(
                x: xBase + (phase ? drift * 1.5 : -drift),
                y: phase ? -60 : 35
            )
            .opacity(phase ? 0 : 0.8)
            .scaleEffect(phase ? 0.15 : 1.0)
            .rotationEffect(.degrees(phase ? Double(seed * 72) : 0))
            .onAppear {
                withAnimation(
                    .easeOut(duration: duration)
                    .repeatForever(autoreverses: false)
                    .delay(delay)
                ) {
                    phase = true
                }
            }
    }

    @ViewBuilder
    var particleShape: some View {
        switch type {
        case .snowflake:
            Image(systemName: "snowflake")
                .font(.system(size: 9, weight: .light))
                .foregroundColor(.white.opacity(0.9))
                .shadow(color: .cyan.opacity(0.5), radius: 3)
        case .petal:
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [Color.pink.opacity(0.7), Color.pink.opacity(0.3)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: 8, height: 5)
                .shadow(color: .pink.opacity(0.4), radius: 2)
        case .star:
            Image(systemName: "star.fill")
                .font(.system(size: 7))
                .foregroundColor(.yellow.opacity(0.9))
                .shadow(color: .yellow.opacity(0.6), radius: 4)
        case .spark:
            ZStack {
                Circle()
                    .fill(Color.yellow)
                    .frame(width: 3, height: 3)
                Circle()
                    .fill(Color.white)
                    .frame(width: 1.5, height: 1.5)
            }
            .shadow(color: .yellow, radius: 4)
        case .flame:
            Image(systemName: "flame.fill")
                .font(.system(size: 8))
                .foregroundColor(.orange.opacity(0.8))
                .shadow(color: .red.opacity(0.5), radius: 3)
        }
    }
}

// MARK: - Rarity Auras

struct EpicAura: View {
    let color: Color
    @State private var pulse = false
    @State private var innerPulse = false

    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(color.opacity(pulse ? 0.5 : 0.1), lineWidth: pulse ? 3.5 : 1.5)
                .frame(width: pulse ? 105 : 95, height: pulse ? 105 : 95)
                .blur(radius: 3)

            // Inner glow
            Circle()
                .fill(color.opacity(innerPulse ? 0.12 : 0.03))
                .frame(width: 100, height: 100)
                .blur(radius: 10)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                pulse = true
            }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                innerPulse = true
            }
        }
    }
}

struct LegendaryAura: View {
    @State private var rotation: Double = 0
    @State private var pulse = false
    @State private var innerPulse = false

    var body: some View {
        ZStack {
            // Rainbow ring
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink, .red],
                        center: .center
                    ),
                    lineWidth: 3
                )
                .frame(width: 104, height: 104)
                .blur(radius: 2)
                .opacity(pulse ? 0.85 : 0.35)
                .rotationEffect(.degrees(rotation))

            // Second ring (offset phase)
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [.purple, .blue, .cyan, .green, .yellow, .orange, .red, .purple],
                        center: .center
                    ),
                    lineWidth: 1.5
                )
                .frame(width: 110, height: 110)
                .blur(radius: 3)
                .opacity(pulse ? 0.4 : 0.15)
                .rotationEffect(.degrees(-rotation * 0.7))

            // Center glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.yellow.opacity(innerPulse ? 0.15 : 0.03), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 55
                    )
                )
                .frame(width: 110, height: 110)
        }
        .onAppear {
            withAnimation(.linear(duration: 5).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                pulse = true
            }
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                innerPulse = true
            }
        }
    }
}

// MARK: - Accessories

struct AccessoryView: View {
    let type: AccessoryType

    var body: some View {
        switch type {
        case .catEars(let color):
            HStack(spacing: 30) {
                Triangle().fill(color)
                    .frame(width: 16, height: 14)
                    .rotationEffect(.degrees(-10))
                Triangle().fill(color)
                    .frame(width: 16, height: 14)
                    .rotationEffect(.degrees(10))
            }
            .offset(y: -42)

        case .foxEars(let color):
            HStack(spacing: 34) {
                Triangle().fill(color)
                    .frame(width: 13, height: 22)
                    .rotationEffect(.degrees(-15))
                Triangle().fill(color)
                    .frame(width: 13, height: 22)
                    .rotationEffect(.degrees(15))
            }
            .offset(y: -44)

        case .horns(let color):
            HStack(spacing: 26) {
                Capsule().fill(color)
                    .frame(width: 9, height: 20)
                    .rotationEffect(.degrees(-25))
                Capsule().fill(color)
                    .frame(width: 9, height: 20)
                    .rotationEffect(.degrees(25))
            }
            .offset(y: -46)

        case .halo(let color):
            HaloAccessory(color: color)
                .offset(y: -50)

        case .crown(let color):
            CrownShape().fill(color)
                .frame(width: 32, height: 16)
                .shadow(color: color.opacity(0.7), radius: 5)
                .offset(y: -44)

        case .bow(let color):
            BowShape().fill(color)
                .frame(width: 15, height: 13)
                .shadow(color: color.opacity(0.4), radius: 2)
                .offset(x: 35, y: -24)
        }
    }
}

struct HaloAccessory: View {
    let color: Color
    @State private var glow = false

    var body: some View {
        Ellipse()
            .stroke(color, lineWidth: 2.5)
            .frame(width: 38, height: 11)
            .shadow(color: color.opacity(glow ? 1.0 : 0.3), radius: glow ? 10 : 3)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    glow = true
                }
            }
    }
}

// MARK: - Accessory Shapes

struct CrownShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: 0, y: h))
        p.addLine(to: CGPoint(x: 0, y: h * 0.45))
        p.addLine(to: CGPoint(x: w * 0.18, y: h * 0.65))
        p.addLine(to: CGPoint(x: w * 0.33, y: 0))
        p.addLine(to: CGPoint(x: w * 0.5, y: h * 0.5))
        p.addLine(to: CGPoint(x: w * 0.67, y: 0))
        p.addLine(to: CGPoint(x: w * 0.82, y: h * 0.65))
        p.addLine(to: CGPoint(x: w, y: h * 0.45))
        p.addLine(to: CGPoint(x: w, y: h))
        p.closeSubpath()
        return p
    }
}

struct BowShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addEllipse(in: CGRect(
            x: 0, y: rect.height * 0.1,
            width: rect.width * 0.45, height: rect.height * 0.8
        ))
        p.addEllipse(in: CGRect(
            x: rect.width * 0.55, y: rect.height * 0.1,
            width: rect.width * 0.45, height: rect.height * 0.8
        ))
        p.addEllipse(in: CGRect(
            x: rect.width * 0.3, y: rect.height * 0.25,
            width: rect.width * 0.4, height: rect.height * 0.5
        ))
        return p
    }
}
