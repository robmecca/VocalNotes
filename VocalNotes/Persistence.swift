//
//  Persistence.swift
//  VocalNotes
//
//  Created by Roberto Mecca on 23/11/2025.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Create sample topics for preview
        let workTopic = CDTopic(context: viewContext)
        workTopic.id = UUID()
        workTopic.name = "Work"
        workTopic.colorHex = "#4ECDC4"
        workTopic.iconName = "briefcase.fill"
        workTopic.createdAt = Date()
        
        let personalTopic = CDTopic(context: viewContext)
        personalTopic.id = UUID()
        personalTopic.name = "Personal"
        personalTopic.colorHex = "#FF6B6B"
        personalTopic.iconName = "person.fill"
        personalTopic.createdAt = Date()
        
        // Create sample notes for preview
        for i in 0..<5 {
            let newNote = CDNote(context: viewContext)
            newNote.id = UUID()
            newNote.createdAt = Date().addingTimeInterval(TimeInterval(-i * 86400)) // Spread across days
            newNote.updatedAt = newNote.createdAt
            newNote.rawText = "Sample note \(i + 1) for preview purposes"
            newNote.cleanedText = "Sample note \(i + 1) for preview purposes."
            newNote.audioDuration = Double(60 + i * 30)
            
            // Assign topics
            if i % 2 == 0 {
                newNote.topics = NSSet(object: workTopic)
            } else {
                newNote.topics = NSSet(object: personalTopic)
            }
        }
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            print("Preview data creation error: \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "VocalNotes")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Configure CloudKit for sync
            guard let description = container.persistentStoreDescriptions.first else {
                fatalError("Failed to retrieve a persistent store description.")
            }
            
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // In production, you should handle errors gracefully
                print("Unresolved error \(error), \(error.userInfo)")
            }
        })
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}
