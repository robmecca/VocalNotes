//
//  MainTabView.swift
//  VocalNotes
//
//  Created by Roberto Mecca on 23/11/2025.
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var notesViewModel = NotesViewModel()
    @StateObject private var calendarViewModel = CalendarViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            CaptureView(notesViewModel: notesViewModel)
                .tabItem {
                    Label("Capture", systemImage: "mic.circle.fill")
                }
                .tag(0)
            
            CalendarView(
                calendarViewModel: calendarViewModel,
                notesViewModel: notesViewModel
            )
            .tabItem {
                Label("Calendar", systemImage: "calendar")
            }
            .tag(1)
            
            NotesListView(notesViewModel: notesViewModel)
                .tabItem {
                    Label("Notes", systemImage: "note.text")
                }
                .tag(2)
            
            TopicsView(notesViewModel: notesViewModel)
                .tabItem {
                    Label("Topics", systemImage: "folder.fill")
                }
                .tag(3)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(4)
        }
        .tint(.accentColor)
        .task {
            await notesViewModel.loadInitialData()
            await calendarViewModel.loadMonth()
        }
    }
}

#Preview {
    MainTabView()
}

