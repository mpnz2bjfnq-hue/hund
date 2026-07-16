//
//  InfoPages.swift
//  UppdragHund
//
//  Små informationssidor: hur synk fungerar samt hjälp & support.
//

import SwiftUI

struct SyncInfoView: View {
    var body: some View {
        List {
            Section {
                Label {
                    Text("Dina hundars data sparas lokalt på din enhet och skyddas av iOS.")
                } icon: {
                    Image(systemName: "iphone").foregroundStyle(Theme.Colors.brand)
                }
                Label {
                    Text("Delade hundar, inlägg, team och träffar synkas automatiskt via molnet när du är inloggad.")
                } icon: {
                    Image(systemName: "icloud").foregroundStyle(Theme.Colors.brand)
                }
                Label {
                    Text("Ändringar du gör offline skickas upp nästa gång appen öppnas med nätverk.")
                } icon: {
                    Image(systemName: "arrow.triangle.2.circlepath").foregroundStyle(Theme.Colors.brand)
                }
            } footer: {
                Text("Ingen manuell backup behövs. Loggar du in på en ny enhet hämtas det som delats och synkats automatiskt.")
            }
        }
        .navigationTitle("Backup & Synk")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct HelpSupportView: View {
    @State private var authService = AuthService.shared
    @State private var currentUser = CurrentUserStore.shared
    @State private var isPresentingTicket = false
    @State private var myTickets: [SupportTicket] = []
    @State private var confirmation: String?

    var body: some View {
        List {
            Section {
                Button {
                    isPresentingTicket = true
                } label: {
                    Label("Skapa supportärende", systemImage: "ticket")
                }
            } footer: {
                Text("Ärendet skickas direkt till oss i appen och du får en notis när det är löst.")
            }

            if !myTickets.isEmpty {
                Section("Mina ärenden") {
                    ForEach(myTickets) { ticket in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(ticket.subject)
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                Spacer()
                                Text(ticket.isOpen ? "Öppet" : "Löst")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(ticket.isOpen ? .orange : Theme.Colors.brand)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(
                                        (ticket.isOpen ? Color.orange : Theme.Colors.brand).opacity(0.15),
                                        in: Capsule()
                                    )
                            }
                            Text(ticket.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                    }
                }
            }

            Section("Vanliga frågor") {
                DisclosureGroup("Hur delar jag en hund med en vän?") {
                    Text("Bli vänner först (Min profil → Vänner). Öppna sedan hunden och tryck på dela-symbolen, välj vännen och vilka delar som ska delas.")
                        .font(.footnote)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                DisclosureGroup("Varför ser jag inte en delad hund?") {
                    Text("Dra nedåt på Min profil för att uppdatera, eller tryck på synk-symbolen vid Mina hundar. Kontrollera också att du är inloggad med rätt konto.")
                        .font(.footnote)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                DisclosureGroup("Hur fungerar löp-prognosen?") {
                    Text("Prognosen beräknas utifrån hundens tidigare registrerade löp och rasens genomsnitt. Ju fler löp du registrerar, desto träffsäkrare blir den.")
                        .font(.footnote)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                DisclosureGroup("Hur tar jag bort mitt konto?") {
                    Text("Min profil → Inställningar & mer → Inställningar → Radera konto. All din data raderas permanent.")
                        .font(.footnote)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }

            Section {
                Link(destination: URL(string: "mailto:alex.ljungbergs@icloud.com?subject=Canine360%20support")!) {
                    Label("Mejla supporten", systemImage: "envelope")
                }
            } footer: {
                Text("Beskriv gärna vad som hände och vilken skärm du var på, så kan vi hjälpa dig snabbare.")
            }
        }
        .navigationTitle("Hjälp & Support")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Theme.Colors.brand)
        .task { await loadTickets() }
        .sheet(isPresented: $isPresentingTicket, onDismiss: { Task { await loadTickets() } }) {
            NewTicketView()
        }
    }

    private func loadTickets() async {
        guard let uid = authService.currentUserID else { return }
        myTickets = await SupportService.shared.myTickets(uid: uid)
    }
}

// MARK: - Nytt supportärende

struct NewTicketView: View {
    var kind: TicketKind = .support

    @Environment(\.dismiss) private var dismiss
    @State private var authService = AuthService.shared
    @State private var currentUser = CurrentUserStore.shared
    @State private var subject = ""
    @State private var message = ""
    @State private var isSending = false
    @State private var errorMessage: String?

    private var canSend: Bool {
        !subject.trimmingCharacters(in: .whitespaces).isEmpty
            && !message.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var navigationTitle: String {
        switch kind {
        case .feedback: "Skicka feedback"
        case .instructor: "Ansök om instruktörskonto"
        case .support: "Nytt ärende"
        }
    }

    private var subjectPrompt: String {
        switch kind {
        case .feedback: "t.ex. Idé: mörkare kalender"
        case .instructor: "Din verksamhet, t.ex. Hundskolan Tass, Malmö"
        case .support: "t.ex. Delad hund syns inte"
        }
    }

    private var messageLabel: String {
        switch kind {
        case .feedback: "Berätta vad du tycker"
        case .instructor: "Berätta om din verksamhet"
        case .support: "Beskriv problemet"
        }
    }

    private var footerText: String {
        switch kind {
        case .feedback: "Idéer, beröm eller gnäll – allt är välkommet och går direkt till oss."
        case .instructor: "Beskriv vad du gör (kurser, konsultationer), hur länge du hållit på och gärna en länk till hemsida/Instagram. Vi återkommer med en notis när ansökan är granskad."
        case .support: "Beskriv gärna vilken skärm du var på och vad som hände."
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Ämne", text: $subject, prompt: Text(subjectPrompt))
                    TextField(messageLabel, text: $message, axis: .vertical)
                        .lineLimit(4...10)
                } footer: {
                    Text(footerText)
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).font(.caption).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .tint(Theme.Colors.brand)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
            }
            .bottomActionButton("Skicka", disabled: !canSend, isBusy: isSending) {
                send()
            }
        }
    }

    private func send() {
        guard let uid = authService.currentUserID else { return }
        isSending = true
        Task {
            do {
                try await SupportService.shared.createTicket(
                    kind: kind,
                    subject: subject.trimmingCharacters(in: .whitespaces),
                    message: message.trimmingCharacters(in: .whitespaces),
                    uid: uid,
                    name: currentUser.profile?.displayName ?? "Hundägare"
                )
                dismiss()
            } catch {
                errorMessage = "Kunde inte skicka: \(error.localizedDescription)"
                isSending = false
            }
        }
    }
}
