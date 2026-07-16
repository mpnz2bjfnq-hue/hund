//
//  OmOssView.swift
//  UppdragHund
//

import SwiftUI

private struct NewsItem: Identifiable {
    let id = UUID()
    let date: Date
    let title: String
    let description: String
}

struct OmOssView: View {
    @Environment(\.dismiss) private var dismiss

    private let newsItems: [NewsItem] = {
        let calendar = Calendar.current
        func day(_ offset: Int) -> Date {
            calendar.date(byAdding: .day, value: offset, to: .now) ?? .now
        }
        return [
            NewsItem(date: day(0), title: "Hundträning", description: "Logga träningspass med fördefinierade aktiviteter som Inkallning, Fot och Sök, eller ange en egen."),
            NewsItem(date: day(0), title: "Foderdagbok", description: "Logga måltider och snacks med tid och reaktionsanteckningar, grupperat per dag."),
            NewsItem(date: day(-1), title: "Statistik", description: "Se löpintervall, löplängd och viktutveckling som diagram, med möjlighet att logga vikt direkt från grafen."),
            NewsItem(date: day(-2), title: "Dagbok med foton", description: "Daglig symptomlogg (blödning, svullnad, aptit, energi, humör) med möjlighet att bifoga foto och se allt kopplat till en specifik kalenderdag."),
            NewsItem(date: day(-3), title: "Löpprognos och notiser", description: "Appen räknar ut nästa förväntade löp utifrån rasvärde och din hunds egen historik, och påminner dig lokalt i god tid."),
            NewsItem(date: day(-4), title: "Enhetlig hälsologg", description: "Logga veterinärbesök, vaccinationer, vägning, temperatur, mediciner, skador och anteckningar på ett och samma ställe."),
        ]
    }()

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Canine360")
                        .font(.title2.bold())
                    Text("Canine360 hjälper dig hålla koll på din hunds löpcykler, hälsa och vardag.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Appen ersätter inte veterinärvård. Kontakta alltid veterinär vid frågor om din hunds hälsa.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(Color.clear)

            Section("Senaste nytt") {
                ForEach(newsItems) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.date.formatted(date: .numeric, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(item.title)
                            .font(.headline)
                        Text(item.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Om oss")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
        }
    }
}

#Preview {
    NavigationStack {
        OmOssView()
    }
}
