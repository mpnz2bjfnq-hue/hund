//
//  TeamJoinCodeViews.swift
//  UppdragHund
//
//  Inbjudningskod till team: ägare/konsulent visar och delar en kod (+ QR),
//  deltagare går med genom att ange koden — inget vänskaps-krav. Gjord för
//  hundinstruktörer som ska få in en hel kursgrupp på minuter.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

// MARK: - Visa & dela kod (ägare/konsulent)

struct TeamInviteCodeSheet: View {
    let team: Team

    @Environment(\.dismiss) private var dismiss
    @State private var code: String?
    @State private var isWorking = true
    @State private var errorMessage: String?

    /// Kod formaterad som "ABCD-EFGH" för läsbarhet.
    private var displayCode: String {
        guard let code else { return "" }
        guard code.count == 8 else { return code }
        return "\(code.prefix(4))-\(code.suffix(4))"
    }

    /// Djuplänk i QR-koden — systemkameran kan då öppna appen direkt på
    /// gå med-vyn med koden ifylld (kräver att appen är installerad).
    private var joinLink: String {
        "\(WidgetDeepLink.scheme)://team/join?code=\(code ?? "")"
    }

    private var shareText: String {
        """
        Gå med i mitt team "\(team.name)" i Canine360! 🐾
        1. Ladda ner Canine360-appen (iPhone)
           — eller öppna https://canine360-f1221.web.app (Android/dator)
        2. Gå till Team → Gå med med kod
        3. Ange koden: \(displayCode)
        """
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.l) {
                    if isWorking {
                        ProgressView()
                            .padding(.top, 60)
                    } else if let code {
                        Text("Deltagare går med genom att ange koden — de behöver inte vara vänner med dig.")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .multilineTextAlignment(.center)

                        Text(displayCode)
                            .font(.system(size: 34, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .padding(.vertical, Theme.Spacing.m)
                            .frame(maxWidth: .infinity)
                            .background(Theme.Colors.brand.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                            .contextMenu {
                                Button {
                                    UIPasteboard.general.string = displayCode
                                } label: {
                                    Label("Kopiera", systemImage: "doc.on.doc")
                                }
                            }

                        if let qr = QRCodeImage.make(from: joinLink) {
                            Image(uiImage: qr)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 180, height: 180)
                                .padding(Theme.Spacing.m)
                                .background(.white, in: RoundedRectangle(cornerRadius: 14))
                            Text("Visa QR-koden för den som ska gå med — den innehåller koden.")
                                .font(.caption2)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }

                        ShareLink(item: shareText) {
                            Label("Dela inbjudan", systemImage: "square.and.arrow.up")
                                .font(Theme.Typography.body.weight(.medium))
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.Colors.brand)

                        Button {
                            Task { await regenerate() }
                        } label: {
                            Label("Skapa ny kod", systemImage: "arrow.triangle.2.circlepath")
                                .font(Theme.Typography.body.weight(.medium))
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .tint(Theme.Colors.brand)

                        Text("En ny kod gör den gamla ogiltig — bra om koden spridits till fel personer.")
                            .font(.caption2)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(Theme.Spacing.l)
            }
            .background(Theme.screenSurface)
            .navigationTitle("Bjud in med kod")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klar") { dismiss() }
                }
            }
            .task { await loadOrCreate() }
        }
    }

    private func loadOrCreate() async {
        guard let teamID = team.id else { return }
        if let existing = await TeamsRepository.shared.joinCode(teamID: teamID) {
            code = existing
        } else {
            await regenerate()
        }
        isWorking = false
    }

    private func regenerate() async {
        guard let teamID = team.id else { return }
        do {
            code = try await TeamsRepository.shared.generateJoinCode(teamID: teamID, teamName: team.name)
            errorMessage = nil
        } catch {
            errorMessage = "Kunde inte skapa kod: \(error.localizedDescription)"
        }
    }
}

// MARK: - Gå med med kod (deltagare)

struct JoinTeamByCodeView: View {
    var onJoined: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var code: String
    @State private var isJoining = false
    @State private var errorMessage: String?
    @State private var joinedTeamName: String?
    @State private var isPresentingScanner = false

    init(initialCode: String = "", onJoined: @escaping () -> Void = {}) {
        self.onJoined = onJoined
        _code = State(initialValue: initialCode)
    }

    private var canJoin: Bool {
        code.filter(\.isLetter).count + code.filter(\.isNumber).count >= 6
    }

    /// QR:n kan innehålla antingen djuplänken (canine360://team/join?code=…)
    /// eller, från äldre koder, bara själva koden.
    static func extractCode(from scanned: String) -> String {
        if let url = URL(string: scanned),
           url.scheme == WidgetDeepLink.scheme,
           let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?
               .queryItems?.first(where: { $0.name == "code" })?.value {
            return code
        }
        return scanned
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Kod", text: $code, prompt: Text("t.ex. ABCD-EFGH"))
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(.title3, design: .monospaced))
                    if QRScannerView.isSupported {
                        Button {
                            isPresentingScanner = true
                        } label: {
                            Label("Skanna QR-kod", systemImage: "qrcode.viewfinder")
                        }
                    }
                } footer: {
                    Text("Koden får du av din hundinstruktör eller teamets ägare.")
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).font(.caption).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Gå med med kod")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Theme.Colors.brand)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
            }
            .bottomActionButton("Gå med", disabled: !canJoin, isBusy: isJoining) {
                join()
            }
            .sheet(isPresented: $isPresentingScanner) {
                NavigationStack {
                    Group {
                        if QRScannerView.isCameraBlocked {
                            // Nekad kamera ger annars bara svart bild.
                            ContentUnavailableView {
                                Label("Kameran är avstängd", systemImage: "video.slash")
                            } description: {
                                Text("Tillåt kameraåtkomst för Canine360 i Inställningar för att kunna skanna QR-koder.")
                            } actions: {
                                Button("Öppna Inställningar") {
                                    if let url = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(url)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Theme.Colors.brand)
                            }
                        } else {
                            QRScannerView { scanned in
                                code = Self.extractCode(from: scanned)
                                isPresentingScanner = false
                            }
                            .ignoresSafeArea()
                        }
                    }
                    .navigationTitle("Skanna QR-kod")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Avbryt") { isPresentingScanner = false }
                        }
                    }
                }
            }
            .alert(
                "Välkommen! 🎉",
                isPresented: Binding(
                    get: { joinedTeamName != nil },
                    set: { if !$0 { joinedTeamName = nil; dismiss() } }
                )
            ) {
                Button("OK") {
                    joinedTeamName = nil
                    dismiss()
                }
            } message: {
                Text("Du är nu med i \(joinedTeamName ?? "teamet").")
            }
        }
    }

    private func join() {
        isJoining = true
        errorMessage = nil
        Task {
            do {
                let teamName = try await TeamsRepository.shared.joinTeam(code: code)
                onJoined()
                joinedTeamName = teamName
            } catch {
                errorMessage = "Det gick inte att gå med — kontrollera koden och försök igen."
            }
            isJoining = false
        }
    }
}

// MARK: - QR-generering

enum QRCodeImage {
    /// Genererar en skarp QR-bild från en textsträng (CoreImage, inga beroenden).
    static func make(from string: String, scale: CGFloat = 12) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
