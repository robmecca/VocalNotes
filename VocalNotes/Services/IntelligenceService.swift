//
//  IntelligenceService.swift
//  VocalNotes
//
//  Created by Roberto Mecca on 23/11/2025.
//

import Foundation

class IntelligenceService {
    static let shared = IntelligenceService()
    
    // MARK: - Text Enhancement
    
    func cleanText(_ text: String) async throws -> String {
        // For now, implement basic cleaning rules
        // In production, this would integrate with Apple Intelligence APIs
        return await performBasicCleaning(text)
    }
    
    func summarize(_ text: String) async throws -> String {
        // For now, implement basic summarization
        // In production, this would use Apple Intelligence for smart summarization
        return await performBasicSummarization(text)
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
    
    private func performBasicCleaning(_ text: String) async -> String {
        var cleaned = text
        
        // Remove filler words
        let fillers = ["um", "uh", "like", "you know", "sort of", "kind of"]
        for filler in fillers {
            cleaned = cleaned.replacingOccurrences(
                of: "\\b\(filler)\\b",
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        
        // Fix spacing
        cleaned = cleaned.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Capitalize sentences
        cleaned = capitalizeSentences(cleaned)
        
        // Fix common punctuation issues
        cleaned = cleaned.replacingOccurrences(of: " ,", with: ",")
        cleaned = cleaned.replacingOccurrences(of: " .", with: ".")
        cleaned = cleaned.replacingOccurrences(of: " ?", with: "?")
        cleaned = cleaned.replacingOccurrences(of: " !", with: "!")
        
        return cleaned
    }
    
    private func performBasicSummarization(_ text: String) async -> String {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // Take first few sentences and key sentences
        let maxSentences = min(3, sentences.count)
        let keySentences = sentences.prefix(maxSentences)
        
        if keySentences.isEmpty {
            return text
        }
        
        return keySentences.joined(separator: ". ") + "."
    }
    
    private func capitalizeSentences(_ text: String) -> String {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
        let capitalizedSentences = sentences.map { sentence -> String in
            let trimmed = sentence.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return sentence }
            return trimmed.prefix(1).uppercased() + trimmed.dropFirst()
        }
        
        var result = ""
        for (index, sentence) in capitalizedSentences.enumerated() {
            result += sentence
            if index < sentences.count - 1 && !sentence.isEmpty {
                // Restore the original separator
                if text.contains(sentence + ".") {
                    result += "."
                } else if text.contains(sentence + "!") {
                    result += "!"
                } else if text.contains(sentence + "?") {
                    result += "?"
                }
            }
        }
        
        return result
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

