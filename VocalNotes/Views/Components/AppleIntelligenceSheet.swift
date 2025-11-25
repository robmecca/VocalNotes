//
//  AppleIntelligenceSheet.swift
//  VocalNotes
//
//  Created by AI Assistant on 24/11/2025.
//

import SwiftUI
import UIKit

/// Sheet that presents text for Apple Intelligence processing
struct AppleIntelligenceSheet: View {
    @Binding var text: String
    let action: WritingToolsAction
    @Environment(\.dismiss) private var dismiss
    
    @State private var editedText: String
    @State private var hasChanges = false
    
    init(text: Binding<String>, action: WritingToolsAction) {
        self._text = text
        self.action = action
        self._editedText = State(initialValue: text.wrappedValue)
        
        // Debug: Log the text being passed
        print("🔍 AppleIntelligenceSheet init with text: '\(text.wrappedValue.prefix(50))...'")
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Instructions banner
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.purple)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Text selected - Writing Tools available")
                            .font(.subheadline.bold())
                        Text("Tap the popup menu → select '\(actionName)'")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Visual indicator
                    Image(systemName: "hand.tap.fill")
                        .foregroundColor(.purple.opacity(0.6))
                        .imageScale(.large)
                }
                .padding()
                .background(Color.purple.opacity(0.1))
                
                // Text editor with Writing Tools enabled
                AppleIntelligenceTextView(
                    text: $editedText,
                    action: action,
                    onTextChanged: {
                        hasChanges = true
                    }
                )
            }
            .navigationTitle(actionName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        text = editedText
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!hasChanges)
                }
            }
        }
    }
    
    private var actionName: String {
        switch action {
        case .rewrite: return "Rewrite"
        case .polish: return "Polish"
        case .summarize: return "Summarize"
        case .proofread: return "Proofread"
        case .makeConcise: return "Make Concise"
        }
    }
}

/// UIViewRepresentable for Apple Intelligence text editing
struct AppleIntelligenceTextView: UIViewRepresentable {
    @Binding var text: String
    let action: WritingToolsAction
    let onTextChanged: () -> Void
    
    func makeUIView(context: Context) -> UITextView {
        print("📱 Creating UITextView with text: '\(text.prefix(50))...'")
        
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = .systemFont(ofSize: 17)
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        textView.isEditable = true
        textView.isSelectable = true
        textView.isUserInteractionEnabled = true
        
        // Set the initial text
        textView.text = text
        print("✅ UITextView.text set to: '\(textView.text?.prefix(50) ?? "")...'")
        
        // Enable Writing Tools (Apple Intelligence) for iOS 18+
        if #available(iOS 18.0, *) {
            textView.writingToolsBehavior = .complete
            textView.allowsEditingTextAttributes = true
        }
        
        // Store the coordinator reference
        context.coordinator.textView = textView
        
        // Trigger the setup sequence
        DispatchQueue.main.async {
            context.coordinator.setupTextView(textView)
        }
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        // Only update if text actually changed
        if uiView.text != text {
            uiView.text = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onTextChanged: onTextChanged, action: action)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        let onTextChanged: () -> Void
        let action: WritingToolsAction
        weak var textView: UITextView?
        
        init(text: Binding<String>, onTextChanged: @escaping () -> Void, action: WritingToolsAction) {
            self._text = text
            self.onTextChanged = onTextChanged
            self.action = action
        }
        
        func textViewDidChange(_ textView: UITextView) {
            text = textView.text
            onTextChanged()
        }
        
        // This is called when the text view appears
        func setupTextView(_ textView: UITextView) {
            // Make first responder immediately
            textView.becomeFirstResponder()
            
            // Select all text after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak textView] in
                guard let textView = textView else { return }
                
                // Select all text
                textView.selectAll(nil)
                
                // Show the editing menu
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak textView] in
                    guard let textView = textView else { return }
                    
                    if #available(iOS 18.0, *) {
                        // Calculate the rect for the menu (middle of visible text)
                        let rect = CGRect(x: textView.bounds.midX, y: textView.bounds.minY + 50, width: 1, height: 1)
                        
                        // Show menu controller
                        let menuController = UIMenuController.shared
                        menuController.showMenu(from: textView, rect: rect)
                    } else {
                        let rect = CGRect(x: textView.bounds.midX, y: textView.bounds.minY + 50, width: 1, height: 1)
                        UIMenuController.shared.showMenu(from: textView, rect: rect)
                    }
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var sampleText = "um so like i think we should maybe consider the project deadline and you know make sure that we stay on track"
    
    AppleIntelligenceSheet(text: $sampleText, action: .rewrite)
}

