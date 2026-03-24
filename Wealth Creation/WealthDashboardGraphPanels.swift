import SwiftUI

struct WealthMiniGraph: View {
    let points: [Double]
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let safePoints = points.isEmpty ? [0.4, 0.52, 0.48, 0.63] : points
            let step = safePoints.count > 1 ? width / CGFloat(safePoints.count - 1) : width

            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.26), Color.white.opacity(0.10), tint.opacity(0.08), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(tint.opacity(0.24), lineWidth: 0.9)
                    )

                Path { path in
                    for index in 0..<4 {
                        let y = (height / 4) * CGFloat(index) + 4
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                }
                .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 1, dash: [4, 6]))

                Path { path in
                    for (index, value) in safePoints.enumerated() {
                        let x = CGFloat(index) * step
                        let y = (1 - CGFloat(min(max(value, 0), 1))) * (height - 16) + 8
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(
                    LinearGradient(colors: [Color.white.opacity(0.92), tint, tint.opacity(0.88)], startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 4.2, lineCap: .round, lineJoin: .round)
                )

                Path { path in
                    guard let first = safePoints.first else { return }
                    let firstY = (1 - CGFloat(min(max(first, 0), 1))) * (height - 16) + 8
                    path.move(to: CGPoint(x: 0, y: height - 8))
                    path.addLine(to: CGPoint(x: 0, y: firstY))

                    for (index, value) in safePoints.enumerated() {
                        let x = CGFloat(index) * step
                        let y = (1 - CGFloat(min(max(value, 0), 1))) * (height - 16) + 8
                        path.addLine(to: CGPoint(x: x, y: y))
                    }

                    if let lastIndex = safePoints.indices.last {
                        let lastX = CGFloat(lastIndex) * step
                        path.addLine(to: CGPoint(x: lastX, y: height - 8))
                    }
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.34), Color.white.opacity(0.08), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
    }
}

struct WealthGraphCard: View {
    let title: String
    let subtitle: String
    let tint: Color
    let points: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(WealthTheme.grey)
                }
                Spacer()
                Circle()
                    .fill(tint)
                    .frame(width: 10, height: 10)
            }

            WealthMiniGraph(points: points, tint: tint)
                .frame(height: 118)
        }
        .padding(12)
        .background(glowPanelShell(cornerRadius: 24, tint: tint, secondaryTint: .white.opacity(0.92)))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(tint.opacity(0.34), lineWidth: 1.1)
        )
    }
}
