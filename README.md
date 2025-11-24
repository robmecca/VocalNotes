# VocalNotes

A beautiful, voice-first note-taking app for iOS and iPadOS that turns your spoken thoughts into structured, searchable knowledge.

## Features

### 🎤 Voice Capture
- **One-tap recording** - Start capturing your thoughts instantly
- **Real-time transcription** - See your words appear as you speak
- **Audio playback** - Revisit original recordings anytime
- **Smart enhancement** - Automatic text cleaning and summarization

### 📅 Calendar Visualization
- **Beautiful month view** - See your thinking history at a glance
- **Day detail** - Review all notes from any specific day
- **Visual indicators** - Color-coded dots show note counts and topics
- **Quick navigation** - Jump to today or any date effortlessly

### 🏷️ Topic Organization
- **Custom topics** - Create categories with colors and icons
- **Auto-suggestions** - Smart topic recommendations based on content
- **Easy filtering** - View notes by topic or date range
- **Visual management** - Beautiful topic cards with note counts

### 🔍 Powerful Search
- **Full-text search** - Find notes by any keyword
- **Smart filters** - Combine topics and dates
- **Instant results** - Fast search across all notes

### ☁️ iCloud Sync
- **Seamless sync** - Your notes across all your devices
- **Privacy-first** - All data stored in your personal iCloud
- **Offline capable** - Record and access notes anywhere

## Screenshots

*(Add screenshots here)*

## Technology Stack

- **SwiftUI** - Modern, declarative UI framework
- **Core Data + CloudKit** - Robust data persistence and sync
- **Speech Framework** - Apple's speech recognition
- **MVVM Architecture** - Clean, maintainable code structure
- **iOS 17+ / iPadOS 17+** - Latest Apple technologies

## Getting Started

See [SETUP_INSTRUCTIONS.md](SETUP_INSTRUCTIONS.md) for detailed setup and configuration instructions.

### Quick Start

1. Clone the repository
2. Open `VocalNotes.xcodeproj` in Xcode
3. Add all source files to the project
4. Configure permissions in Info.plist
5. Enable CloudKit capability
6. Build and run on your device

## Project Structure

```
VocalNotes/
├── Models/              # Domain entities
├── Services/            # Business logic
├── ViewModels/          # Presentation logic
├── Views/               # SwiftUI UI components
│   ├── Components/      # Reusable UI elements
│   └── ...
├── Persistence.swift    # Core Data stack
└── VocalNotesApp.swift  # App entry point
```

## Design Philosophy

VocalNotes is designed around three core principles:

1. **Voice-First** - Speaking is faster and more natural than typing
2. **Visual Memory** - See your thoughts organized in time
3. **Smart Organization** - Automatic categorization with manual control

## Future Enhancements

- [ ] Apple Intelligence integration for advanced summarization
- [ ] Action item detection and extraction
- [ ] Sharing and collaboration features
- [ ] Export to PDF, Markdown, and other formats
- [ ] Week/timeline view for calendar
- [ ] Widgets for quick capture
- [ ] Apple Watch companion app
- [ ] Siri shortcuts integration

## Requirements

- iOS 17.0+ / iPadOS 17.0+
- Xcode 15.0+
- Swift 5.9+
- Apple Developer Account (for CloudKit)

## Privacy

VocalNotes is built with privacy at its core:
- All voice recordings are processed locally on-device
- Notes are stored in your personal iCloud account
- No data is sent to third-party servers
- You maintain full control of your data

## License

*(Add your license here)*

## Contributing

*(Add contribution guidelines if applicable)*

## Support

For setup help, see [SETUP_INSTRUCTIONS.md](SETUP_INSTRUCTIONS.md)

For issues and feature requests, please create an issue in the repository.

---

Built with ❤️ using SwiftUI

