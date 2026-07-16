//
//  AccountDeletionService.swift
//  UppdragHund
//
//  Anropar Cloud Function `deleteAccount` som raderar användarens konto och
//  all data (inkl. Auth-kontot) med admin-rättigheter.
//

import Foundation
import FirebaseFunctions

final class AccountDeletionService {
    static let shared = AccountDeletionService()

    private lazy var functions = Functions.functions(region: "europe-north1")

    private init() {}

    func deleteAccount() async throws {
        _ = try await functions.httpsCallable("deleteAccount").call()
    }
}
