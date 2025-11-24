//
//  CalendarViewModel.swift
//  VocalNotes
//
//  Created by Roberto Mecca on 23/11/2025.
//

import Foundation
import SwiftUI
import Combine

class CalendarViewModel: ObservableObject {
    @Published var currentMonth: Date = Date()
    @Published var selectedDate: Date?
    @Published var daySummaries: [DaySummary] = []
    @Published var selectedTopicFilter: Topic?
    @Published var viewMode: CalendarViewMode = .month
    
    private let storageService: StorageService
    private let calendar = Calendar.current
    
    init(storageService: StorageService = .shared) {
        self.storageService = storageService
    }
    
    // MARK: - Data Loading
    
    func loadMonth() async {
        do {
            daySummaries = try storageService.fetchDaySummaries(for: currentMonth)
        } catch {
            print("Failed to load month: \(error)")
        }
    }
    
    func moveMonth(by offset: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: offset, to: currentMonth) {
            currentMonth = newMonth
            Task {
                await loadMonth()
            }
        }
    }
    
    func goToToday() {
        currentMonth = Date()
        selectedDate = Date()
        Task {
            await loadMonth()
        }
    }
    
    // MARK: - Calendar Helpers
    
    func getDaysInMonth() -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start) else {
            return []
        }
        
        let daysInMonth = calendar.range(of: .day, in: .month, for: currentMonth)?.count ?? 0
        var days: [Date?] = []
        
        // Add padding for days before month starts
        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let paddingDays = (firstWeekday - calendar.firstWeekday + 7) % 7
        days.append(contentsOf: Array(repeating: nil, count: paddingDays))
        
        // Add actual days
        for day in 0..<daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day, to: monthInterval.start) {
                days.append(date)
            }
        }
        
        // Add padding to complete the last week
        let remainingDays = (7 - (days.count % 7)) % 7
        days.append(contentsOf: Array(repeating: nil, count: remainingDays))
        
        return days
    }
    
    func getSummary(for date: Date?) -> DaySummary? {
        guard let date = date else { return nil }
        let dayStart = calendar.startOfDay(for: date)
        return daySummaries.first { calendar.isDate($0.date, inSameDayAs: dayStart) }
    }
    
    func isToday(_ date: Date?) -> Bool {
        guard let date = date else { return false }
        return calendar.isDateInToday(date)
    }
    
    func isSelected(_ date: Date?) -> Bool {
        guard let date = date, let selected = selectedDate else { return false }
        return calendar.isDate(date, inSameDayAs: selected)
    }
    
    var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }
    
    var weekDaySymbols: [String] {
        let formatter = DateFormatter()
        return formatter.veryShortWeekdaySymbols
    }
}

enum CalendarViewMode {
    case month
    case week
}

