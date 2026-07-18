//
//  AvatarImage.swift
//  UppdragHund
//
//  Komprimerar en vald bild till en liten kvadratisk avatar som får plats
//  direkt i Firestore-profilen (dokumentgräns 1 MB).
//

import UIKit

enum AvatarImage {
    static let targetSize: CGFloat = 256
    static let jpegQuality: CGFloat = 0.7

    /// Skalar (aspect-fill), beskär till en kvadrat och komprimerar till JPEG.
    /// `side` styr storleken — små thumbnails (t.ex. 128) för listor som ska
    /// samsas många i ett Firestore-dokument.
    static func makeThumbnailData(from image: UIImage, side: CGFloat = targetSize) -> Data? {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)

        let rendered = renderer.image { _ in
            // Aspect-fill: skala så kortaste sidan täcker, centrera.
            let scale = max(side / image.size.width, side / image.size.height)
            let scaledWidth = image.size.width * scale
            let scaledHeight = image.size.height * scale
            let origin = CGPoint(x: (side - scaledWidth) / 2, y: (side - scaledHeight) / 2)
            image.draw(in: CGRect(origin: origin, size: CGSize(width: scaledWidth, height: scaledHeight)))
        }
        return rendered.jpegData(compressionQuality: jpegQuality)
    }
}
