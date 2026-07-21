//
//  DogProfileDetailView.swift
//  UppdragHund
//
//  Hund-profil i detalj: foto, identitet och registreringsinformation.
//  Verifierad-bocken visas när hunden har ett registreringsnummer.
//

import SwiftUI
import SwiftData

struct DogProfileDetailView: View {
    let dog: Dog

    @State private var currentUser = CurrentUserStore.shared
    @State private var isEditing = false
    @State private var didCopyReg = false
    @State private var didCopyInsurance = false

    private var isRegistered: Bool {
        dog.registrationNumber?.isEmpty == false
    }

    /// Försäkringskortet visas bara på egna hundar (uppgifterna är ägarens),
    /// och bara när minst ett fält är ifyllt.
    private var showsInsurance: Bool {
        !dog.isShared && (
            dog.insuranceCompany?.isEmpty == false ||
            dog.insuranceNumber?.isEmpty == false ||
            dog.insurancePhone?.isEmpty == false ||
            dog.insuranceRenewalDate != nil
        )
    }

    private var ownerName: String? {
        dog.isShared ? dog.ownerDisplayName : currentUser.profile?.displayName
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                if dog.isDeceased {
                    memorialBanner
                }
                heroCard
                if showsInsurance {
                    insuranceCard
                }
                informationCard
            }
            .padding(Theme.Spacing.l)
        }
        .frame(maxWidth: .infinity)
        .background(Theme.screenSurface)
        .navigationTitle(dog.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !dog.isShared {
                ToolbarItem(placement: .primaryAction) {
                    Button("Redigera") { isEditing = true }
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            AddDogView(dogToEdit: dog)
        }
    }

    /// Minnesbanner för änglar 🌈 — visar levnadsperioden.
    private var memorialBanner: some View {
        VStack(spacing: 4) {
            Text("🌈")
                .font(.title)
            Text("Till minne av \(dog.name)")
                .font(Theme.Typography.body.weight(.semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("\(dog.memorialYears) · alltid i våra hjärtan")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    // MARK: - Hero

    private var heroCard: some View {
        VStack(spacing: Theme.Spacing.m) {
            DogAvatar(photoData: dog.photoData, size: 120, isActive: true)

            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Text(dog.name)
                        .font(.title.bold())
                        .foregroundStyle(Theme.Colors.textPrimary)
                    if isRegistered {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.title3)
                            .foregroundStyle(Theme.Colors.verified)
                            .accessibilityLabel("Registrerad")
                    }
                }

                Text("\(dog.breed) · \(dog.sex.displayName)")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)

                Text("Född \(dog.birthDate.formatted(date: .abbreviated, time: .omitted)) · \(AgeFormatter.describe(birthDate: dog.birthDate))")
                    .font(Theme.Typography.footnote)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            if let reg = dog.registrationNumber, !reg.isEmpty {
                Button {
                    UIPasteboard.general.string = reg
                    withAnimation { didCopyReg = true }
                } label: {
                    HStack(spacing: 6) {
                        Text(reg)
                            .font(.footnote.monospaced())
                        Image(systemName: didCopyReg ? "checkmark" : "doc.on.doc")
                            .font(.caption)
                    }
                    .foregroundStyle(Theme.Colors.brand)
                    .padding(.horizontal, Theme.Spacing.m)
                    .padding(.vertical, 6)
                    .background(Theme.Colors.brand.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Kopiera registreringsnummer")
            }

            DogBadgeRow(badges: DogBadge.badges(for: dog))
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .cardStyle(padding: Theme.Spacing.xl)
    }

    // MARK: - Försäkring

    private var insuranceCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack(spacing: 6) {
                Image(systemName: "shield.checkered")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.verified)
                Text("Försäkring")
                    .font(Theme.Typography.sectionTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)
            }

            if let company = dog.insuranceCompany, !company.isEmpty {
                Text(company)
                    .font(Theme.Typography.body.weight(.semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
            }

            if let renewal = dog.insuranceRenewalDate {
                HStack {
                    Text("Förnyas")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Spacer()
                    Text(renewal.formatted(date: .abbreviated, time: .omitted))
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
            }

            HStack(spacing: Theme.Spacing.m) {
                if let number = dog.insuranceNumber, !number.isEmpty {
                    Button {
                        UIPasteboard.general.string = number
                        withAnimation { didCopyInsurance = true }
                    } label: {
                        HStack(spacing: 6) {
                            Text(number)
                                .font(.footnote.monospaced())
                                .lineLimit(1)
                            Image(systemName: didCopyInsurance ? "checkmark" : "doc.on.doc")
                                .font(.caption)
                        }
                        .foregroundStyle(Theme.Colors.verified)
                        .padding(.horizontal, Theme.Spacing.m)
                        .padding(.vertical, 6)
                        .background(Theme.Colors.verified.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Kopiera försäkringsnummer")
                }

                if let phoneURL = insurancePhoneURL {
                    Link(destination: phoneURL) {
                        HStack(spacing: 6) {
                            Image(systemName: "phone.fill")
                                .font(.caption)
                            Text("Ring bolaget")
                                .font(.footnote.weight(.semibold))
                        }
                        .foregroundStyle(Theme.Colors.brand)
                        .padding(.horizontal, Theme.Spacing.m)
                        .padding(.vertical, 6)
                        .background(Theme.Colors.brand.opacity(0.12), in: Capsule())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    /// tel:-URL av telefonnumret (siffror, + och # behålls — mellanslag/bindestreck rensas).
    private var insurancePhoneURL: URL? {
        guard let phone = dog.insurancePhone, !phone.isEmpty else { return nil }
        let cleaned = phone.filter { $0.isNumber || $0 == "+" || $0 == "#" || $0 == "*" }
        guard !cleaned.isEmpty else { return nil }
        return URL(string: "tel:\(cleaned)")
    }

    // MARK: - Information

    private var informationCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("Information")
                .font(Theme.Typography.sectionTitle)
                .foregroundStyle(Theme.Colors.textPrimary)

            VStack(spacing: 0) {
                let rows = infoRows
                if rows.isEmpty {
                    Text("Ingen registreringsinformation tillagd än.")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                        HStack {
                            Text(row.label)
                                .font(Theme.Typography.body)
                                .foregroundStyle(Theme.Colors.textSecondary)
                            Spacer()
                            Text(row.value)
                                .font(Theme.Typography.body)
                                .foregroundStyle(Theme.Colors.textPrimary)
                                .multilineTextAlignment(.trailing)
                        }
                        .padding(.vertical, Theme.Spacing.m)
                        if index < rows.count - 1 {
                            Divider().overlay(Theme.Colors.textSecondary.opacity(0.2))
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private struct InfoRow {
        let label: String
        let value: String
    }

    private var infoRows: [InfoRow] {
        var rows: [InfoRow] = []
        if let color = dog.color, !color.isEmpty { rows.append(InfoRow(label: "Färg", value: color)) }
        if let breeder = dog.breeder, !breeder.isEmpty { rows.append(InfoRow(label: "Uppfödare", value: breeder)) }
        if let owner = ownerName, !owner.isEmpty { rows.append(InfoRow(label: "Ägare", value: owner)) }
        if let chip = dog.chipNumber, !chip.isEmpty { rows.append(InfoRow(label: "Chipnummer", value: chip)) }
        return rows
    }
}

#Preview {
    NavigationStack {
        DogProfileDetailView(dog: Dog(name: "Sixten", breed: "Malinois", birthDate: .now, sex: .male))
    }
    .modelContainer(for: Dog.self, inMemory: true)
}
