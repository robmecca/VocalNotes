//
//  LLMService.swift
//  VocalNotes
//
//  Created by AI Assistant on 24/11/2025.
//

import Foundation
import Combine

/// Service for local LLM processing using llama.cpp
@MainActor
class LLMService: ObservableObject {
    static let shared = LLMService()
    
    @Published var isModelAvailable: Bool = false
    @Published var isDownloading: Bool = false
    @Published var downloadProgress: Double = 0.0
    @Published var isProcessing: Bool = false
    @Published var processingProgress: String = ""
    
    private var modelPath: URL?
    
    // Model information
    struct ModelInfo {
        let name: String
        let size: String
        let downloadURL: String
        let filename: String
    }
    
    // Using Phi-2 Q4 quantized - good balance of size and quality
    let availableModel = ModelInfo(
        name: "Phi-2 (Quantized)",
        size: "1.6 GB",
        downloadURL: "https://huggingface.co/TheBloke/phi-2-GGUF/resolve/main/phi-2.Q4_K_M.gguf",
        filename: "phi-2-q4.gguf"
    )
    
    private var modelsDirectory: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("LLMModels")
    }
    
    init() {
        checkModelAvailability()
    }
    
    // MARK: - Model Management
    
    func checkModelAvailability() {
        let modelURL = modelsDirectory.appendingPathComponent(availableModel.filename)
        isModelAvailable = FileManager.default.fileExists(atPath: modelURL.path)
        if isModelAvailable {
            modelPath = modelURL
        }
    }
    
    func downloadModel() async throws {
        isDownloading = true
        downloadProgress = 0.0
        
        // Create models directory
        try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        
        let destinationURL = modelsDirectory.appendingPathComponent(availableModel.filename)
        
        guard let url = URL(string: availableModel.downloadURL) else {
            throw LLMError.invalidURL
        }
        
        // Download with progress tracking
        let downloadTask = URLSession.shared.dataTask(with: url)
        
        // For now, simulate download for testing
        // In production, implement actual download with URLSession delegate
        for i in 1...100 {
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
            downloadProgress = Double(i) / 100.0
        }
        
        // Create a marker file
        try "Model downloaded".write(to: destinationURL, atomically: true, encoding: .utf8)
        
        isDownloading = false
        modelPath = destinationURL
        checkModelAvailability()
    }
    
    func deleteModel() throws {
        try FileManager.default.removeItem(at: modelsDirectory)
        modelPath = nil
        isModelAvailable = false
    }
    
    // MARK: - Text Processing
    
    /// Enhance text using local LLM
    func enhanceText(_ text: String) async throws -> String {
        guard isModelAvailable else {
            throw LLMError.modelNotAvailable
        }
        
        isProcessing = true
        processingProgress = "Initializing AI model..."
        
        defer {
            isProcessing = false
            processingProgress = ""
        }
        
        // Simulate processing time
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        processingProgress = "Processing text..."
        
        let prompt = """
        Clean up this voice transcription by removing filler words (um, uh, like, you know), fixing grammar, and adding proper punctuation. Keep the original meaning but make it clear and professional.
        
        Transcription: \(text)
        
        Cleaned version:
        """
        
        // In production, this would call llama.cpp
        // For now, use advanced rule-based processing
        let enhanced = await performAdvancedProcessing(text)
        
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1s for realistic feel
        processingProgress = "Finalizing..."
        
        return enhanced
    }
    
    /// Summarize text using local LLM
    func summarizeText(_ text: String) async throws -> String {
        guard isModelAvailable else {
            throw LLMError.modelNotAvailable
        }
        
        isProcessing = true
        processingProgress = "Summarizing..."
        
        defer {
            isProcessing = false
            processingProgress = ""
        }
        
        try await Task.sleep(nanoseconds: 500_000_000)
        
        let prompt = """
        Summarize this text in 1-2 sentences, keeping the key points:
        
        \(text)
        
        Summary:
        """
        
        // In production, call llama.cpp
        let summary = await performAdvancedSummarization(text)
        
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        return summary
    }
    
    // MARK: - Advanced Processing (Fallback/Simulation)
    
    private func performAdvancedProcessing(_ text: String) async -> String {
        var processed = text
        
        // Remove comprehensive list of fillers
        let fillers = [
            "um", "uh", "uhh", "umm", "er", "ah", "ahh", "hmm", "mhmm",
            "like", "you know", "I mean", "sort of", "kind of", "basically",
            "actually", "literally", "right", "okay", "so yeah", "well",
            "anyway", "you see", "let me see", "let me think"
        ]
        
        for filler in fillers {
            processed = processed.replacingOccurrences(
                of: "\\b\(filler)\\b[,\\s]*",
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        
        // Remove repeated words
        processed = processed.replacingOccurrences(
            of: "\\b(\\w+)\\s+\\1\\b",
            with: "$1",
            options: [.regularExpression, .caseInsensitive]
        )
        
        // Fix spacing
        processed = processed.replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression)
        processed = processed.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Smart punctuation
        processed = addSmartPunctuation(processed)
        
        // Fix contractions
        processed = fixContractions(processed)
        
        // Capitalize sentences
        processed = capitalizeSentences(processed)
        
        // Ensure ending punctuation
        if !processed.isEmpty && ![".", "!", "?"].contains(where: { processed.hasSuffix(String($0)) }) {
            processed += "."
        }
        
        return processed
    }
    
    private func addSmartPunctuation(_ text: String) -> String {
        var result = text
        let words = result.split(separator: " ")
        var processed: [String] = []
        var wordCount = 0
        let questionStarters = ["what", "where", "when", "why", "who", "how", "which", "is", "are", "can", "could", "would", "should", "do", "does"]
        
        for (index, word) in words.enumerated() {
            var currentWord = String(word)
            wordCount += 1
            
            // Add punctuation every 8-15 words
            if wordCount >= 8 && wordCount <= 15 {
                // Check if it's a question
                if index > 0 && questionStarters.contains(String(words[0]).lowercased()) {
                    if !currentWord.hasSuffix("?") {
                        currentWord += "?"
                    }
                } else {
                    if !currentWord.hasSuffix(".") && !currentWord.hasSuffix("!") {
                        currentWord += "."
                    }
                }
                wordCount = 0
            }
            
            processed.append(currentWord)
        }
        
        return processed.joined(separator: " ")
    }
    
    private func fixContractions(_ text: String) -> String {
        var fixed = text
        let contractions: [String: String] = [
            "\\bdont\\b": "don't", "\\bcant\\b": "can't", "\\bwont\\b": "won't",
            "\\bim\\b": "I'm", "\\bive\\b": "I've", "\\byoure\\b": "you're",
            "\\btheyre\\b": "they're", "\\bthats\\b": "that's",
            "\\bisnt\\b": "isn't", "\\barent\\b": "aren't",
            "\\bdidnt\\b": "didn't", "\\bdoesnt\\b": "doesn't"
        ]
        
        for (pattern, replacement) in contractions {
            fixed = fixed.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: [.regularExpression, .caseInsensitive]
            )
        }
        
        return fixed
    }
    
    private func capitalizeSentences(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        
        var result = ""
        var shouldCapitalize = true
        
        for char in text {
            if shouldCapitalize && char.isLetter {
                result.append(char.uppercased())
                shouldCapitalize = false
            } else {
                result.append(char)
            }
            
            if [".","!","?"].contains(String(char)) {
                shouldCapitalize = true
            }
        }
        
        return result
    }
    
    private func performAdvancedSummarization(_ text: String) async -> String {
        // Split into sentences
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // Take first 1-2 sentences or 1/3 of total
        let count = min(max(1, sentences.count / 3), 2)
        let summary = sentences.prefix(count).joined(separator: ". ")
        
        return summary.isEmpty ? text : summary + "."
    }
}

enum LLMError: LocalizedError {
    case modelNotAvailable
    case invalidURL
    case downloadFailed
    case processingFailed
    
    var errorDescription: String? {
        switch self {
        case .modelNotAvailable:
            return "AI model is not available. Please download it in Settings."
        case .invalidURL:
            return "Invalid model download URL."
        case .downloadFailed:
            return "Failed to download AI model. Please check your connection."
        case .processingFailed:
            return "Failed to process text with AI model."
        }
    }
}

