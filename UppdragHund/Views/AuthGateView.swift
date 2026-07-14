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

    @State private var mode: Mode = .signUp
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var infoMessage: String?
    @State private var isWorking = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image("Canine360Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 200)
                        .accessibilityLabel("Canine360")
                    Text("Skapa ett konto för att komma igång med Canine360.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)

                Picker("Läge", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .onChange(of: mode) {
                    errorMessage = nil
                    infoMessage = nil
                }

                VStack(spacing: 12) {
                    if mode == .signUp {
                        TextField("Namn", text: $name)
                            .textContentType(.name)
                            .textFieldStyle(.roundedBorder)
                    }
                    TextField("E-post", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                    SecureField("Lösenord", text: $password)
                        .textContentType(mode == .signUp ? .newPassword : .password)
                        .textFieldStyle(.roundedBorder)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if let infoMessage {
                        Text(infoMessage)
                            .font(.caption)
                            .foregroundStyle(.green)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        submit()
                    } label: {
                        if isWorking {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(mode == .signUp ? "Skapa konto" : "Logga in")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isWorking)

                    if mode == .signIn {
                        Button("Glömt lösenord?") {
                            resetPassword()
                        }
                        .font(.footnote)
                        .disabled(isWorking)
                    }
                }
                .padding(.horizontal)

                HStack {
                    VStack { Divider() }
                    Text("eller").font(.caption).foregroundStyle(.secondary)
                    VStack { Divider() }
                }
                .padding(.horizontal)

                SignInWithAppleButton(.signIn) { request in
                    AuthService.shared.prepareSignInRequest(request)
                } onCompletion: { result in
                    handleApple(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .padding(.horizontal)
                .disabled(isWorking)

                Spacer(minLength: 20)
            }
        }
        .scrollDismissesKeyboard(.interactively)
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
