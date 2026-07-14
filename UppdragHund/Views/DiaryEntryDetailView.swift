//
//  DiaryEntryDetailView.swift
//  UppdragHund
//

import SwiftUI

struct DiaryEntryDetailView: View {
    let entry: DiaryEntry

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let data = entry.photoData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    HStack {
                        Text(entry.date.formatted(date: .long, time: .omitted))
                            .font(.headline)
                        Spacer()
                        Text(entry.mood.emoji)
                            .font(.largeTitle)
                    }

                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                        GridRow {
                            Text("Blödning").foregroundStyle(.secondary)
                            Text("\(entry.bleedingLevel)/5")
                        }
                        GridRow {
                            Text("Svullnad").foregroundStyle(.secondary)
                            Text("\(entry.swellingLevel)/5")
                        }
                        GridRow {
                            Text("Aptit").foregroundStyle(.secondary)
                            Text("\(entry.appetiteLevel)/5")
                        }
                        GridRow {
                            Text("Energi").foregroundStyle(.secondary)
                            Text("\(entry.energyLevel)/5")
                        }
                    }
                    .font(.subheadline)
                }
                .padding()
            }
            .navigationTitle("Dagboksinlägg")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Stäng") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    DiaryEntryDetailView(entry: DiaryEntry(date: .now, bleedingLevel: 3, swellingLevel: 2, appetiteLevel: 4, energyLevel: 3, mood: .good))
}
