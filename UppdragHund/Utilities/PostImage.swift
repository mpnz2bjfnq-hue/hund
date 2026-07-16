//
//  PostImage.swift
//  UppdragHund
//
//  Komprimerar en vald bild för inlägg i flödet. Behåller proportionerna
//  (max ~900 px längsta sida) och pressar JPEG-kvaliteten tills den ryms
//  gott inom Firestores dokumentgräns (1 MB).
//

import UIKit

enum PostImage {
    static let maxSide: CGFloat = 900
    static let maxBytes = 600_000

    static func makeData(from image: UIImage) -> Data? {
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }

        // Sänk kvaliteten stegvis tills bilden ryms.
        var quality: CGFloat = 0.7
        while quality >= 0.3 {
            if let data = rendered.jpegData(compressionQuality: quality), data.count <= maxBytes {
                return data
            }
            quality -= 0.1
        }
        return rendered.jpegData(compressionQuality: 0.25)
    }
}
