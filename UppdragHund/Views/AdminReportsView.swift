//
//  AdminReportsView.swift
//  UppdragHund
//
//  Admin: anmälningskö. Visa rapporterat innehåll, ta bort det eller
//  avfärda anmälan. Syns bara för konton i config/admins.
//

import SwiftUI

struct AdminReportsView: View {
    @State private var reports: [ContentReport] = []
    @State private var isLoading = true
    @State private var message: String?

    var body: some View {
        List {
            if reports.isEmpty {
                Text(isLoading ? "Laddar…" : "Inga anmälningar. 🎉")
                    .foregroundStyle(Theme.Colors.textSecondary)
            } else {
                ForEach(reports) { report in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label(
                                report.contentType == "comment" ? "Kommentar" : "Inlägg",
                                systemImage: report.contentType == "comment" ? "bubble.right" : "text.bubble"
                            )
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Theme.Colors.brand)
                            if report.teamId != nil {
                                Text("· team")
                                    .font(.caption2)
                                    .foregroundStyle(Theme.Colors.textSecondary)
                            }
                            Spacer()
                            Text(report.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                        Text("\u{201C}\(report.contentText)\u{201D}")
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        HStack(spacing: Theme.Spacing.m) {
                            Button(role: .destructive) {
                                removeContent(report)
                            } label: {
                                Label("Ta bort innehållet", systemImage: "trash")
                            }
                            .buttonStyle(.bordered)
                            Button {
                                dismissReport(report)
                            } label: {
                                Label("Avfärda", systemImage: "checkmark")
                            }
                            .buttonStyle(.bordered)
                            .tint(Theme.Colors.brand)
                        }
                        .controlSize(.small)
                        .padding(.top, 2)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Anmälningar")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
        .alert(
            "Klart",
            isPresented: Binding(
                get: { message != nil },
                set: { if !$0 { message = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
    }

    private func load() async {
        reports = await AdminService.shared.fetchReports()
        isLoading = false
    }

    private func removeContent(_ report: ContentReport) {
        Task {
            do {
                try await AdminService.shared.deleteReportedContent(report)
                try await AdminService.shared.dismissReport(id: report.id)
                message = "Innehållet är borttaget."
            } catch {
                message = "Kunde inte ta bort: \(error.localizedDescription)"
            }
            await load()
        }
    }

    private func dismissReport(_ report: ContentReport) {
        Task {
            try? await AdminService.shared.dismissReport(id: report.id)
            await load()
        }
    }
}
