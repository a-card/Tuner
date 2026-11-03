import SwiftUI

/// A semicircular meter showing how far the pitch is from the target, −50…+50 cents.
struct CentsGauge: View {
    /// `nil` when nothing has been detected yet.
    let cents: Double?
    let isActive: Bool

    private let range = 50.0
    /// Half of the arc's sweep, in degrees.
    private let sweep = 70.0

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let radius = min(size.width / 2, size.height) * 0.95
            let center = CGPoint(x: size.width / 2, y: size.height)

            ZStack {
                // In-tune zone.
                ArcShape(center: center, radius: radius, from: angle(for: -TunerModel.inTuneTolerance),
                         to: angle(for: TunerModel.inTuneTolerance))
                    .stroke(Color.green.opacity(0.35), style: StrokeStyle(lineWidth: 14, lineCap: .round))

                // Tick marks every 10 cents, minor every 5.
                ForEach(Array(stride(from: -50, through: 50, by: 5)), id: \.self) { value in
                    Tick(center: center, radius: radius, angle: angle(for: Double(value)),
                         length: value % 10 == 0 ? 16 : 8)
                        .stroke(value == 0 ? Color.primary : Color.secondary,
                                lineWidth: value == 0 ? 3 : 1.5)
                }

                ForEach([-50, -25, 25, 50], id: \.self) { value in
                    Text(value > 0 ? "+\(value)" : "\(value)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .position(point(center: center, radius: radius - 30, angle: angle(for: Double(value))))
                }

                Text("♭")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .position(point(center: center, radius: radius + 4, angle: -sweep - 14))
                Text("♯")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .position(point(center: center, radius: radius + 4, angle: sweep + 14))

                Needle(center: center, length: radius - 6, angle: angle(for: displayedCents))
                    .stroke(needleColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .animation(.interpolatingSpring(stiffness: 140, damping: 18), value: displayedCents)

                Circle()
                    .fill(needleColor)
                    .frame(width: 16, height: 16)
                    .position(center)
            }
        }
        .opacity(isActive ? 1 : 0.45)
        .animation(.easeOut(duration: 0.3), value: isActive)
        .accessibilityElement()
        .accessibilityLabel("Tuning meter")
        .accessibilityValue(accessibilityValue)
    }

    private var displayedCents: Double {
        guard let cents else { return 0 }
        return max(-range, min(range, cents))
    }

    private var needleColor: Color {
        guard let cents, isActive else { return .secondary }
        if abs(cents) <= TunerModel.inTuneTolerance { return .green }
        return abs(cents) < 15 ? .orange : .red
    }

    private var accessibilityValue: String {
        guard let cents, isActive else { return "No signal" }
        let rounded = Int(cents.rounded())
        if abs(cents) <= TunerModel.inTuneTolerance { return "In tune" }
        return rounded > 0 ? "\(rounded) cents sharp" : "\(-rounded) cents flat"
    }

    /// Degrees from vertical, clockwise.
    private func angle(for cents: Double) -> Double {
        cents / range * sweep
    }
}

/// Converts an angle measured clockwise from 12 o'clock into a point.
private func point(center: CGPoint, radius: CGFloat, angle: Double) -> CGPoint {
    let radians = angle * .pi / 180
    return CGPoint(x: center.x + radius * sin(radians), y: center.y - radius * cos(radians))
}

private struct ArcShape: Shape {
    let center: CGPoint
    let radius: CGFloat
    let from: Double
    let to: Double

    func path(in rect: CGRect) -> Path {
        Path { path in
            // SwiftUI angles start at 3 o'clock; ours start at 12 o'clock.
            path.addArc(center: center, radius: radius,
                        startAngle: .degrees(from - 90), endAngle: .degrees(to - 90), clockwise: false)
        }
    }
}

private struct Tick: Shape {
    let center: CGPoint
    let radius: CGFloat
    let angle: Double
    let length: CGFloat

    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: point(center: center, radius: radius, angle: angle))
            path.addLine(to: point(center: center, radius: radius - length, angle: angle))
        }
    }
}

private struct Needle: Shape {
    let center: CGPoint
    let length: CGFloat
    var angle: Double

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: center)
            path.addLine(to: point(center: center, radius: length, angle: angle))
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        CentsGauge(cents: -18, isActive: true).frame(height: 170)
        CentsGauge(cents: 2, isActive: true).frame(height: 170)
        CentsGauge(cents: nil, isActive: false).frame(height: 170)
    }
    .padding()
}
