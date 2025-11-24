//
//  CalendarView.swift
//  VocalNotes
//
//  Created by Roberto Mecca on 23/11/2025.
//

import SwiftUI

struct CalendarView: View {
    @ObservedObject var calendarViewModel: CalendarViewModel
    @ObservedObject var notesViewModel: NotesViewModel
    
    @State private var showingDayDetail = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Month header
                HStack {
                    Button(action: { calendarViewModel.moveMonth(by: -1) }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 4) {
                        Text(calendarViewModel.monthYearString)
                            .font(.title2.bold())
                        
                        Button(action: { calendarViewModel.goToToday() }) {
                            Text("Today")
                                .font(.caption)
                                .foregroundColor(.accentColor)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: { calendarViewModel.moveMonth(by: 1) }) {
                        Image(systemName: "chevron.right")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                    }
                }
                .padding()
                
                // Weekday headers
                HStack(spacing: 0) {
                    ForEach(calendarViewModel.weekDaySymbols, id: \.self) { symbol in
                        Text(symbol)
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                // Calendar grid
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                        ForEach(Array(calendarViewModel.getDaysInMonth().enumerated()), id: \.offset) { _, date in
                            CalendarDayCell(
                                date: date,
                                summary: calendarViewModel.getSummary(for: date),
                                isToday: calendarViewModel.isToday(date),
                                isSelected: calendarViewModel.isSelected(date),
                                topics: notesViewModel.topics
                            ) {
                                if let date = date {
                                    calendarViewModel.selectedDate = date
                                    notesViewModel.filterByDate(date)
                                    showingDayDetail = true
                                }
                            }
                        }
                    }
                    .padding()
                }
                
                // Quick stats
                if let selectedDate = calendarViewModel.selectedDate,
                   let summary = calendarViewModel.getSummary(for: selectedDate) {
                    VStack(spacing: 8) {
                        Divider()
                        
                        HStack(spacing: 20) {
                            StatItem(
                                icon: "note.text",
                                value: "\(summary.noteCount)",
                                label: "Notes"
                            )
                            
                            if let duration = summary.totalDuration {
                                StatItem(
                                    icon: "timer",
                                    value: formatDuration(duration),
                                    label: "Duration"
                                )
                            }
                        }
                        .padding()
                    }
                    .background(Color(.secondarySystemBackground))
                }
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingDayDetail) {
                if let selectedDate = calendarViewModel.selectedDate {
                    DayDetailView(
                        date: selectedDate,
                        notesViewModel: notesViewModel
                    )
                }
            }
            .task {
                await calendarViewModel.loadMonth()
            }
            .onChange(of: calendarViewModel.currentMonth) { _, _ in
                Task {
                    await calendarViewModel.loadMonth()
                }
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        return "\(minutes)m"
    }
}

struct CalendarDayCell: View {
    let date: Date?
    let summary: DaySummary?
    let isToday: Bool
    let isSelected: Bool
    let topics: [Topic]
    let onTap: () -> Void
    
    var body: some View {
        Button(action: {
            if date != nil {
                onTap()
            }
        }) {
            VStack(spacing: 4) {
                if let date = date {
                    Text("\(Calendar.current.component(.day, from: date))")
                        .font(.system(size: 16, weight: isToday ? .bold : .regular))
                        .foregroundColor(
                            isToday ? .white :
                            isSelected ? .accentColor :
                            .primary
                        )
                    
                    // Note indicators
                    if let summary = summary, summary.hasNotes {
                        HStack(spacing: 2) {
                            ForEach(Array(summary.topicCounts.keys.prefix(3)), id: \.self) { topicId in
                                if let topic = topics.first(where: { $0.id == topicId }) {
                                    Circle()
                                        .fill(topic.color)
                                        .frame(width: 4, height: 4)
                                }
                            }
                        }
                        .frame(height: 4)
                    } else {
                        Spacer()
                            .frame(height: 4)
                    }
                } else {
                    Color.clear
                        .frame(height: 20)
                }
            }
            .frame(height: 60)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isToday ? Color.accentColor :
                        isSelected ? Color.accentColor.opacity(0.2) :
                        summary?.hasNotes == true ? Color(.tertiarySystemBackground) :
                        Color.clear
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected ? Color.accentColor : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(date == nil)
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline)
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct DayDetailView: View {
    let date: Date
    @ObservedObject var notesViewModel: NotesViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Group {
                if notesViewModel.notes.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "note.text")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("No notes for this day")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        ForEach(notesViewModel.notes) { note in
                            NavigationLink(destination: NoteDetailView(note: note, notesViewModel: notesViewModel)) {
                                NoteRowView(note: note, topics: notesViewModel.getTopics(for: note))
                            }
                        }
                    }
                }
            }
            .navigationTitle(formatDate(date))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
}

#Preview {
    CalendarView(
        calendarViewModel: CalendarViewModel(),
        notesViewModel: NotesViewModel()
    )
}

