//
//  IntelligenceService.swift
//  VocalNotes
//
//  Created by Roberto Mecca on 23/11/2025.
//

import Foundation
import NaturalLanguage
import SwiftUI

class IntelligenceService {
    static let shared = IntelligenceService()
    
    // Check user preferences
    private var useAIEnhancement: Bool {
        UserDefaults.standard.bool(forKey: "useAIEnhancement")
    }
    
    // MARK: - Text Enhancement
    
    func cleanText(_ text: String) async throws -> String {
        // Always add punctuation, even without AI models
        print("📝 Starting text enhancement...")
        
        // Try to use LLM if available and enabled
        if useAIEnhancement && LLMService.shared.isModelAvailable {
            do {
                print("🤖 Using local AI model for text enhancement")
                return try await LLMService.shared.enhanceText(text)
            } catch {
                print("⚠️ AI model failed, falling back to standard processing: \(error)")
                // Fall back to standard processing
            }
        }
        
        // Always use rule-based processing with punctuation
        print("✏️ Applying rule-based punctuation and capitalization...")
        let enhanced = await performStandardProcessing(text)
        print("✅ Enhancement complete: \(enhanced.prefix(50))...")
        return enhanced
    }
    
    func summarize(_ text: String) async throws -> String {
        // Try to use LLM if available and enabled
        if useAIEnhancement && LLMService.shared.isModelAvailable {
            do {
                print("🤖 Using local AI model for summarization")
                return try await LLMService.shared.summarizeText(text)
            } catch {
                print("⚠️ AI model failed, falling back to standard processing: \(error)")
                // Fall back to standard processing
            }
        }
        
        // Fallback: Enhanced summarization with better sentence scoring
        print("📝 Using advanced rule-based summarization")
        return await performAdvancedSummarization(text)
    }
    
    // Standard processing without AI - with enhanced punctuation
    private func performStandardProcessing(_ text: String) async -> String {
        var processed = text
        
        // Remove fillers
        let fillers = ["um", "uh", "uhh", "umm", "like", "you know", "i mean", "sort of", "kind of", "basically", "actually"]
        for filler in fillers {
            processed = processed.replacingOccurrences(
                of: "\\b\(filler)\\b[,\\s]*",
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        
        // Fix spacing
        processed = processed.replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression)
        processed = processed.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Add smart punctuation
        processed = addSmartPunctuation(processed)
        
        // Capitalize sentences
        processed = capitalizeSentences(processed)
        
        // Add ending punctuation if missing
        if !processed.isEmpty && ![".", "!", "?"].contains(where: { processed.hasSuffix(String($0)) }) {
            processed += "."
        }
        
        return processed
    }
    
    private func addSmartPunctuation(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        
        var result = text
        let words = result.split(separator: " ").map { String($0) }
        var processedWords: [String] = []
        var wordCount = 0
        
        // Question starters
        let questionStarters = ["what", "where", "when", "why", "who", "how", "which", "is", "are", "can", "could", "would", "should", "do", "does", "did", "will", "was", "were"]
        
        // Sentence connectors that suggest a new sentence
        let connectors = ["then", "after", "next", "also", "however", "but", "so", "therefore", "meanwhile"]
        
        var isQuestion = false
        
        for (index, word) in words.enumerated() {
            var currentWord = word
            wordCount += 1
            
            // Check if this starts a question
            if wordCount == 1 && questionStarters.contains(currentWord.lowercased()) {
                isQuestion = true
            }
            
            // Add punctuation based on various conditions
            let isLastWord = index == words.count - 1
            let nextWordIsConnector = index < words.count - 1 && connectors.contains(words[index + 1].lowercased())
            let nextWordIsQuestion = index < words.count - 1 && questionStarters.contains(words[index + 1].lowercased())
            
            // Force punctuation at 10+ words, or at connectors, or last word
            if (wordCount >= 10) || nextWordIsConnector || nextWordIsQuestion || isLastWord {
                // Don't add if already has punctuation
                if !currentWord.hasSuffix(".") && !currentWord.hasSuffix("!") && !currentWord.hasSuffix("?") && !currentWord.hasSuffix(",") {
                    if isQuestion {
                        currentWord += "?"
                        isQuestion = false
                    } else {
                        currentWord += "."
                    }
                    wordCount = 0
                }
            }
            // Add commas for pauses (every 4-6 words)
            else if wordCount >= 4 && wordCount <= 6 && index < words.count - 2 {
                let pauseWords = ["and", "but", "or", "because", "since", "while", "although"]
                if pauseWords.contains(words[index + 1].lowercased()) && !currentWord.hasSuffix(",") {
                    currentWord += ","
                }
            }
            
            processedWords.append(currentWord)
        }
        
        return processedWords.joined(separator: " ")
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
            
            // Capitalize after sentence-ending punctuation
            if [".", "!", "?"].contains(String(char)) {
                shouldCapitalize = true
            }
        }
        
        return result
    }
    
