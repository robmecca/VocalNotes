//
//  WhisperService.swift
//  VocalNotes
//
//  Created by AI Assistant on 24/11/2025.
//

import Foundation
import AVFoundation
import Speech
import Combine
import CoreML
#if canImport(WhisperKit)
import WhisperKit
#endif

// MARK: - Fallback Speech Recognition
/// Uses Apple's built-in speech recognition as fallback when WhisperKit is not available
@MainActor
class FallbackSpeechRecognizer: NSObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    
    var onPartialResult: ((String) -> Void)?
    
    override init() {
        super.init()
    }
    
    // For live streaming transcription
    func startLiveTranscription(audioEngine: AVAudioEngine) throws {
        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false // Use cloud for better results
        
        self.recognitionRequest = request
        self.audioEngine = audioEngine
        
        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            if let result = result {
                let transcription = result.bestTranscription.formattedString
                Task { @MainActor in
                    self?.onPartialResult?(transcription)
                }
            }
            
            if error != nil {
                self?.stopLiveTranscription()
            }
        }
        
        // Tap into audio and feed to recognition
        let recordingFormat = audioEngine.inputNode.outputFormat(forBus: 0)
        audioEngine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
    }
    
    func stopLiveTranscription() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
    }
    
    // For transcribing completed audio file
    func transcribe(audioURL: URL) async throws -> String {
        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false
        
        return try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false
            
            speechRecognizer?.recognitionTask(with: request) { result, error in
                if let error = error, !hasResumed {
                    hasResumed = true
                    continuation.resume(throwing: error)
                    return
                }
                
                if let result = result, result.isFinal, !hasResumed {
                    hasResumed = true
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }
}

/// Service for speech recognition using OpenAI Whisper Core ML
@MainActor
class WhisperService: ObservableObject {
    static let shared = WhisperService()
    
    @Published var isRecording = false
    @Published var transcribedText = ""
    @Published var isModelAvailable = false
    @Published var isDownloadingModel = false
    @Published var downloadProgress: Double = 0.0
    @Published var recognitionError: String?
    
    private var audioEngine: AVAudioEngine?
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var recordingStartTime: Date?
    
    // Whisper model configuration
    enum WhisperModel: String, CaseIterable {
        case tiny = "openai_whisper-tiny"
        case base = "openai_whisper-base"
        case small = "openai_whisper-small"
        case medium = "openai_whisper-medium"
        case large = "openai_whisper-large-v2"
        
        var displayName: String {
            switch self {
            case .tiny: return "Tiny (75 MB)"
            case .base: return "Base (140 MB)"
            case .small: return "Small (480 MB)"
            case .medium: return "Medium (1.5 GB) - Recommended"
            case .large: return "Large (3 GB)"
            }
        }
        
        var size: String {
            switch self {
            case .tiny: return "75 MB"
            case .base: return "140 MB"
            case .small: return "480 MB"
            case .medium: return "1.5 GB"
            case .large: return "3 GB"
            }
        }
        
        var modelName: String {
            return rawValue
        }
    }
    
    @Published var selectedModel: WhisperModel = .medium {
        didSet {
            UserDefaults.standard.set(selectedModel.rawValue, forKey: "whisperModel")
            // Clear the old model instance when switching models
            whisperKit = nil
            checkModelAvailability()
            
            // Pre-load the new model if available
            if isModelAvailable {
                Task {
                    await preloadModel()
                }
            }
        }
    }
    
    private var modelsDirectory: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        // WhisperKit creates its own structure: models/argmaxinc/whisperkit-coreml
        // So we just need to provide the base directory
        return documentsPath.appendingPathComponent("huggingface")
    }
    
    private var modelPath: URL? {
        // WhisperKit downloads to: <base>/models/argmaxinc/whisperkit-coreml/<model-name>
        let whisperKitPath = modelsDirectory.appendingPathComponent("models/argmaxinc/whisperkit-coreml")
        let modelFolder = whisperKitPath.appendingPathComponent(selectedModel.rawValue)
        return isValidModelDirectory(modelFolder) ? modelFolder : nil
    }
    
    // WhisperKit instance (lazy loaded)
    private var whisperKit: Any? // WhisperKit when the package is available
    
    // Fallback speech recognizer for when WhisperKit is not available
    private let fallbackRecognizer = FallbackSpeechRecognizer()
    
    init() {
        // Load saved model preference
        if let savedModel = UserDefaults.standard.string(forKey: "whisperModel"),
           let model = WhisperModel(rawValue: savedModel) {
            selectedModel = model
        }
        
        setupAudioSession()
        checkModelAvailability()
        
        // Pre-load model if available
        if isModelAvailable {
            Task {
                await preloadModel()
            }
        }
    }
    
    // MARK: - Permissions
    
    func requestAuthorization() async -> Bool {
        let micPermission = await requestMicrophonePermission()
        let speechPermission = await requestSpeechPermission()
        return micPermission && speechPermission
    }
    
    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    private func requestSpeechPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
    
    // MARK: - Model Management
    
    func checkModelAvailability() {
        print("🔍 Checking model availability for: \(selectedModel.displayName)")
        let whisperKitPath = modelsDirectory.appendingPathComponent("models/argmaxinc/whisperkit-coreml")
        let expectedDir = whisperKitPath.appendingPathComponent(selectedModel.rawValue)
        print("📁 Expected model directory: \(expectedDir.path)")
        
        if let validPath = modelPath {
            print("✅ Model found at: \(validPath.path)")
            isModelAvailable = true
            return
        }
        
        print("⚠️ Model not found at expected location")
        
        // If we have a folder with only placeholder files, clean it up so the user can download again
        if FileManager.default.fileExists(atPath: expectedDir.path) {
            if !isValidModelDirectory(expectedDir) {
                print("🗑️ Cleaning up invalid model directory: \(expectedDir.path)")
                try? FileManager.default.removeItem(at: expectedDir)
            } else {
                print("🤔 Directory exists and is valid, but modelPath returned nil. Investigating...")
                if let contents = try? FileManager.default.contentsOfDirectory(atPath: expectedDir.path) {
                    print("📂 Directory contents: \(contents.joined(separator: ", "))")
                }
            }
        } else {
            print("📁 Model directory does not exist yet")
        }
        
        isModelAvailable = false
    }
    
    /// Pre-load the WhisperKit model to avoid loading delays during transcription
    func preloadModel() async {
        guard isModelAvailable, whisperKit == nil else {
            if whisperKit != nil {
                print("✅ WhisperKit already loaded in memory")
            }
            return
        }
        
        print("🚀 Pre-loading WhisperKit model for faster transcription...")
        
        do {
#if canImport(WhisperKit)
            let computeOptions = ModelComputeOptions(
                audioEncoderCompute: .cpuAndGPU,
                textDecoderCompute: .cpuAndGPU
            )
            
            let config = WhisperKitConfig(
                model: selectedModel.modelName,
                downloadBase: modelsDirectory,
                computeOptions: computeOptions,
                prewarm: true, // Prewarm the model for faster first inference
                load: true,
                download: false // Don't download, we're loading existing model
            )
            
            whisperKit = try await WhisperKit(config)
            print("✅ WhisperKit pre-loaded successfully (ready for fast transcription)")
#endif
        } catch {
            print("⚠️ Failed to pre-load WhisperKit: \(error)")
        }
    }
    
    func downloadModel() async throws {
        isDownloadingModel = true
        downloadProgress = 0.0
        
        do {
            print("📥 Starting download of \(selectedModel.displayName)...")
            print("📁 Download base directory: \(modelsDirectory.path)")
            let expectedPath = modelsDirectory.appendingPathComponent("models/argmaxinc/whisperkit-coreml/\(selectedModel.rawValue)")
            print("📁 Expected model path: \(expectedPath.path)")
            
#if canImport(WhisperKit)
            // WhisperKit will handle the actual download when initialized
            // Pass the base directory - WhisperKit will create: models/argmaxinc/whisperkit-coreml/<model>
            
            // Configure compute options to avoid ANE issues on simulator/incompatible devices
            let computeOptions = ModelComputeOptions(
                audioEncoderCompute: .cpuAndGPU,
                textDecoderCompute: .cpuAndGPU
            )
            
            let config = WhisperKitConfig(
                model: selectedModel.modelName,
                downloadBase: modelsDirectory,
                computeOptions: computeOptions,
                prewarm: false, // Don't prewarm yet to save time
                download: true // Explicitly enable download
            )
            
            // Show simulated progress during download
            Task {
                for step in stride(from: 0.1, through: 0.9, by: 0.1) {
                    if !isDownloadingModel { break }
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    await MainActor.run {
                        downloadProgress = step
                    }
                }
            }
            
            // This will download the model if not present
            print("🔧 Initializing WhisperKit with CPU/GPU compute options...")
            whisperKit = try await WhisperKit(config)
            downloadProgress = 1.0
            
            // Verify the model was actually downloaded
            print("✅ WhisperKit initialized successfully with CPU/GPU compute")
            
            // List what's actually in the models directory
            let whisperKitBase = modelsDirectory.appendingPathComponent("models/argmaxinc/whisperkit-coreml")
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: whisperKitBase.path) {
                print("📂 Contents of whisperkit-coreml directory: \(contents)")
            }
            
            let modelDir = whisperKitBase.appendingPathComponent(selectedModel.rawValue)
            if FileManager.default.fileExists(atPath: modelDir.path) {
                let files = try? FileManager.default.contentsOfDirectory(atPath: modelDir.path)
                print("✅ Model found at expected path with \(files?.count ?? 0) files")
            } else {
                print("⚠️ Model not found at expected path: \(modelDir.path)")
            }
            
#else
            print("❌ WhisperKit package not available. Please add the Swift Package dependency.")
            throw WhisperError.whisperKitUnavailable
#endif
            
        } catch let whisperError as WhisperError {
            print("❌ Download failed: \(whisperError)")
            downloadProgress = 0.0
            isDownloadingModel = false
            throw whisperError
        } catch {
            print("❌ Download failed with error: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            downloadProgress = 0.0
            isDownloadingModel = false
            throw WhisperError.downloadFailed
        }
        
        isDownloadingModel = false
        checkModelAvailability()
        
        if !isModelAvailable {
            print("⚠️ Model availability check failed after download!")
            print("📁 Checking model path: \(modelPath?.path ?? "nil")")
        } else {
            print("✅ Model is now available!")
            // Pre-load the model for faster first use
            await preloadModel()
        }
    }
    
    func deleteModel() throws {
        let whisperKitPath = modelsDirectory.appendingPathComponent("models/argmaxinc/whisperkit-coreml")
        let modelFolder = whisperKitPath.appendingPathComponent(selectedModel.rawValue)
        let path = modelPath ?? modelFolder
        if FileManager.default.fileExists(atPath: path.path) {
            try FileManager.default.removeItem(at: path)
            print("🗑️ Deleted model at: \(path.path)")
        }
        whisperKit = nil
        checkModelAvailability()
    }
    
    // MARK: - Audio Setup
    
    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    // MARK: - Recording
    
    func startRecording() async throws -> Bool {
        // Setup recording URL
        let timestamp = Date().timeIntervalSince1970
        let filename = "recording_\(timestamp).wav"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        recordingURL = documentsPath.appendingPathComponent(filename)
        
        guard let url = recordingURL else { return false }
        
        // Configure audio settings for Whisper (16kHz mono WAV)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ]
        
        do {
            // Setup audio engine for live transcription
            audioEngine = AVAudioEngine()
            
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.record()
            
            isRecording = true
            recordingStartTime = Date()
            transcribedText = ""
            recognitionError = nil
            
            // Start live transcription with streaming (for fallback mode)
            if !isModelAvailable {
                print("📱 Using Apple Speech Recognition with streaming...")
                try startLiveStreamingTranscription()
            } else {
                print("🧠 Whisper model available - will transcribe after recording")
                // Note: Real Whisper will do batch transcription at the end
                // Live transcription with Whisper would require streaming API
            }
            
            return true
        } catch {
            recognitionError = "Failed to start recording: \(error.localizedDescription)"
            return false
        }
    }
    
    func stopRecording() async throws -> (transcribedText: String, audioFileURL: URL?, duration: TimeInterval?) {
        isRecording = false
        
        // Stop live streaming transcription
        stopLiveStreamingTranscription()
        
        audioRecorder?.stop()
        
        let duration = recordingStartTime.map { Date().timeIntervalSince($0) }
        
        guard let audioURL = recordingURL else {
            throw WhisperError.noRecording
        }
        
        // Get raw transcription first
        print("📝 Finalizing transcription from complete audio...")
        var rawText: String
        do {
            rawText = try await transcribeAudio(url: audioURL)
            print("✅ Raw transcription: \(rawText.prefix(50))...")
        } catch {
            print("⚠️ Transcription failed, using streaming result: \(error)")
            rawText = transcribedText.isEmpty ? "No transcription available" : transcribedText
        }
        
        // TEMPORARILY DISABLED: Text enhancement to test raw WhisperKit output
        /*
        print("✨ Auto-enhancing transcription with AI...")
        let finalText: String
        do {
            finalText = try await IntelligenceService.shared.cleanText(rawText)
            print("✅ Enhanced transcription: \(finalText.prefix(50))...")
        } catch {
            print("⚠️ Enhancement failed, using raw text: \(error)")
            finalText = rawText
        }
        */
        
        // Using raw WhisperKit output only
        print("🎯 Returning raw WhisperKit transcription (no enhancement)")
        transcribedText = rawText
        
        return (rawText, audioURL, duration)
    }
    
    // MARK: - Transcription
    
    private func startLiveStreamingTranscription() throws {
        guard let engine = audioEngine else { return }
        
        // Start audio engine
        try engine.start()
        
        // Configure fallback recognizer for streaming
        fallbackRecognizer.onPartialResult = { [weak self] text in
            Task { @MainActor in
                self?.transcribedText = text
                print("🔄 Live transcription: \(text.prefix(50))...")
            }
        }
        
        try fallbackRecognizer.startLiveTranscription(audioEngine: engine)
    }
    
    private func stopLiveStreamingTranscription() {
        fallbackRecognizer.stopLiveTranscription()
        audioEngine?.stop()
        audioEngine = nil
    }
    
    private func transcribeAudio(url: URL) async throws -> String {
#if canImport(WhisperKit)
        let hasLocalModel = modelPath != nil || whisperKit != nil
        
        if hasLocalModel {
            // Initialize WhisperKit if needed (should be pre-loaded)
            if whisperKit == nil {
                print("⚠️ WhisperKit not pre-loaded, loading now (this may take ~10 seconds)...")
                // Configure compute options to avoid ANE issues
                let computeOptions = ModelComputeOptions(
                    audioEncoderCompute: .cpuAndGPU,
                    textDecoderCompute: .cpuAndGPU
                )
                
                let config = WhisperKitConfig(
                    model: selectedModel.modelName,
                    downloadBase: modelsDirectory,
                    computeOptions: computeOptions,
                    prewarm: true
                )
                whisperKit = try await WhisperKit(config)
                print("✅ WhisperKit loaded")
            } else {
                print("⚡️ Using pre-loaded WhisperKit (fast path)")
            }
            
            if let kit = whisperKit as? WhisperKit {
                print("🎤 Starting Whisper transcription for: \(url.lastPathComponent)")
                let startTime = Date()
                let results = await kit.transcribe(audioPaths: [url.path])
                let elapsed = Date().timeIntervalSince(startTime)
                print("⏱️ Transcription completed in \(String(format: "%.2f", elapsed))s")
                print("📊 Transcription results received: \(results.count) result(s)")
                
                if let resultArray = results.first {
                    print("📝 First result array has \(resultArray?.count ?? 0) segments")
                    if let firstResult = resultArray?.first {
                        print("✅ First segment text: \"\(firstResult.text.prefix(100))...\"")
                        if !firstResult.text.isEmpty {
                            return firstResult.text
                        } else {
                            print("⚠️ Transcription text is empty")
                        }
                    } else {
                        print("⚠️ No results in first array")
                    }
                } else {
                    print("⚠️ No result arrays returned")
                }
            } else {
                print("❌ WhisperKit cast failed or whisperKit is nil")
            }
        }
        
        // If WhisperKit isn't available or returns empty, fall back to Apple speech
        print("⚠️ Falling back to Apple Speech Recognition")
        return try await simulateWhisperTranscription(url)
#else
        print("⚠️ WhisperKit package not linked. Falling back to Apple Speech Recognition.")
        return try await simulateWhisperTranscription(url)
#endif
    }
    
    private func isValidModelDirectory(_ url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("❌ Directory does not exist: \(url.path)")
            return false
        }
        
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
        print("📂 Checking directory validity: \(url.lastPathComponent)")
        print("   Total files: \(contents.count)")
        
        // Ignore obvious placeholder or metadata files
        let realFiles = contents.filter { file in
            let lower = file.lowercased()
            if lower == "model.txt" || lower == ".ds_store" || lower.hasSuffix(".placeholder") {
                return false
            }
            return true
        }
        
        print("   Real files: \(realFiles.count)")
        if realFiles.isEmpty {
            print("   ❌ No valid model files found")
        } else {
            print("   ✅ Valid files: \(realFiles.prefix(5).joined(separator: ", "))\(realFiles.count > 5 ? "..." : "")")
        }
        
        return !realFiles.isEmpty
    }
    
    /// Uses Apple Speech Recognition as fallback until WhisperKit is added
    private func simulateWhisperTranscription(_ url: URL) async throws -> String {
        print("⚠️ WhisperKit not available - using Apple Speech Recognition fallback for final transcription")
        
        // Use actual speech recognition for the final, complete audio file
        do {
            let transcription = try await fallbackRecognizer.transcribe(audioURL: url)
            print("✅ Fallback transcription completed: \(transcription.prefix(50))...")
            return transcription
        } catch {
            print("❌ Fallback transcription failed: \(error)")
            // Return what we captured during streaming, if available
            if !transcribedText.isEmpty {
                print("ℹ️ Using streaming transcription result instead")
                return transcribedText
            }
            throw error
        }
    }
}

// MARK: - Error Types

enum WhisperError: LocalizedError {
    case modelNotAvailable
    case invalidURL
    case downloadFailed
    case noRecording
    case transcriptionFailed
    case whisperKitUnavailable
    
    var errorDescription: String? {
        switch self {
        case .modelNotAvailable:
            return "Whisper model is not available. Please download it in Settings."
        case .invalidURL:
            return "Invalid model download URL."
        case .downloadFailed:
            return "Failed to download Whisper model. Please check your connection."
        case .noRecording:
            return "No audio recording found."
        case .transcriptionFailed:
            return "Failed to transcribe audio with Whisper."
        case .whisperKitUnavailable:
            return "WhisperKit package is missing. Add the Swift Package dependency to enable Whisper."
        }
    }
}
