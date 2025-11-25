//
//  VocalNotesApp.swift
//  VocalNotes
//
//  Created by Roberto Mecca on 23/11/2025.
//

import SwiftUI
import CoreData

@main
struct VocalNotesApp: App {
    let persistenceController = PersistenceController.shared

    init() {
        // Set default values for user preferences on first launch
        registerDefaultSettings()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
    
    private func registerDefaultSettings() {
        let defaults = UserDefaults.standard
        let hasLaunchedBefore = defaults.bool(forKey: "hasLaunchedBefore")
        
        if !hasLaunchedBefore {
            // First launch - set defaults
            defaults.set(true, forKey: "useAIEnhancement")
            defaults.set(true, forKey: "autoEnhanceNotes")
            defaults.set(true, forKey: "hasLaunchedBefore")
            print("✅ Default settings initialized")
        }
    }
}