    func suggestTopics(for text: String, existingTopics: [Topic]) async -> [Topic] {
        // Basic keyword-based topic suggestion
        let lowercasedText = text.lowercased()
        
        return existingTopics.filter { topic in
            let keywords = generateKeywords(for: topic.name)
            return keywords.contains { keyword in
                lowercasedText.contains(keyword.lowercased())
            }
        }
    }
    
    func extractActionItems(_ text: String) async -> [String] {
        // Extract potential action items from text
        let lines = text.components(separatedBy: .newlines)
        var actionItems: [String] = []
        
        let actionWords = ["todo", "task", "need to", "must", "should", "remember to", "don't forget"]
        
        for line in lines {
            let lowercasedLine = line.lowercased()
            if actionWords.contains(where: { lowercasedLine.contains($0) }) {
                actionItems.append(line.trimmingCharacters(in: .whitespaces))
            }
        }
        
        return actionItems
    }
    
    // MARK: - Private Helpers
    
    private func performAdvancedCleaning(_ text: String) async -> String {
        var cleaned = text
        
        // Remove filler words (expanded list)
        let fillers = [
            "um", "uh", "uhh", "umm", "er", "ah", "ahh",
            "like", "you know", "I mean", "sort of", "kind of",
            "basically", "actually", "literally", "right",
            "okay", "so yeah", "well"
        ]
        
        for filler in fillers {
            // Remove filler at word boundaries
            cleaned = cleaned.replacingOccurrences(
                of: "\\b\(filler)\\b",
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        
        // Remove repeated words (e.g., "I I think" -> "I think")
        cleaned = cleaned.replacingOccurrences(
            of: "\\b(\\w+)\\s+\\1\\b",
            with: "$1",
            options: [.regularExpression, .caseInsensitive]
        )
        
        // Fix spacing issues
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Fix punctuation spacing
        cleaned = cleaned.replacingOccurrences(of: "\\s+([,.:;!?])", with: "$1", options: .regularExpression)
        
        // Add space after punctuation if missing
        cleaned = cleaned.replacingOccurrences(of: "([,.:;!?])([A-Za-z])", with: "$1 $2", options: .regularExpression)
        
        // Capitalize properly using NaturalLanguage
        cleaned = capitalizeWithNLP(cleaned)
        
        // Fix common transcription errors
        cleaned = fixCommonTranscriptionErrors(cleaned)
        
        // Ensure proper sentence ending
        if !cleaned.isEmpty && ![".", "!", "?"].contains(where: { cleaned.hasSuffix(String($0)) }) {
            cleaned += "."
        }
        
        return cleaned
    }
    
    private func performAdvancedSummarization(_ text: String) async -> String {
        // Use NaturalLanguage for better sentence detection
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        
        var sentences: [(String, Double)] = []
        
        // Extract sentences and calculate importance scores
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                let score = calculateSentenceImportance(sentence, in: text)
                sentences.append((sentence, score))
            }
            return true
        }
        
        if sentences.isEmpty {
            return text
        }
        
        // Sort by importance and take top sentences
        let sortedSentences = sentences.sorted { $0.1 > $1.1 }
        let maxSentences = min(3, sentences.count)
        let topSentences = Array(sortedSentences.prefix(maxSentences))
        
        // Sort back to original order for coherence
        let originalOrder = topSentences.sorted { s1, s2 in
            guard let index1 = sentences.firstIndex(where: { $0.0 == s1.0 }),
                  let index2 = sentences.firstIndex(where: { $0.0 == s2.0 }) else {
                return false
            }
            return index1 < index2
        }
        
        let summary = originalOrder.map { $0.0 }.joined(separator: " ")
        return summary
    }
    
