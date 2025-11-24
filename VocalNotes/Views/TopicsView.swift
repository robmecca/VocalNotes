//
//  TopicsView.swift
//  VocalNotes
//
//  Created by Roberto Mecca on 23/11/2025.
//

import SwiftUI

struct TopicsView: View {
    @ObservedObject var notesViewModel: NotesViewModel
    @State private var showingAddTopic = false
    @State private var showingEditTopic: Topic?
    
    var body: some View {
        NavigationView {
            List {
                ForEach(notesViewModel.topics) { topic in
                    Button(action: {
                        notesViewModel.filterByTopic(topic)
                    }) {
                        HStack(spacing: 16) {
                            // Color circle
                            Circle()
                                .fill(topic.color)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: topic.iconName ?? "tag.fill")
                                        .foregroundColor(.white)
                                        .font(.system(size: 18))
                                )
                            
                            // Topic info
                            VStack(alignment: .leading, spacing: 4) {
                                Text(topic.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                let noteCount = try? StorageService.shared.fetchNotes(forTopic: topic.id).count ?? 0
                                Text("\(noteCount ?? 0) notes")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            deleteTopic(topic)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        
                        Button {
                            showingEditTopic = topic
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
            }
            .navigationTitle("Topics")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddTopic = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddTopic) {
                TopicEditorSheet(notesViewModel: notesViewModel)
            }
            .sheet(item: $showingEditTopic) { topic in
                TopicEditorSheet(notesViewModel: notesViewModel, editingTopic: topic)
            }
        }
    }
    
    private func deleteTopic(_ topic: Topic) {
        Task {
            await notesViewModel.deleteTopic(topic)
        }
    }
}

struct TopicEditorSheet: View {
    @ObservedObject var notesViewModel: NotesViewModel
    var editingTopic: Topic?
    
    @State private var name: String = ""
    @State private var selectedColor: Color = .blue
    @State private var selectedIcon: String = "tag.fill"
    @Environment(\.dismiss) private var dismiss
    
    let availableIcons = [
        "tag.fill",
        "person.fill",
        "briefcase.fill",
        "lightbulb.fill",
        "book.fill",
        "heart.fill",
        "star.fill",
        "flag.fill",
        "house.fill",
        "car.fill"
    ]
    
    let availableColors: [Color] = [
        .red, .orange, .yellow, .green, .blue,
        .purple, .pink, .cyan, .indigo, .mint
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Details") {
                    TextField("Topic Name", text: $name)
                }
                
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 16) {
                        ForEach(availableIcons, id: \.self) { icon in
                            Button(action: {
                                selectedIcon = icon
                            }) {
                                Circle()
                                    .fill(selectedIcon == icon ? selectedColor : Color(.systemGray5))
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        Image(systemName: icon)
                                            .foregroundColor(selectedIcon == icon ? .white : .gray)
                                    )
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 16) {
                        ForEach(availableColors, id: \.self) { color in
                            Button(action: {
                                selectedColor = color
                            }) {
                                Circle()
                                    .fill(color)
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary, lineWidth: selectedColor == color ? 3 : 0)
                                    )
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle(editingTopic == nil ? "New Topic" : "Edit Topic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTopic()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
        .onAppear {
            if let topic = editingTopic {
                name = topic.name
                selectedColor = topic.color
                selectedIcon = topic.iconName ?? "tag.fill"
            }
        }
    }
    
    private func saveTopic() {
        Task {
            if let editingTopic = editingTopic {
                var updatedTopic = editingTopic
                updatedTopic.name = name
                updatedTopic.colorHex = selectedColor.toHex()
                updatedTopic.iconName = selectedIcon
                await notesViewModel.updateTopic(updatedTopic)
            } else {
                let newTopic = Topic(
                    name: name,
                    colorHex: selectedColor.toHex(),
                    iconName: selectedIcon
                )
                await notesViewModel.createTopic(newTopic)
            }
            dismiss()
        }
    }
}

#Preview {
    TopicsView(notesViewModel: NotesViewModel())
}

