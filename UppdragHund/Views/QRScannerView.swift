//
//  QRScannerView.swift
//  UppdragHund
//
//  Kameraskanner för QR-koder (VisionKit DataScanner, inga beroenden).
//  Anropar onCode med första lästa koden och slutar sedan lyssna.
//

import AVFoundation
import SwiftUI
import Vision
import VisionKit

struct QRScannerView: UIViewControllerRepresentable {
    var onCode: (String) -> Void

    /// Hårdvarustöd (A12+ med kamera) — falskt i simulatorn, så anroparen
    /// kan dölja skanningsknappen där den inte fungerar. Avsiktligt UTAN
    /// isAvailable: den blir falsk även vid nekad kamerabehörighet, och då
    /// ska knappen synas och leda till "öppna Inställningar"-vyn i stället
    /// för att tyst försvinna.
    static var isSupported: Bool {
        DataScannerViewController.isSupported
    }

    /// Har användaren aktivt nekat (eller föräldrar spärrat) kameran?
    static var isCameraBlocked: Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .denied, .restricted: true
        default: false
        }
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