    private func capitalizeWithNLP(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        
        var result = text
        
        // Capitalize first letter
        if let first = result.first {
            result = first.uppercased() + result.dropFirst()
        }
        
        // Capitalize after sentence-ending punctuation
        let sentences = result.components(separatedBy: CharacterSet(charactersIn: ".!?"))
        var capitalizedResult = ""
        var previousSeparator = ""
        
        for (index, sentence) in sentences.enumerated() {
            let trimmed = sentence.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                capitalizedResult += previousSeparator
                if !previousSeparator.isEmpty {
                    capitalizedResult += " "
                }
                // Capitalize first letter of sentence
                capitalizedResult += trimmed.prefix(1).uppercased() + trimmed.dropFirst()
            }
            
            // Find the separator that was used
            if index < sentences.count - 1 {
                let searchStart = capitalizedResult.count
                if let dotIndex = text.firstIndex(of: "."),
                   text.distance(from: text.startIndex, to: dotIndex) >= searchStart {
                    previousSeparator = "."
                } else if let exclamIndex = text.firstIndex(of: "!"),
                          text.distance(from: text.startIndex, to: exclamIndex) >= searchStart {
                    previousSeparator = "!"
                } else if let questionIndex = text.firstIndex(of: "?"),
                          text.distance(from: text.startIndex, to: questionIndex) >= searchStart {
                    previousSeparator = "?"
                }
            }
        }
        
        return capitalizedResult
    }
    
    private func fixCommonTranscriptionErrors(_ text: String) -> String {
        var fixed = text
        
        // Common speech-to-text mistakes
        let corrections: [String: String] = [
            "dont": "don't",
            "cant": "can't",
            "wont": "won't",
            "im": "I'm",
            "ive": "I've",
            "youre": "you're",
            "theyre": "they're",
            "thats": "that's",
            "whats": "what's",
            "heres": "here's",
            "theres": "there's"
        ]
        
        for (wrong, correct) in corrections {
            fixed = fixed.replacingOccurrences(
                of: "\\b\(wrong)\\b",
                with: correct,
                options: [.regularExpression, .caseInsensitive]
            )
        }
        
        return fixed
    }
    
    private func calculateSentenceImportance(_ sentence: String, in fullText: String) -> Double {
        var score = 0.0
        
        // Length score (prefer medium-length sentences)
        let wordCount = sentence.split(separator: " ").count
        if wordCount >= 5 && wordCount <= 20 {
            score += 1.0
        } else if wordCount < 3 {
            score -= 0.5
        }
        
        // Position score (first sentences are often important)
        if fullText.hasPrefix(sentence) {
            score += 1.0
        }
        
        // Keyword score (sentences with important words)
        let importantWords = ["important", "key", "main", "should", "must", "need", "critical", "essential"]
        let lowercasedSentence = sentence.lowercased()
        for word in importantWords {
            if lowercasedSentence.contains(word) {
                score += 0.5
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
        score += Double(entityCount) * 0.3
        
        return score
    }
    
    private func generateKeywords(for topicName: String) -> [String] {
        // Generate related keywords for a topic
        var keywords = [topicName]
        
        // Add common related terms
        let relatedTerms: [String: [String]] = [
            "work": ["job", "office", "meeting", "project", "colleague", "business"],
            "personal": ["life", "family", "home", "myself"],
            "ideas": ["thought", "concept", "brainstorm", "innovation"],
            "research": ["study", "analysis", "investigation", "finding", "data"]
        ]
        
        let lowercasedName = topicName.lowercased()
        for (key, terms) in relatedTerms {
            if lowercasedName.contains(key) {
                keywords.append(contentsOf: terms)
            }
        }
        
        return keywords
    }
}

