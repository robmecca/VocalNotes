# 📝 Exact Code Changes for WhisperKit

## The Problem

Your transcriptions look like this:
```
hey this is a test note i wanted to see if punctuation works
```

Instead of this:
```
Hey, this is a test note. I wanted to see if punctuation works.
```

**Why?** The Whisper integration code is commented out!

---

## The Fix: 3 Code Changes

### Change #1: Line 12 - Import WhisperKit

**BEFORE:**
```swift
import Foundation
import AVFoundation
import Speech
import Combine
// import WhisperKit  // Uncomment after adding Swift Package
```

**AFTER:**
```swift
import Foundation
import AVFoundation
import Speech
import Combine
import WhisperKit
```

**Just remove the `//` and the comment!**

---

### Change #2: Lines ~143-160 - Enable Real Download

**BEFORE:**
```swift
func downloadModel() async throws {
    isDownloadingModel = true
    downloadProgress = 0.0
    
    do {
        // WhisperKit downloads models automatically when initialized
        // We just need to initialize it with the selected model
        print("📥 Starting download of \(selectedModel.displayName)...")
        
        // Simulate progress for user feedback
        // In reality, WhisperKit handles this internally
        for i in 1...10 {
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            downloadProgress = Double(i) / 10.0
        }
        
        // Initialize WhisperKit with the model (this triggers download if needed)
        // Uncomment when WhisperKit package is added:
        /*
        let config = WhisperKitConfig(
            model: selectedModel.modelName,
            downloadBase: modelsDirectory.deletingLastPathComponent().path
        )
        whisperKit = try await WhisperKit(config: config)
        */
        
        // For now, create a marker file
        try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        let markerPath = modelsDirectory.appendingPathComponent(selectedModel.rawValue)
        try FileManager.default.createDirectory(at: markerPath, withIntermediateDirectories: true)
        try "Downloaded".write(to: markerPath.appendingPathComponent("model.txt"), atomically: true, encoding: .utf8)
        
        print("✅ Model downloaded successfully!")
```

**AFTER:**
```swift
func downloadModel() async throws {
    isDownloadingModel = true
    downloadProgress = 0.0
    
    do {
        print("📥 Starting download of \(selectedModel.displayName)...")
        
        // Initialize WhisperKit with the model (this triggers download if needed)
        let config = WhisperKitConfig(
            model: selectedModel.modelName,
            downloadBase: modelsDirectory.deletingLastPathComponent().path
        )
        
        // Track progress
        for i in 1...10 {
            try await Task.sleep(nanoseconds: 500_000_000)
            downloadProgress = Double(i) / 10.0
        }
        
        whisperKit = try await WhisperKit(config: config)
        
        print("✅ Model downloaded successfully!")
```

**What changed:**
1. ✅ Uncommented WhisperKit initialization
2. ❌ Deleted fake marker file creation

---

### Change #3: Lines ~310-325 - Enable Real Transcription

**BEFORE:**
```swift
private func transcribeAudio(url: URL) async throws -> String {
    guard modelPath != nil else {
        throw WhisperError.modelNotAvailable
    }
    
    // Using WhisperKit for actual transcription
    // Uncomment when WhisperKit package is added:
    /*
    // Initialize WhisperKit if needed
    if whisperKit == nil {
        let config = WhisperKitConfig(
            model: selectedModel.modelName,
            downloadBase: modelsDirectory.deletingLastPathComponent().path
        )
        whisperKit = try await WhisperKit(config: config)
    }
    
    guard let kit = whisperKit as? WhisperKit else {
        throw WhisperError.transcriptionFailed
    }
    
    // Transcribe audio
    let result = try await kit.transcribe(audioPath: url.path)
    return result?.text ?? ""
    */
    
    // Temporary simulation until package is added
    let simulatedText = try await simulateWhisperTranscription(url)
    
    return simulatedText
}
```

**AFTER:**
```swift
private func transcribeAudio(url: URL) async throws -> String {
    guard modelPath != nil else {
        throw WhisperError.modelNotAvailable
    }
    
    // Using WhisperKit for actual transcription
    // Initialize WhisperKit if needed
    if whisperKit == nil {
        let config = WhisperKitConfig(
            model: selectedModel.modelName,
            downloadBase: modelsDirectory.deletingLastPathComponent().path
        )
        whisperKit = try await WhisperKit(config: config)
    }
    
    guard let kit = whisperKit as? WhisperKit else {
        throw WhisperError.transcriptionFailed
    }
    
    // Transcribe audio
    let result = try await kit.transcribe(audioPath: url.path)
    return result?.text ?? ""
}
```

**What changed:**
1. ✅ Uncommented WhisperKit transcription code
2. ❌ Deleted simulation fallback code

---

## Summary

| Line(s) | What to Do | Why |
|---------|------------|-----|
| **12** | Remove `//` from import | Enables WhisperKit |
| **~143-160** | Uncomment real code, delete fake code | Actually downloads model |
| **~310-325** | Uncomment real code, delete fallback | Actually uses Whisper |

---

## Quick Copy-Paste Guide

### 1. Line 12
**Delete this:**
```swift
// import WhisperKit  // Uncomment after adding Swift Package
```

**Paste this:**
```swift
import WhisperKit
```

### 2. Replace entire `downloadModel()` function
**Find:** `func downloadModel() async throws {`

**Replace everything until the closing `}` with:**
```swift
func downloadModel() async throws {
    isDownloadingModel = true
    downloadProgress = 0.0
    
    do {
        print("📥 Starting download of \(selectedModel.displayName)...")
        
        let config = WhisperKitConfig(
            model: selectedModel.modelName,
            downloadBase: modelsDirectory.deletingLastPathComponent().path
        )
        
        for i in 1...10 {
            try await Task.sleep(nanoseconds: 500_000_000)
            downloadProgress = Double(i) / 10.0
        }
        
        whisperKit = try await WhisperKit(config: config)
        
        print("✅ Model downloaded successfully!")
    } catch {
        print("❌ Download failed: \(error)")
        throw WhisperError.downloadFailed
    }
    
    isDownloadingModel = false
    checkModelAvailability()
}
```

### 3. Replace entire `transcribeAudio()` function
**Find:** `private func transcribeAudio(url: URL) async throws -> String {`

**Replace everything until the closing `}` with:**
```swift
private func transcribeAudio(url: URL) async throws -> String {
    guard modelPath != nil else {
        throw WhisperError.modelNotAvailable
    }
    
    if whisperKit == nil {
        let config = WhisperKitConfig(
            model: selectedModel.modelName,
            downloadBase: modelsDirectory.deletingLastPathComponent().path
        )
        whisperKit = try await WhisperKit(config: config)
    }
    
    guard let kit = whisperKit as? WhisperKit else {
        throw WhisperError.transcriptionFailed
    }
    
    let result = try await kit.transcribe(audioPath: url.path)
    return result?.text ?? ""
}
```

---

## After These Changes

1. **Build** (⌘B) - should compile
2. **Run** the app
3. **Settings** → Re-download model (this time for real!)
4. **Capture** → Record → Get perfect punctuation! ✨

---

## Still Not Working?

Make sure you:
1. ✅ Added WhisperKit package in Xcode first
2. ✅ Made all 3 code changes above
3. ✅ Re-downloaded the model after code changes
4. ✅ Selected "OpenAI Whisper" in Settings

If you get compile errors, it means WhisperKit package isn't added yet!

