//
//  DogBodyMap.swift
//  UppdragHund
//
//  Kroppskarta för att markera var på hunden en skada sitter. Sex vyer
//  (schäfer-illustrationer i asset-katalogen) med en vy-väljare, och en
//  markör som antingen sätts genom att trycka (redigerbart läge) eller bara
//  visas (läsläge). Markörens position lagras normaliserat (0–1) så den
//  följer med oavsett bildstorlek.
//

import SwiftUI

struct DogBodyMap: View {
    @Binding var view: BodyView
    /// Normaliserad markörposition (0–1), eller nil om ingen markör satts.
    @Binding var point: CGPoint?
    /// Redigerbart: tryck sätter markören. Annars visas den bara.
    var isEditable: Bool = false
    /// Färg på markören (t.ex. läk-statusens färg).
    var markerColor: Color = Theme.Colors.warning

    private let mapHeight: CGFloat = 260

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            if isEditable {
                viewPicker
            }
            mapArea
            if isEditable {
                Text(point == nil
                     ? "Tryck på kartan där skadan sitter."
                     : "\(view.displayName) · tryck för att flytta markören.")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
    }

    private var viewPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.s) {
                ForEach(BodyView.allCases) { candidate in
                    Button {
                        view = candidate
                    } label: {
                        Text(candidate.displayName)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, Theme.Spacing.m)
                            .padding(.vertical, Theme.Spacing.s)
                            .background(
                                view == candidate ? Theme.Colors.brand.opacity(0.15) : Color.clear,
                                in: Capsule()
                            )
                            .overlay(
                                Capsule().strokeBorder(
                                    view == candidate ? Theme.Colors.brand : Theme.Colors.textSecondary.opacity(0.3),
                                    lineWidth: 1
                                )
                            )
                            .foregroundStyle(view == candidate ? Theme.Colors.brand : Theme.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var mapArea: some View {
        GeometryReader { geo in
            let aspect = imageAspect
            let renderedW = min(geo.size.width, mapHeight * aspect)
            let renderedH = renderedW / aspect
            let ox = (geo.size.width - renderedW) / 2
            let oy = (mapHeight - renderedH) / 2

            ZStack(alignment: .topLeading) {
                Image(view.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: mapHeight)

                if let point {
                    marker
                        .position(x: ox + point.x * renderedW,
                                  y: oy + point.y * renderedH)
                }
            }
            .frame(width: geo.size.width, height: mapHeight)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        guard isEditable, renderedW > 0, renderedH > 0 else { return }
                        let nx = (value.location.x - ox) / renderedW
                        let ny = (value.location.y - oy) / renderedH
                        guard (0...1).contains(nx), (0...1).contains(ny) else { return }
                        point = CGPoint(x: nx, y: ny)
                    }
            )
        }
        .frame(height: mapHeight)
    }

    private var marker: some View {
        ZStack {
            Circle()
                .fill(markerColor.opacity(0.22))
                .frame(width: 34, height: 34)
            Circle()
                .fill(markerColor)
                .frame(width: 15, height: 15)
                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
        }
    }

    /// Bredd/höjd-förhållande för aktuell vy, läst från bilden.
    private var imageAspect: CGFloat {
        guard let image = UIImage(named: view.assetName), image.size.height > 0 else { return 1 }
        return image.size.width / image.size.height
    }
}

#Preview {
    struct Harness: View {
        @State private var view: BodyView = .side
        @State private var point: CGPoint? = CGPoint(x: 0.32, y: 0.62)
        var body: some View {
            ScrollView {
                DogBodyMap(view: $view, point: $point, isEditable: true)
                    .padding()
            }
            .background(Theme.screenSurface)
        }
    }
    return Harness()
}
