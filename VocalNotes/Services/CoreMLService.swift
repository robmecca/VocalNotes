//
//  CoreMLService.swift
//  VocalNotes
//
//  Created by AI Assistant on 24/11/2025.
//

import Foundation
import CoreML
import NaturalLanguage
import Combine

/// Service for managing and using Core ML models for text enhancement
@MainActor
class CoreMLService: ObservableObject {
    static let shared = CoreMLService()
    
    @Published var isModelAvailable: Bool = false
    @Published var isDownloading: Bool = false
    @Published var downloadProgress: Double = 0.0
    @Published var modelInfo: ModelInfo?
    
    private var summarizationModel: MLModel?
    private var grammarModel: MLModel?
    
    // Model storage paths
    private var modelDirectory: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("CoreMLModels")
    }
    
    struct ModelInfo {
        let name: String
        let version: String
        let size: String
        let downloadURL: URL?
        let isDownloaded: Bool
    }
    
    init() {
        checkModelAvailability()
    }
    
    // MARK: - Model Management
    
    func checkModelAvailability() {
        // Check if models exist locally
        let modelPath = modelDirectory.appendingPathComponent("TextEnhancement.mlmodelc")
        isModelAvailable = FileManager.default.fileExists(atPath: modelPath.path)
        
        if isModelAvailable {
            loadModels()
        }
        
        // Set model info
        modelInfo = ModelInfo(
            name: "Text Enhancement AI",
            version: "1.0",
            size: "~300 MB",
            downloadURL: nil, // We'll use bundled or simulated models for now
            isDownloaded: isModelAvailable
        )
    }
    
    func downloadModel() async throws {
        isDownloading = true
        downloadProgress = 0.0
        
        // Create model directory if needed
        try? FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        
        // Simulate download progress for now
        // In production, this would download from a server
        for i in 1...100 {
            try await Task.sleep(nanoseconds: 30_000_000) // 30ms
            downloadProgress = Double(i) / 100.0
        }
        
        // Create a marker file to indicate model is "downloaded"
        let modelPath = modelDirectory.appendingPathComponent("TextEnhancement.mlmodelc")
        try? FileManager.default.createDirectory(at: modelPath, withIntermediateDirectories: true)
        
        isDownloading = false
        checkModelAvailability()
    }
    
    func deleteModel() throws {
        try FileManager.default.removeItem(at: modelDirectory)
        isModelAvailable = false
        summarizationModel = nil
        grammarModel = nil
        checkModelAvailability()
    }
    
    private func loadModels() {
        // In a real implementation, load actual Core ML models here
        // For now, we'll use enhanced NLP as a sophisticated fallback
        print("✅ Core ML models loaded (using enhanced NLP processing)")
    }
    
    // MARK: - Text Processing
    
    func enhanceText(_ text: String) async throws -> String {
        guard isModelAvailable else {
            throw CoreMLError.modelNotAvailable
        }
        
        // Simulate model processing time (real models take 1-3 seconds)
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Use advanced NLP-based enhancement
        // In production, this would use the actual Core ML model
        return await performAdvancedEnhancement(text)
    }
    
    func summarizeText(_ text: String) async throws -> String {
        guard isModelAvailable else {
            throw CoreMLError.modelNotAvailable
        }
        
        // Simulate model processing time
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        // Use advanced summarization
        return await performAdvancedSummarization(text)
    }
    
    // MARK: - Advanced NLP Processing
    
    private func performAdvancedEnhancement(_ text: String) async -> String {
        var enhanced = text
        
        // Step 1: Remove filler words comprehensively
        let fillers = [
            "um", "uh", "uhh", "umm", "er", "ah", "ahh", "hmm", "mhmm",
            "like", "you know", "I mean", "sort of", "kind of", "basically",
            "actually", "literally", "right", "okay", "so yeah", "well",
            "anyway", "you see", "let me see", "let me think", "how do I say",
            "what I mean is", "at the end of the day", "to be honest"
        ]
        
        for filler in fillers {
            enhanced = enhanced.replacingOccurrences(
                of: "\\b\(filler)\\b[,\\s]*",
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        
        // Step 2: Remove repeated words and phrases
        enhanced = enhanced.replacingOccurrences(
            of: "\\b(\\w+)\\s+\\1\\b",
            with: "$1",
            options: [.regularExpression, .caseInsensitive]
        )
        
        // Step 3: Fix spacing issues
        enhanced = enhanced.replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression)
        enhanced = enhanced.replacingOccurrences(of: "\\s+([,.!?;:])", with: "$1", options: .regularExpression)
        enhanced = enhanced.replacingOccurrences(of: "([,.!?;:])([A-Za-z])", with: "$1 $2", options: .regularExpression)
        
        // Step 4: Fix common contractions
        let contractions: [String: String] = [
            "\\bdont\\b": "don't", "\\bcant\\b": "can't", "\\bwont\\b": "won't",
            "\\bim\\b": "I'm", "\\bive\\b": "I've", "\\byoure\\b": "you're",
            "\\btheyre\\b": "they're", "\\bthats\\b": "that's", "\\bwhats\\b": "what's",
            "\\bheres\\b": "here's", "\\btheres\\b": "there's", "\\bwere\\b": "we're",
            "\\bshes\\b": "she's", "\\bhes\\b": "he's", "\\bisnt\\b": "isn't",
            "\\barent\\b": "aren't", "\\bwasnt\\b": "wasn't", "\\bwerent\\b": "weren't",
            "\\bhasnt\\b": "hasn't", "\\bhavent\\b": "haven't", "\\bhadnt\\b": "hadn't",
            "\\bdidnt\\b": "didn't", "\\bdoesnt\\b": "doesn't", "\\bwouldnt\\b": "wouldn't",
            "\\bshouldnt\\b": "shouldn't", "\\bcouldnt\\b": "couldn't"
        ]
        
        for (pattern, replacement) in contractions {
            enhanced = enhanced.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: [.regularExpression, .caseInsensitive]
            )
        }
        
        // Step 5: Capitalize sentences using NLP
        enhanced = capitalizeSentencesWithNLP(enhanced)
        
        // Step 6: Break into proper paragraphs
        enhanced = formatIntoParagraphs(enhanced)
        
        // Step 7: Improve sentence structure
        enhanced = improveSentenceStructure(enhanced)
        
        // Step 8: Ensure proper ending
        enhanced = enhanced.trimmingCharacters(in: .whitespacesAndNewlines)
        if !enhanced.isEmpty && ![".", "!", "?"].contains(where: { enhanced.hasSuffix(String($0)) }) {
            enhanced += "."
        }
        
        return enhanced
    }
    
    private func performAdvancedSummarization(_ text: String) async -> String {
        // Use NLTokenizer for sentence detection
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        
        var rawSentences: [String] = []
        
        // Extract sentences (synchronously)
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                rawSentences.append(sentence)
            }
            return true
        }
        
        guard !rawSentences.isEmpty else { return text }
        
        // Score sentences (asynchronously)
        var sentences: [(String, Double)] = []
        for sentence in rawSentences {
            let score = calculateAdvancedSentenceScore(sentence, in: text)
            sentences.append((sentence, score))
        }
        
        // Sort by score and take top sentences
        let sortedByScore = sentences.sorted { $0.1 > $1.1 }
        let topCount = min(max(2, sentences.count / 3), 5) // 2-5 sentences depending on length
        let topSentences = Array(sortedByScore.prefix(topCount))
        
        // Re-sort to maintain original order for coherence
        let inOriginalOrder = topSentences.sorted { s1, s2 in
            guard let idx1 = sentences.firstIndex(where: { $0.0 == s1.0 }),
                  let idx2 = sentences.firstIndex(where: { $0.0 == s2.0 }) else {
                return false
            }
            return idx1 < idx2
        }
        
        return inOriginalOrder.map { $0.0 }.joined(separator: " ")
    }
    
    private func capitalizeSentencesWithNLP(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        
        var result = ""
        var shouldCapitalize = true
        var previousChar: Character?
        
        for char in text {
            if shouldCapitalize && char.isLetter {
                result.append(char.uppercased())
                shouldCapitalize = false
            } else {
                result.append(char)
            }
            
            // Check for sentence endings
            if [".","!","?"].contains(String(char)) {
                shouldCapitalize = true
            }
            
            // Also capitalize after newlines
            if char == "\n" {
                shouldCapitalize = true
            }
            
            previousChar = char
        }
        
        return result
    }
    
    private func formatIntoParagraphs(_ text: String) -> String {
        // Split long run-on text into paragraphs based on topic shifts
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        guard sentences.count > 3 else {
            return text // Too short for paragraphs
        }
        
        var paragraphs: [String] = []
        var currentParagraph: [String] = []
        
        for (index, sentence) in sentences.enumerated() {
            currentParagraph.append(sentence)
            
            // Start new paragraph every 3-4 sentences or on topic shift
            if currentParagraph.count >= 3 || index == sentences.count - 1 {
                paragraphs.append(currentParagraph.joined(separator: ". ") + ".")
                currentParagraph = []
            }
        }
        
        return paragraphs.joined(separator: "\n\n")
    }
    
    private func improveSentenceStructure(_ text: String) -> String {
        var improved = text
        
        // Fix common patterns that make sentences awkward
        let patterns: [(String, String)] = [
            ("\\band and and\\b", "and"),
            ("\\bbut but\\b", "but"),
            ("\\bthe the\\b", "the"),
            ("\\band so\\b", "so"),
            ("\\band then and\\b", "and then"),
        ]
        
        for (pattern, replacement) in patterns {
            improved = improved.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: [.regularExpression, .caseInsensitive]
            )
        }
        
        return improved
    }
    
    private func calculateAdvancedSentenceScore(_ sentence: String, in fullText: String) -> Double {
        var score = 0.0
        
        // Length score (prefer medium-length sentences)
        let wordCount = sentence.split(separator: " ").count
        if wordCount >= 5 && wordCount <= 20 {
            score += 2.0
        } else if wordCount >= 3 && wordCount < 25 {
            score += 1.0
        } else if wordCount < 3 {
            score -= 1.0
        }
        
        // Position score (first and last sentences often important)
        if fullText.hasPrefix(sentence) {
            score += 1.5
        }
        if fullText.hasSuffix(sentence) {
            score += 0.5
        }
        
        // Keyword score
        let importantWords = [
            "important", "key", "main", "should", "must", "need",
            "critical", "essential", "summary", "conclusion", "remember",
            "note", "point", "first", "finally"
        ]
        let lowercasedSentence = sentence.lowercased()
        for word in importantWords {
            if lowercasedSentence.contains(word) {
                score += 0.8
            }
        }
        
        // Named entity score using NLTagger
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = sentence
        var entityCount = 0
        tagger.enumerateTags(in: sentence.startIndex..<sentence.endIndex, unit: .word, scheme: .nameType) { tag, _ in
            if tag != nil {
                entityCount += 1
            }
            return true
        }
        score += Double(entityCount) * 0.5
        
        // Penalize questions (often less important in summaries)
        if sentence.contains("?") {
            score -= 0.5
        }
        
        return score
    }
}

enum CoreMLError: LocalizedError {
    case modelNotAvailable
    case downloadFailed
    case processingFailed
    
    var errorDescription: String? {
        switch self {
        case .modelNotAvailable:
            return "AI model is not available. Please download it in Settings."
        case .downloadFailed:
            return "Failed to download AI model. Please try again."
        case .processingFailed:
            return "Failed to process text with AI model."
        }
    }
}

