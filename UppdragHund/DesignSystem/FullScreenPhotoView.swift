//
//  FullScreenPhotoView.swift
//  UppdragHund
//
//  Helskärmsvisning av ett foto med nyp-zoom, panorering och dubbeltryck.
//  Zoomen ligger i en UIScrollView för att få systemets känsla (studs,
//  momentum, dubbeltryck mot punkt) — SwiftUI-gester blir styltiga här.
//

import SwiftUI

/// Identifierbar omslagstyp så bilden kan presenteras med .fullScreenCover(item:).
struct FullScreenPhoto: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct FullScreenPhotoView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            ZoomableImageView(image: image)
                .ignoresSafeArea()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.leading, Theme.Spacing.m)
            .padding(.top, Theme.Spacing.s)
            .accessibilityLabel("Stäng")
        }
        .statusBarHidden()
    }
}

/// UIScrollView-baserad zoombar bild. Dubbeltryck zoomar in mot punkten och
/// ut igen; nyp och drag hanteras av scrollvyn.
private struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 5
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = .clear
        scrollView.contentInsetAdjustmentBehavior = .never

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.frame = scrollView.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        imageView.isUserInteractionEnabled = true
        scrollView.addSubview(imageView)
        context.coordinator.imageView = imageView

        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var imageView: UIImageView?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView = gesture.view as? UIScrollView else { return }
            if scrollView.zoomScale > scrollView.minimumZoomScale {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            } else {
                // Zooma in mot punkten man tryckte på.
                let point = gesture.location(in: imageView)
                let side = CGSize(width: scrollView.bounds.width / 3,
                                  height: scrollView.bounds.height / 3)
                scrollView.zoom(
                    to: CGRect(x: point.x - side.width / 2,
                               y: point.y - side.height / 2,
                               width: side.width,
                               height: side.height),
                    animated: true
                )
            }
        }
    }
}
