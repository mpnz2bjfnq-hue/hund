//
//  QRScannerView.swift
//  UppdragHund
//
//  Kameraskanner för QR-koder (VisionKit DataScanner, inga beroenden).
//  Anropar onCode med första lästa koden och slutar sedan lyssna.
//

import SwiftUI
import Vision
import VisionKit

struct QRScannerView: UIViewControllerRepresentable {
    var onCode: (String) -> Void

    /// Kräver A12+ och kamera — falskt i simulatorn, så anroparen kan
    /// dölja skanningsknappen där den inte fungerar.
    static var isSupported: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        guard !scanner.isScanning else { return }
        try? scanner.startScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onCode: (String) -> Void
        private var didFire = false

        init(onCode: @escaping (String) -> Void) {
            self.onCode = onCode
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            guard !didFire else { return }
            for item in addedItems {
                if case .barcode(let barcode) = item, let value = barcode.payloadStringValue {
                    didFire = true
                    onCode(value)
                    return
                }
            }
        }
    }
}
