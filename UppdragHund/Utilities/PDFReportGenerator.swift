//
//  PDFReportGenerator.swift
//  UppdragHund
//

import UIKit

enum PDFReportGenerator {
    static func generateReport(
        dogName: String,
        dogBreed: String,
        healthEvents: [HealthEvent],
        heatCycleEntries: [HeatCycleAnalyzer.HistoryEntry],
        includeHealth: Bool,
        includeHeat: Bool,
        generatedAt: Date = .now
    ) -> Data {
        let pageWidth: CGFloat = 595 // A4 at 72dpi
        let pageHeight: CGFloat = 842
        let margin: CGFloat = 40
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let titleFont = UIFont.boldSystemFont(ofSize: 20)
        let headerFont = UIFont.boldSystemFont(ofSize: 14)
        let bodyFont = UIFont.systemFont(ofSize: 11)
        let secondaryFont = UIFont.systemFont(ofSize: 10)

        return renderer.pdfData { context in
            context.beginPage()
            var y: CGFloat = margin

            func drawText(_ text: String, font: UIFont, color: UIColor = .black, spacingAfter: CGFloat = 4) {
                let attributed = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
                let maxWidth = pageWidth - margin * 2
                let boundingRect = attributed.boundingRect(
                    with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
                    options: .usesLineFragmentOrigin,
                    context: nil
                )
                if y + boundingRect.height > pageHeight - margin {
                    context.beginPage()
                    y = margin
                }
                attributed.draw(in: CGRect(x: margin, y: y, width: maxWidth, height: ceil(boundingRect.height)))
                y += ceil(boundingRect.height) + spacingAfter
            }

            drawText(String(localized: "Hälsorapport – \(dogName)"), font: titleFont, spacingAfter: 4)
            drawText(
                String(localized: "\(dogBreed) · Genererad \(generatedAt.formatted(date: .abbreviated, time: .shortened))"),
                font: secondaryFont,
                color: .darkGray,
                spacingAfter: 16
            )

            if includeHealth {
                drawText(String(localized: "Hälsologg"), font: headerFont, spacingAfter: 6)
                if healthEvents.isEmpty {
                    drawText(String(localized: "Inga poster i valt intervall."), font: bodyFont, color: .darkGray, spacingAfter: 12)
                } else {
                    for event in healthEvents {
                        drawText(healthEventLine(event), font: bodyFont, spacingAfter: 3)
                        if let note = event.note, !note.isEmpty {
                            drawText("   \(note)", font: secondaryFont, color: .darkGray, spacingAfter: 4)
                        }
                    }
                    y += 8
                }
            }

            if includeHeat {
                drawText(String(localized: "Löphistorik"), font: headerFont, spacingAfter: 6)
                if heatCycleEntries.isEmpty {
                    drawText(String(localized: "Inga löp i valt intervall."), font: bodyFont, color: .darkGray, spacingAfter: 12)
                } else {
                    for entry in heatCycleEntries {
                        drawText(heatCycleLine(entry), font: bodyFont, spacingAfter: 3)
                    }
                }
            }
        }
    }

    private static func healthEventLine(_ event: HealthEvent) -> String {
        var line = "\(event.date.formatted(date: .abbreviated, time: .omitted)) – \(event.type.displayName): \(event.title)"
        if let weight = event.weightKg {
            line += " (\(String(format: "%.1f", weight)) kg)"
        }
        if let temperature = event.temperatureCelsius {
            line += " (\(String(format: "%.1f", temperature)) °C)"
        }
        if let bodyLocation = event.bodyLocation {
            line += " – \(bodyLocation.displayName)"
        }
        return line
    }

    private static func heatCycleLine(_ entry: HeatCycleAnalyzer.HistoryEntry) -> String {
        let endText = entry.cycle.endDate?.formatted(date: .abbreviated, time: .omitted) ?? String(localized: "pågående")
        var line = "\(entry.cycle.startDate.formatted(date: .abbreviated, time: .omitted)) – \(endText)"
        if let duration = entry.cycle.durationInDays {
            line += String(localized: ", \(duration) dagar")
        }
        if let interval = entry.intervalSincePreviousDays {
            line += String(localized: ", intervall \(interval) dagar")
        }
        return line
    }
}
