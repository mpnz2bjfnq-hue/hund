//
//  SignInView.swift
//  UppdragHund
//

import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "pawprint.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            Text("Logga in för att lägga till vänner")
                .font(.headline)

            Text("Din hunddata är fortfarande privat och lokal på den här enheten — inloggning behövs bara för vänfunktionen.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            SignInWithAppleButton(.signIn) { request in
                AuthService.shared.prepareSignInRequest(request)
            } onCompletion: { result in
                Task {
                    do {
                        try await AuthService.shared.handleSignIn(result)
                        errorMessage = nil
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 44)
            .padding(.horizontal, 40)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
        .padding(.vertical, 24)
    }
}

#Preview {
    SignInView()
}
