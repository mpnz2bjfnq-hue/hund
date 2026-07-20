//
//  DeepLinkStore.swift
//  UppdragHund
//
//  Buffrar inkommande djuplänkar (widgetarnas canine360://-URL:er).
//  Vid kallstart levereras URL:en innan MainTabView är monterad — utan
//  buffert tappas den och widgetknappen "gör ingenting". ContentView tar
//  emot URL:en direkt vid roten; MainTabView konsumerar när den finns.
//

import Foundation
import Observation

@MainActor
@Observable
final class DeepLinkStore {
    /// Delad instans så att AppDelegate (som ligger utanför SwiftUI-hierarkin
    /// och därmed inte når @Environment) kan lämna ifrån sig notistryck.
    static let shared = DeepLinkStore()

    var pending: URL?
}
