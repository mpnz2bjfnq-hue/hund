//
//  DogListView.swift
//  UppdragHund
//

import SwiftUI
import SwiftData

struct DogListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ActiveDogStore.self) private var activeDogStore
    @Query(filter: #Predicate<Dog> { !$0.isShared }, sort: \Dog.name) private var dogs: [Dog]
    @Query(filter: #Predicate<Dog> { $0.isShared }, sort: \Dog.name) private var sharedDogs: [Dog]

    @State private var isPresentingAddDog = false
    @State private var dogPendingEdit: Dog?
    @State private var dogPendingDelete: Dog?
    @State private var dogPendingShare: Dog?

    var body: some View {
        Group {
            if dogs.isEmpty && sharedDogs.isEmpty {
                ContentUnavailableView(
                    "Inga hundar än",
                    systemImage: "pawprint",
                    description: Text("Lägg till din första hund för att börja logga.")
                )
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

                    Section("Delade med mig") {
                        if sharedDogs.isEmpty {
                            Text("Hundar som vänner delar med dig dyker upp här.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(sharedDogs) { dog in
                                sharedDogRow(for: dog)
                            }
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
    }

    private func delete(_ dog: Dog) {
        let wasActive = activeDogStore.activeDog?.persistentModelID == dog.persistentModelID
        let remaining = dogs.first(where: { $0.persistentModelID != dog.persistentModelID })
        modelContext.delete(dog)
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
