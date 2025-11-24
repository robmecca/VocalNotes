# VocalNotes Setup Instructions

## Overview

VocalNotes is a voice-first note-taking app built with SwiftUI for iOS and iPadOS. This guide will help you configure the Xcode project to run the app successfully.

## Requirements

- Xcode 15.0 or later
- iOS 17.0+ / iPadOS 17.0+ deployment target (iOS 18+ recommended for Apple Intelligence features)
- Swift 5.9+
- Apple Developer Account (for CloudKit and device testing)

## Project Configuration

### 1. Add Files to Xcode Project

The following file structure has been created:

```
VocalNotes/
├── Models/
│   ├── Note.swift
│   ├── Topic.swift
│   └── DaySummary.swift
├── Services/
│   ├── StorageService.swift
│   ├── SpeechService.swift
│   └── IntelligenceService.swift
├── ViewModels/
│   ├── NotesViewModel.swift
│   └── CalendarViewModel.swift
├── Views/
│   ├── MainTabView.swift
│   ├── CaptureView.swift
│   ├── CalendarView.swift
│   ├── NotesListView.swift
│   ├── NoteDetailView.swift
│   ├── TopicsView.swift
│   └── Components/
│       ├── FlowLayout.swift
│       └── TopicChip.swift
├── ContentView.swift
├── VocalNotesApp.swift
├── Persistence.swift
└── VocalNotes.xcdatamodeld/
```

**Important:** Make sure to add all these new files to your Xcode project:

1. Open `VocalNotes.xcodeproj` in Xcode
2. Right-click on the VocalNotes group in the Project Navigator
3. Select "Add Files to VocalNotes..."
4. Navigate to the VocalNotes folder and select all the new folders (Models, Services, ViewModels, Views)
5. Make sure "Copy items if needed" is unchecked (files are already in the right location)
6. Make sure the VocalNotes target is checked
7. Click "Add"

### 2. Configure Info.plist Permissions

The app requires microphone and speech recognition permissions. Add these keys to your Info.plist or configure them in your target's Info section:

**In Xcode:**
1. Select the VocalNotes project in the Project Navigator
2. Select the VocalNotes target
3. Go to the "Info" tab
4. Click the "+" button to add custom iOS target properties
5. Add the following keys:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>VocalNotes needs access to your microphone to record voice notes.</string>

<key>NSSpeechRecognitionUsageDescription</key>
<string>VocalNotes uses speech recognition to transcribe your voice notes into text.</string>
```

**Or manually in Info.plist** (if you have one):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSMicrophoneUsageDescription</key>
    <string>VocalNotes needs access to your microphone to record voice notes.</string>
    <key>NSSpeechRecognitionUsageDescription</key>
    <string>VocalNotes uses speech recognition to transcribe your voice notes into text.</string>
</dict>
</plist>
```

### 3. Enable CloudKit

1. Select the VocalNotes project in Project Navigator
2. Select the VocalNotes target
3. Go to the "Signing & Capabilities" tab
4. Click "+ Capability"
5. Add "iCloud"
6. Check "CloudKit"
7. Select or create a CloudKit container (e.g., `iCloud.com.yourdomain.VocalNotes`)

### 4. Configure Background Modes (Optional)

For better sync experience:
1. In "Signing & Capabilities"
2. Add "Background Modes" capability
3. Check "Remote notifications"

### 5. Update Deployment Target

1. Select the VocalNotes project
2. Select the VocalNotes target
3. In "General" tab, set "Minimum Deployments" to iOS 17.0 or higher

## Building and Running

### First Build

1. Clean the build folder: `Product > Clean Build Folder` (⇧⌘K)
2. Build the project: `Product > Build` (⌘B)
3. If you encounter any errors about missing files, verify all Swift files are added to the target
4. Select your target device (simulator or physical device)
5. Run the app: `Product > Run` (⌘R)

### Testing on Device

To test voice recording features, you must use a physical device (microphone doesn't work in simulator):

1. Connect your iOS device
2. Select it as the target
3. Ensure your Apple ID is set in Xcode preferences
4. Run the app

### Troubleshooting

**Issue: Files not found during build**
- Solution: Make sure all new files are added to the Xcode project and have the VocalNotes target checked

**Issue: Core Data model errors**
- Solution: Open `VocalNotes.xcdatamodeld` and verify entities are present. Clean build folder and rebuild.

**Issue: Permission denied for microphone**
- Solution: Reset permissions in iOS Settings > Privacy & Security > Microphone > VocalNotes

**Issue: CloudKit sync not working**
- Solution: Ensure you're signed in to iCloud on the device and CloudKit capability is properly configured

## Features Overview

### 1. Capture Tab
- Tap the microphone button to start recording
- Speak your thoughts
- Tap again to stop
- Review transcribed text and assign topics
- Save the note

### 2. Calendar Tab
- View notes organized by date
- Month view with note indicators
- Tap any day to see notes from that day
- Color-coded by topics

### 3. Notes Tab
- Browse all notes
- Search functionality
- Filter by topics or dates
- Swipe to delete
- Tap to view details

### 4. Topics Tab
- Manage your topic categories
- Create custom topics with colors and icons
- View note count per topic
- Edit or delete topics

## Architecture

The app follows the MVVM (Model-View-ViewModel) architecture:

- **Models**: Domain entities (Note, Topic, DaySummary)
- **Services**: Business logic layers (Storage, Speech, Intelligence)
- **ViewModels**: Presentation logic and state management
- **Views**: SwiftUI user interface components
- **Core Data**: Local persistence with CloudKit sync

## Next Steps

1. **Customize App Icon**: Add your app icon in Assets.xcassets
2. **Customize Accent Color**: Modify AccentColor in Assets.xcassets
3. **Test on Device**: Build and test on a physical iOS device
4. **Configure TestFlight**: Prepare for beta testing
5. **App Store Submission**: Complete when ready for production

## Apple Intelligence Integration (Future)

Currently, the IntelligenceService uses basic text processing. When Apple Intelligence APIs become available:

1. Update `IntelligenceService.swift` to use Apple Intelligence frameworks
2. Ensure iOS 18+ deployment target
3. Test on devices with Apple Intelligence support

## Support

For issues or questions about the implementation, refer to:
- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [Core Data Documentation](https://developer.apple.com/documentation/coredata)
- [Speech Framework](https://developer.apple.com/documentation/speech)

---

**Built with ❤️ using SwiftUI**

