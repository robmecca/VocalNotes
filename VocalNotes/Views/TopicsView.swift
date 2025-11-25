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
    @State private var selectedTopic: Topic?
    
    var body: some View {
        NavigationView {
            // Topics List (Master)
            List {
                ForEach(notesViewModel.topics) { topic in
                    Button(action: {
                        // Toggle selection - tap again to deselect
                        if selectedTopic?.id == topic.id {
                            selectedTopic = nil
                        } else {
                            selectedTopic = topic
                        }
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
                            
                            // Show checkmark when selected
                            if selectedTopic?.id == topic.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentColor)
                                    .font(.title3)
                            }
                        }
                        .padding(.vertical, 8)
                        .background(selectedTopic?.id == topic.id ? topic.color.opacity(0.1) : Color.clear)
                        .cornerRadius(8)
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
            
            // Notes for selected topic (Detail)
            if let topic = selectedTopic {
                TopicNotesView(topic: topic, notesViewModel: notesViewModel)
            } else {
                // Placeholder when no topic is selected
                VStack(spacing: 16) {
                    Image(systemName: "tag.circle")
                        .font(.system(size: 80))
                        .foregroundColor(.secondary)
                    
                    Text("Select a Topic")
                        .font(.title2.bold())
                    
                    Text("Tap a topic to see its related notes")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
            }
        }
    }
    
    private func deleteTopic(_ topic: Topic) {
        if selectedTopic?.id == topic.id {
            selectedTopic = nil
        }
        Task {
            await notesViewModel.deleteTopic(topic)
        }
    }
}

/// View showing notes for a specific topic
struct TopicNotesView: View {
    let topic: Topic
    @ObservedObject var notesViewModel: NotesViewModel
    @State private var topicNotes: [Note] = []
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with topic info
            VStack(spacing: 12) {
                Circle()
                    .fill(topic.color)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: topic.iconName ?? "tag.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 28))
                    )
                
                Text(topic.name)
                    .font(.title2.bold())
                
                Text("\(topicNotes.count) \(topicNotes.count == 1 ? "note" : "notes")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(topic.color.opacity(0.1))
            
            // Notes list
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if topicNotes.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "note.text")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("No notes in this topic")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Notes assigned to \"\(topic.name)\" will appear here")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(topicNotes) { note in
                            NavigationLink(destination: NoteDetailView(note: note, notesViewModel: notesViewModel)) {
                                NoteRowView(note: note, topics: notesViewModel.getTopics(for: note))
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteNote(note)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
        }
        .navigationTitle(topic.name)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .task {
            await loadNotes()
        }
        .onChange(of: notesViewModel.notes) { _, _ in
            // Refresh when notes change
            Task {
                await loadNotes()
            }
        }
    }
    
    private func loadNotes() async {
        isLoading = true
        do {
            topicNotes = try StorageService.shared.fetchNotes(forTopic: topic.id)
        } catch {
            print("Failed to load notes for topic: \(error)")
            topicNotes = []
        }
        isLoading = false
    }
    
    private func deleteNote(_ note: Note) {
        Task {
            await notesViewModel.deleteNote(note)
            await loadNotes()
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
                // Preview Section
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Circle()
                                .fill(selectedColor)
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Image(systemName: selectedIcon)
                                        .foregroundColor(.white)
                                        .font(.system(size: 36))
                                )
                            
                            Text(name.isEmpty ? "Topic Preview" : name)
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        .padding(.vertical, 8)
                        Spacer()
                    }
                } header: {
                    Text("Preview")
                }
                
                Section("Name") {
                    TextField("Topic Name", text: $name)
                        .textInputAutocapitalization(.words)
                }
                
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 16) {
                        ForEach(availableIcons, id: \.self) { icon in
                            Button(action: {
                                selectedIcon = icon
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(selectedIcon == icon ? selectedColor : Color(.systemGray5))
                                        .frame(width: 50, height: 50)
                                    
                                    Image(systemName: icon)
                                        .foregroundColor(selectedIcon == icon ? .white : .gray)
                                        .font(.system(size: 20))
                                    
                                    // Selection indicator
                                    if selectedIcon == icon {
                                        Circle()
                                            .stroke(Color.primary, lineWidth: 2)
                                            .frame(width: 54, height: 54)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
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
                                ZStack {
                                    Circle()
                                        .fill(color)
                                        .frame(width: 50, height: 50)
                                    
                                    // Selection indicator
                                    if selectedColor == color {
                                        Circle()
                                            .stroke(Color.primary, lineWidth: 3)
                                            .frame(width: 54, height: 54)
                                        
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.white)
                                            .font(.system(size: 16, weight: .bold))
                                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
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

