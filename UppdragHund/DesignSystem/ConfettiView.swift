//
//  ConfettiView.swift
//  UppdragHund
//
//  Enkel konfetti-effekt för firande (t.ex. när ett pass slutförs).
//

import SwiftUI

struct ConfettiView: View {
    var count = 70
    @State private var animate = false
    @State private var pieces: [Piece] = []

    private let palette: [Color] = [.green, .orange, .pink, .yellow, .blue, .mint]

    private struct Piece: Identifiable {
        let id = UUID()
        let x: CGFloat
        let delay: Double
        let color: Color
        let size: CGFloat
        let rotation: Double
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { piece in
                    Rectangle()
                        .fill(piece.color)
                        .frame(width: piece.size, height: piece.size * 0.6)
                        .rotationEffect(.degrees(animate ? piece.rotation + 420 : piece.rotation))
                        .position(
                            x: piece.x * geo.size.width,
                            y: animate ? geo.size.height + 40 : -40
                        )
                        .opacity(animate ? 0 : 1)
                        .animation(.easeIn(duration: 2.0).delay(piece.delay), value: animate)
                }
            }
            .onAppear {
                pieces = (0..<count).map { _ in
                    Piece(
                        x: .random(in: 0...1),
                        delay: .random(in: 0...0.4),
                        color: palette.randomElement() ?? .green,
                        size: .random(in: 6...12),
                        rotation: .random(in: 0...360)
                    )
                }
                animate = true
            }
        }
        .allowsHitTesting(false)
    }
}
