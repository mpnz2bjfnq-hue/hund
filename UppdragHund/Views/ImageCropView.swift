//
//  ImageCropView.swift
//  UppdragHund
//
//  Beskärning av vald bild: dra för att flytta, nyp för att zooma.
//  Kvadratisk ram eftersom resultatet används både som rund avatar och
//  som hero-bakgrund. Resultatet renderas till en JPEG i vald storlek.
//

import SwiftUI
import UIKit

/// Identifierbart omslag så bilden kan presenteras via .sheet(item:).
struct CropCandidate: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct ImageCropView: View {
    let image: UIImage
    /// Sidlängd i pixlar på den färdiga kvadraten.
    var outputSide: CGFloat = 800
    let onCrop: (Data) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var zoom: CGFloat = 1
    @State private var committedZoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var committedOffset: CGSize = .zero
    @State private var cropSide: CGFloat = 0

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height) - Theme.Spacing.xl * 2
                ZStack {
                    Color.black.ignoresSafeArea()

                    Image(uiImage: image)
                        .resizable()
                        .frame(
                            width: image.size.width * displayScale(cropSide: side),
                            height: image.size.height * displayScale(cropSide: side)
                        )
                        .offset(offset)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)

                    dimOverlay(side: side, in: geo.size)

                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .stroke(.white.opacity(0.9), lineWidth: 1)
                        .frame(width: side, height: side)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                        .allowsHitTesting(false)

                    Text("Dra för att flytta · nyp för att zooma")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .position(x: geo.size.width / 2, y: (geo.size.height + side) / 2 + Theme.Spacing.xl)
                        .allowsHitTesting(false)
                }
                .contentShape(Rectangle())
                .gesture(dragGesture(cropSide: side).simultaneously(with: zoomGesture(cropSide: side)))
                .onAppear { cropSide = side }
                .onChange(of: geo.size) { _, _ in cropSide = side }
            }
            .navigationTitle("Justera bild")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klar") {
                        if let data = renderCropped() {
                            onCrop(data)
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Geometri

    /// Skala så bilden minst fyller ramen, gånger användarens zoom.
    private func displayScale(cropSide: CGFloat) -> CGFloat {
        guard image.size.width > 0, image.size.height > 0 else { return 1 }
        return max(cropSide / image.size.width, cropSide / image.size.height) * zoom
    }

    /// Bilden får aldrig lämna en glipa innanför ramen.
    private func clampedOffset(_ proposed: CGSize, cropSide: CGFloat) -> CGSize {
        let width = image.size.width * displayScale(cropSide: cropSide)
        let height = image.size.height * displayScale(cropSide: cropSide)
        let maxX = max(0, (width - cropSide) / 2)
        let maxY = max(0, (height - cropSide) / 2)
        return CGSize(
            width: min(maxX, max(-maxX, proposed.width)),
            height: min(maxY, max(-maxY, proposed.height))
        )
    }

    private func dragGesture(cropSide: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                offset = clampedOffset(CGSize(
                    width: committedOffset.width + value.translation.width,
                    height: committedOffset.height + value.translation.height
                ), cropSide: cropSide)
            }
            .onEnded { _ in
                committedOffset = offset
            }
    }

    private func zoomGesture(cropSide: CGFloat) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                zoom = min(6, max(1, committedZoom * value.magnification))
                offset = clampedOffset(offset, cropSide: cropSide)
            }
            .onEnded { _ in
                committedZoom = zoom
                committedOffset = offset
            }
    }

    /// Mörkar allt utanför ramen (even-odd-fyllning med hål i mitten).
    private func dimOverlay(side: CGFloat, in size: CGSize) -> some View {
        let hole = CGRect(
            x: (size.width - side) / 2,
            y: (size.height - side) / 2,
            width: side, height: side
        )
        return Path { path in
            path.addRect(CGRect(origin: .zero, size: size))
            path.addRoundedRect(
                in: hole,
                cornerSize: CGSize(width: Theme.Radius.card, height: Theme.Radius.card)
            )
        }
        .fill(Color.black.opacity(0.6), style: FillStyle(eoFill: true))
        .allowsHitTesting(false)
    }

    // MARK: - Rendering

    /// Ritar exakt det som syns i ramen till en kvadratisk JPEG.
    private func renderCropped() -> Data? {
        guard cropSide > 0 else { return nil }
        let factor = outputSide / cropSide
        let scale = displayScale(cropSide: cropSide)
        let drawSize = CGSize(
            width: image.size.width * scale * factor,
            height: image.size.height * scale * factor
        )
        let origin = CGPoint(
            x: (outputSide - drawSize.width) / 2 + offset.width * factor,
            y: (outputSide - drawSize.height) / 2 + offset.height * factor
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: outputSide, height: outputSide),
            format: format
        )
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: origin, size: drawSize))
        }
        return rendered.jpegData(compressionQuality: AvatarImage.jpegQuality)
    }
}
