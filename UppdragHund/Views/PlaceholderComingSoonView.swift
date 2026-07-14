//
//  PlaceholderComingSoonView.swift
//  UppdragHund
//

import SwiftUI

struct PlaceholderComingSoonView: View {
    let title: String
    let systemImage: String
    var message: String = "Den här funktionen är inte klar än."

    var body: some View {
        ContentUnavailableView(title, systemImage: systemImage, description: Text(message))
    }
}
