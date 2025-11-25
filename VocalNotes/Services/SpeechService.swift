//
//  SpeechService.swift
//  VocalNotes
//
//  Created by Roberto Mecca on 23/11/2025.
//

import Foundation
import Speech
import AVFoundation
import Combine

@MainActor
class SpeechService: NSObject, ObservableObject {
    @Published var transcribedText: String = ""
    @Published var isRecording: Bool = false
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var recordingStartTime: Date?
    
    override init() {
        super.init()
        checkAuthorization()
    }
    
    // MARK: - Authorization
    
    func checkAuthorization() {
        authorizationStatus = SFSpeechRecognizer.authorizationStatus()
    }
    
    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                Task { @MainActor in
                    self.authorizationStatus = status
                    continuation.resume(returning: status == .authorized)
                }
            }
        }
    }
    
    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    // MARK: - Recording
    
    func startRecording() throws {
        // Cancel any ongoing recognition task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Configure audio session FIRST before any audio operations
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // Setup audio engine BEFORE recognition request
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw SpeechError.audioEngineFailed
        }
        
        // Verify input node is available (important for simulator)
        guard audioEngine.inputNode.inputFormat(forBus: 0).channelCount > 0 else {
            print("⚠️ No audio input available. Using AVAudioRecorder fallback.")
            // Fall back to AVAudioRecorder only
            try startAudioRecorderOnly()
            return
        }
        
        // Setup recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechError.recognitionRequestFailed
        }
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Validate recording format
        guard recordingFormat.channelCount > 0 && recordingFormat.sampleRate > 0 else {
            throw SpeechError.audioEngineFailed
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        // Setup audio recording to file
        setupAudioRecorder()
        
        // Prepare and start
        audioEngine.prepare()
        try audioEngine.start()
        audioRecorder?.record()
        
        recordingStartTime = Date()
        transcribedText = ""
        isRecording = true
        
        // Start recognition
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                Task { @MainActor in
                    self.transcribedText = result.bestTranscription.formattedString
                }
            }
            
            if error != nil || result?.isFinal == true {
                Task { @MainActor in
                    self.stopRecordingInternal()
                }
            }
        }
    }
    
    // Fallback for when AVAudioEngine isn't available (e.g., simulator)
    private func startAudioRecorderOnly() throws {
        setupAudioRecorder()
        audioRecorder?.record()
        recordingStartTime = Date()
        transcribedText = ""
        isRecording = true
    }
    
    func stopRecording() -> RecordingResult? {
        stopRecordingInternal()
        
        guard let url = recordingURL,
              let startTime = recordingStartTime else {
            return nil
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        return RecordingResult(
            transcribedText: transcribedText,
            audioFileURL: url,
            duration: duration
        )
    }
    
    private func stopRecordingInternal() {
        // Stop audio engine if it was used
        if let engine = audioEngine {
            engine.stop()
            // Only remove tap if the input node has taps installed
            if engine.inputNode.numberOfInputs > 0 {
                engine.inputNode.removeTap(onBus: 0)
            }
        }
        
        // Stop audio recorder
        audioRecorder?.stop()
        
        // Clean up recognition
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        // Deactivate audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("⚠️ Failed to deactivate audio session: \(error)")
        }
        
        isRecording = false
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
    }
    
    private func setupAudioRecorder() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("recording_\(UUID().uuidString).m4a")
        recordingURL = audioFilename
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.prepareToRecord()
        } catch {
            print("Failed to setup audio recorder: \(error)")
        }
    }
}

struct RecordingResult {
    let transcribedText: String
    let audioFileURL: URL
    let duration: TimeInterval
}

enum SpeechError: Error {
    case recognitionRequestFailed
    case audioEngineFailed
    case notAuthorized
}

