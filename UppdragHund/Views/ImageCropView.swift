//
//  ImageCropView.swift
//  UppdragHund
//
//  Beskärning av vald bild: dra för att flytta, nyp för att zooma.
//  Ramens form styrs av `aspect` (1 = kvadrat för avatarer/hundfoton,
//  16/9 för omslagsbilder). Resultatet renderas till en JPEG.
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
    /// Bredd i pixlar på den färdiga bilden (höjd = bredd / aspect).
    var outputWidth: CGFloat = 800
    /// Ramens bredd/höjd-förhållande. 1 = kvadrat, 16/9 = omslag.
    var aspect: CGFloat = 1
    /// JPEG-kvalitet — sänk för bilder som ska samsas i ett Firestore-dokument.
    var quality: CGFloat = AvatarImage.jpegQuality
    let onCrop: (Data) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var zoom: CGFloat = 1
    @State private var committedZoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var committedOffset: CGSize = .zero
    @State private var cropSize: CGSize = .zero

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let size = frameSize(in: geo.size)
                ZStack {
                    Color.black.ignoresSafeArea()

                    Image(uiImage: image)
                        .resizable()
                        .frame(
                            width: image.size.width * displayScale(cropSize: size),
                            height: image.size.height * displayScale(cropSize: size)
                        )
                        .offset(offset)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)

                    dimOverlay(cropSize: size, in: geo.size)

                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .stroke(.white.opacity(0.9), lineWidth: 1)
                        .frame(width: size.width, height: size.height)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                        .allowsHitTesting(false)

                    Text("Dra för att flytta · nyp för att zooma")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .position(x: geo.size.width / 2, y: (geo.size.height + size.height) / 2 + Theme.Spacing.xl)
                        .allowsHitTesting(false)
                }
                .contentShape(Rectangle())
                .gesture(dragGesture(cropSize: size).simultaneously(with: zoomGesture(cropSize: size)))
                .onAppear { cropSize = size }
                .onChange(of: geo.size) { _, _ in cropSize = size }
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

    /// Största ram med rätt förhållande som ryms med marginal.
    private func frameSize(in available: CGSize) -> CGSize {
        let margin = Theme.Spacing.xl * 2
        let maxWidth = available.width - margin
        let maxHeight = available.height - margin
        let width = min(maxWidth, maxHeight * aspect)
        return CGSize(width: width, height: width / aspect)
    }

    /// Skala så bilden minst fyller ramen, gånger användarens zoom.
    private func displayScale(cropSize: CGSize) -> CGFloat {
        guard image.size.width > 0, image.size.height > 0 else { return 1 }
        return max(cropSize.width / image.size.width, cropSize.height / image.size.height) * zoom
    }

    /// Bilden får aldrig lämna en glipa innanför ramen.
    private func clampedOffset(_ proposed: CGSize, cropSize: CGSize) -> CGSize {
        let width = image.size.width * displayScale(cropSize: cropSize)
        let height = image.size.height * displayScale(cropSize: cropSize)
        let maxX = max(0, (width - cropSize.width) / 2)
        let maxY = max(0, (height - cropSize.height) / 2)
        return CGSize(
            width: min(maxX, max(-maxX, proposed.width)),
            height: min(maxY, max(-maxY, proposed.height))
        )
    }

    private func dragGesture(cropSize: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                offset = clampedOffset(CGSize(
                    width: committedOffset.width + value.translation.width,
                    height: committedOffset.height + value.translation.height
                ), cropSize: cropSize)
            }
            .onEnded { _ in
                committedOffset = offset
            }
    }

    private func zoomGesture(cropSize: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                zoom = min(6, max(1, committedZoom * value.magnification))
                offset = clampedOffset(offset, cropSize: cropSize)
            }
            .onEnded { _ in
                committedZoom = zoom
                committedOffset = offset
            }
    }

    /// Mörkar allt utanför ramen (even-odd-fyllning med hål i mitten).
    private func dimOverlay(cropSize: CGSize, in size: CGSize) -> some View {
        let hole = CGRect(
            x: (size.width - cropSize.width) / 2,
            y: (size.height - cropSize.height) / 2,
            width: cropSize.width, height: cropSize.height
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

    /// Ritar exakt det som syns i ramen till en JPEG i outputstorleken.
    private func renderCropped() -> Data? {
        guard cropSize.width > 0 else { return nil }
        let outputSize = CGSize(width: outputWidth, height: outputWidth / aspect)
        let factor = outputWidth / cropSize.width
        let scale = displayScale(cropSize: cropSize)
        let drawSize = CGSize(
            width: image.size.width * scale * factor,
            height: image.size.height * scale * factor
        )
        let origin = CGPoint(
            x: (outputSize.width - drawSize.width) / 2 + offset.width * factor,
            y: (outputSize.height - drawSize.height) / 2 + offset.height * factor
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: outputSize, format: format)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: origin, size: drawSize))
        }
        return rendered.jpegData(compressionQuality: quality)
    }
}
