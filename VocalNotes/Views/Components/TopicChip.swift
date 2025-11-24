//
//  TopicChip.swift
//  VocalNotes
//
//  Created by Roberto Mecca on 23/11/2025.
//

import SwiftUI

struct TopicChip: View {
    let topic: Topic
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                if let iconName = topic.iconName {
                    Image(systemName: iconName)
                        .font(.caption)
                } else {
                    Circle()
                        .fill(topic.color)
                        .frame(width: 8, height: 8)
                }
                
                Text(topic.name)
                    .font(.subheadline)
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                isSelected ?
                topic.color.opacity(0.3) :
                Color(.tertiarySystemBackground)
            )
            .foregroundColor(isSelected ? topic.color : .primary)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(topic.color, lineWidth: isSelected ? 2 : 0)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    VStack {
        TopicChip(
            topic: Topic(name: "Work", colorHex: "#4ECDC4"),
            isSelected: false,
            onTap: {}
        )
        
        TopicChip(
            topic: Topic(name: "Personal", colorHex: "#FF6B6B"),
            isSelected: true,
            onTap: {}
        )
    }
}

