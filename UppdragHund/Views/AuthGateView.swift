//
//  AuthGateView.swift
//  UppdragHund
//
//  Onboarding/inloggning som gatar hela appen. Visas tills användaren
//  är inloggad (via Apple eller e-post/lösenord).
//

import SwiftUI
import AuthenticationServices

struct AuthGateView: View {
    private enum Mode: String, CaseIterable {
        case signIn = "Logga in"
        case signUp = "Skapa konto"
    }

    @Environment(\.colorScheme) private var colorScheme
    /// Apple-knappen är en UIKit-kontroll med fast text — låt ramen växa i stället.
    @ScaledMetric(relativeTo: .body) private var appleButtonHeight: CGFloat = 52
    @State private var mode: Mode = .signUp
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var infoMessage: String?
    @State private var isWorking = false

    @FocusState private var focusedField: Field?
    private enum Field { case name, email, password }

    var body: some View {
        ZStack {
            Theme.screenSurface

            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    hero
                    modePicker
                    formCard
                    dividerRow
                    appleButton
                    Spacer(minLength: Theme.Spacing.l)
                }
                .padding(Theme.Spacing.l)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image("Canine360Logo")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 190)
                // Neonglöden lyfter loggan mot svart, men blir en grön dis
                // mot ljus botten — dämpas kraftigt där.
                .shadow(
                    color: Theme.Colors.brand.opacity(colorScheme == .dark ? 0.35 : 0.12),
                    radius: colorScheme == .dark ? 24 : 12,
                    y: 8
                )
                .accessibilityLabel("Canine360")
            Text("Håll koll på din hunds hälsa, löp, träning och vardag — och dela med vänner.")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top, Theme.Spacing.xxl)
    }

    // MARK: - Lägesväljare (glaspiller)

    private var modePicker: some View {
        HStack(spacing: 0) {
            ForEach(Mode.allCases, id: \.self) { item in
                Button {
                    withAnimation(.spring(duration: 0.3)) { mode = item }
                    errorMessage = nil
                    infoMessage = nil
                } label: {
                    Text(item.rawValue)
                        .font(Theme.Typography.caption.weight(.semibold))
                        .foregroundStyle(mode == item ? .white : Theme.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background {
                            if mode == item {
                                Capsule()
                                    .fill(Theme.Colors.brand)
                                    .matchedGeometryEffect(id: "modePill", in: pillNamespace)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.Colors.hairline, lineWidth: 0.5))
    }

    @Namespace private var pillNamespace

    // MARK: - Formulär

    private var formCard: some View {
        VStack(spacing: Theme.Spacing.m) {
            if mode == .signUp {
                authField(icon: "person", placeholder: "Namn", text: $name)
                    .textContentType(.name)
                    .focused($focusedField, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .email }
            }
            authField(icon: "envelope", placeholder: "E-post", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .email)
                .submitLabel(.next)
                .onSubmit { focusedField = .password }
            authField(icon: "lock", placeholder: "Lösenord", text: $password, secure: true)
                .textContentType(mode == .signUp ? .newPassword : .password)
                .focused($focusedField, equals: .password)
                .submitLabel(.go)
                .onSubmit { submit() }

            if let errorMessage {
                messageRow(errorMessage, icon: "exclamationmark.triangle.fill", color: Theme.Colors.warning)
            }
            if let infoMessage {
                messageRow(infoMessage, icon: "checkmark.circle.fill", color: Theme.Colors.brand)
            }

            Button {
                submit()
            } label: {
                Group {
                    if isWorking {
                        ProgressView().tint(.white)
                    } else {
                        Text(mode == .signUp ? "Skapa konto" : "Logga in")
                            .font(.body.weight(.semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(Theme.Colors.brand)
            .disabled(isWorking)
            .padding(.top, 2)

            if mode == .signIn {
                Button("Glömt lösenord?") { resetPassword() }
                    .font(.footnote)
                    .tint(Theme.Colors.brand)
                    .disabled(isWorking)
            }
        }
        .cardStyle()
    }

    /// Tonat inmatningsfält med ikon — matchar appens glas/kort-stil.
    private func authField(icon: String, placeholder: String, text: Binding<String>, secure: Bool = false) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(width: 20)
            Group {
                if secure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                }
            }
            .foregroundStyle(Theme.Colors.textPrimary)
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                .fill(Theme.Colors.fieldFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                .strokeBorder(Theme.Colors.hairline, lineWidth: 0.5)
        )
    }

    private func messageRow(_ text: String, icon: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon)
            Text(text)
            Spacer(minLength: 0)
        }
        .font(.caption)
        .foregroundStyle(color)
    }

    private var dividerRow: some View {
        HStack(spacing: Theme.Spacing.m) {
            Rectangle().fill(Theme.Colors.hairline).frame(height: 0.5)
            Text("eller")
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
            Rectangle().fill(Theme.Colors.hairline).frame(height: 0.5)
        }
    }

    private var appleButton: some View {
        SignInWithAppleButton(.signIn) { request in
            AuthService.shared.prepareSignInRequest(request)
        } onCompletion: { result in
            handleApple(result)
        }
        // Apples riktlinje: svart knapp på ljus bakgrund, vit på mörk.
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        // Knappen är en UIKit-kontroll som inte byter stil av sig själv när
        // färgläget ändras — id:t tvingar SwiftUI att skapa om den.
        .id(colorScheme)
        .frame(height: appleButtonHeight)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .disabled(isWorking)
    }

    // MARK: - Actions

    private func submit() {
        errorMessage = nil
        infoMessage = nil

        let validation = mode == .signUp
            ? EmailAuthValidator.validateSignUp(name: name, email: email, password: password)
            : EmailAuthValidator.validateSignIn(email: email, password: password)
        if let validation {
            errorMessage = validation.errorDescription
            return
        }

        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                if mode == .signUp {
                    try await AuthService.shared.signUpWithEmail(name: name, email: email, password: password)
                } else {
                    try await AuthService.shared.signInWithEmail(email: email, password: password)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func resetPassword() {
        errorMessage = nil
        infoMessage = nil
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard EmailAuthValidator.isValidEmail(trimmed) else {
            errorMessage = "Ange din e-postadress först."
            return
        }
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                try await AuthService.shared.sendPasswordReset(email: trimmed)
                infoMessage = "Vi har skickat en återställningslänk till \(trimmed)."
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        errorMessage = nil
        infoMessage = nil
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                try await AuthService.shared.handleSignIn(result)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    AuthGateView()
}
