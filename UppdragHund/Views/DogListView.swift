//
//  DogListView.swift
//  UppdragHund
//

import SwiftUI
import SwiftData

struct DogListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ActiveDogStore.self) private var activeDogStore
    @Query(filter: #Predicate<Dog> { !$0.isShared }, sort: \Dog.name) private var allOwnDogs: [Dog]
    @Query(filter: #Predicate<Dog> { $0.isShared }, sort: \Dog.name) private var sharedDogs: [Dog]

    /// Bara det inloggade kontots egna hundar (levande).
    private var dogs: [Dog] {
        allOwnDogs.filter { $0.ownerUid == AuthService.shared.currentUserID && !$0.isDeceased }
    }

    /// Änglar: avlidna hundar, bevarade för att hedras.
    private var angelDogs: [Dog] {
        allOwnDogs.filter { $0.ownerUid == AuthService.shared.currentUserID && $0.isDeceased }
    }

    @State private var isPresentingAddDog = false
    @State private var dogPendingEdit: Dog?
    @State private var dogPendingDelete: Dog?
    @State private var dogPendingShare: Dog?
    @State private var sharedDogPendingRemoval: Dog?
    @State private var removalErrorMessage: String?

    var body: some View {
        Group {
            if dogs.isEmpty && sharedDogs.isEmpty && angelDogs.isEmpty {
                VStack(spacing: 20) {
                    Image("Canine360Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 220)
                        .accessibilityLabel("Canine360")
                    Text("Välkommen till Canine360")
                        .font(.title3.weight(.semibold))
                    Text("Lägg till din första hund för att börja logga.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section {
                        Text("Tryck på en hund för att välja den – all statistik, kalender och hälsologg följer ditt val.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Section("Mina hundar") {
                        if dogs.isEmpty {
                            Text("Inga egna hundar än.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(dogs) { dog in
                                dogRow(for: dog)
                            }
                        }
                    }

                    Section {
                        if sharedDogs.isEmpty {
                            Text("Hundar som vänner delar med dig dyker upp här.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(sharedDogs) { dog in
                                sharedDogRow(for: dog)
                            }
                        }
                    } header: {
                        Text("Delade med mig")
                    } footer: {
                        if let message = SharedDogPuller.shared.lastSyncMessage {
                            Text(message)
                                .foregroundStyle(SharedDogPuller.shared.lastSyncFailed ? .orange : .secondary)
                        }
                    }

                    if !angelDogs.isEmpty {
                        Section {
                            ForEach(angelDogs) { dog in
                                angelRow(for: dog)
                            }
                        } header: {
                            Text("Änglar 🌈 (\(angelDogs.count))")
                        } footer: {
                            Text("Alltid i våra hjärtan. All information finns kvar – tryck för att minnas.")
                        }
                    }
                }
                .refreshable {
                    await SharedDogPuller.shared.pull(context: modelContext)
                }
            }
        }
        .task {
            await SharedDogPuller.shared.pull(context: modelContext)
        }
        .navigationTitle("Hundar")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isPresentingAddDog = true
                } label: {
                    Label("Ny hund", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isPresentingAddDog) {
            AddDogView()
        }
        .sheet(item: $dogPendingEdit) { dog in
            AddDogView(dogToEdit: dog)
        }
        .sheet(item: $dogPendingShare) { dog in
            ShareDogView(dog: dog)
        }
        .confirmationDialog(
            "Ta bort \(dogPendingDelete?.name ?? "hund")?",
            isPresented: Binding(
                get: { dogPendingDelete != nil },
                set: { isPresented in
                    if !isPresented { dogPendingDelete = nil }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("Ta bort", role: .destructive) {
                if let dog = dogPendingDelete {
                    delete(dog)
                }
                dogPendingDelete = nil
            }
            Button("Avbryt", role: .cancel) {
                dogPendingDelete = nil
            }
        }
        .confirmationDialog(
            "Ta bort delningen av \(sharedDogPendingRemoval?.name ?? "hund")?",
            isPresented: Binding(
                get: { sharedDogPendingRemoval != nil },
                set: { if !$0 { sharedDogPendingRemoval = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Ta bort delning", role: .destructive) {
                if let dog = sharedDogPendingRemoval {
                    removeSharedDog(dog)
                }
                sharedDogPendingRemoval = nil
            }
            Button("Avbryt", role: .cancel) {
                sharedDogPendingRemoval = nil
            }
        } message: {
            Text("Hunden försvinner från din app. Ägarens data påverkas inte, och hen kan dela hunden med dig igen senare.")
        }
        .alert(
            "Något gick fel",
            isPresented: Binding(
                get: { removalErrorMessage != nil },
                set: { if !$0 { removalErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(removalErrorMessage ?? "")
        }
    }

    @ViewBuilder
    private func angelRow(for dog: Dog) -> some View {
        NavigationLink {
            DogProfileDetailView(dog: dog)
        } label: {
            HStack(spacing: 12) {
                DogAvatar(photoData: dog.photoData, size: 44, isActive: false)
                    .overlay(alignment: .topTrailing) {
                        Text("🌈").font(.caption2)
                    }
                    .opacity(0.85)
                VStack(alignment: .leading, spacing: 2) {
                    Text(dog.name)
                        .font(.headline)
                    Text("\(dog.breed) · \(dog.memorialYears)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .swipeActions(edge: .trailing) {
            Button {
                dogPendingEdit = dog
            } label: {
                Label("Redigera", systemImage: "pencil")
            }
            .tint(.blue)
            Button(role: .destructive) {
                dogPendingDelete = dog
            } label: {
                Label("Ta bort", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func dogRow(for dog: Dog) -> some View {
        let isActive = dog.persistentModelID == activeDogStore.activeDog?.persistentModelID

        Button {
            activeDogStore.activeDog = dog
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "pawprint.circle.fill")
                    .font(.title)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(dog.name)
                            .font(.headline)
                        if isActive {
                            Image(systemName: "checkmark")
                                .font(.subheadline.bold())
                                .foregroundStyle(.tint)
                        }
                    }
                    Text(dog.breed)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(AgeFormatter.describe(birthDate: dog.birthDate)) · Född \(dog.birthDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                dogPendingDelete = dog
            } label: {
                Label("Ta bort", systemImage: "trash")
            }

            Button {
                dogPendingEdit = dog
            } label: {
                Label("Redigera", systemImage: "pencil")
            }
            .tint(.blue)

            if !dog.isShared {
                Button {
                    dogPendingShare = dog
                } label: {
                    Label("Dela", systemImage: "square.and.arrow.up")
                }
                .tint(.indigo)
            }
        }
    }

    @ViewBuilder
    private func sharedDogRow(for dog: Dog) -> some View {
        let isActive = dog.persistentModelID == activeDogStore.activeDog?.persistentModelID

        Button {
            activeDogStore.activeDog = dog
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "pawprint.circle")
                    .font(.title)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(dog.name)
                            .font(.headline)
                        if isActive {
                            Image(systemName: "checkmark")
                                .font(.subheadline.bold())
                                .foregroundStyle(.tint)
                        }
                    }
                    Text("Delas av \(dog.ownerDisplayName ?? "vän")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let permission = dog.sharePermission {
                        Text(permission.displayName)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.tint.opacity(0.15), in: Capsule())
                    }
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                sharedDogPendingRemoval = dog
            } label: {
                Label("Ta bort delning", systemImage: "person.crop.circle.badge.xmark")
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                sharedDogPendingRemoval = dog
            } label: {
                Label("Ta bort delning", systemImage: "person.crop.circle.badge.xmark")
            }
        }
    }

    /// Mottagaren slutar följa en delad hund.
    private func removeSharedDog(_ dog: Dog) {
        let wasActive = activeDogStore.activeDog?.persistentModelID == dog.persistentModelID
        let remaining = dogs.first(where: { $0.persistentModelID != dog.persistentModelID && !$0.isShared })
        Task {
            do {
                try await DogShareService.shared.stopReceiving(dog: dog, context: modelContext)
                if wasActive {
                    activeDogStore.activeDog = remaining
                }
            } catch {
                removalErrorMessage = "Kunde inte ta bort delningen: \(error.localizedDescription)"
            }
        }
    }

    private func delete(_ dog: Dog) {
        let wasActive = activeDogStore.activeDog?.persistentModelID == dog.persistentModelID
        let remaining = dogs.first(where: { $0.persistentModelID != dog.persistentModelID })
        SyncCoordinator.shared.deleteDog(dog, in: modelContext)
        if wasActive {
            activeDogStore.activeDog = remaining
        }
    }
}

#Preview {
    NavigationStack {
        DogListView()
    }
    .environment(ActiveDogStore())
    .modelContainer(for: Dog.self, inMemory: true)
}
