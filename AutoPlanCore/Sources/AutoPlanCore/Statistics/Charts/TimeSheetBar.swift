//
//  TimeSheetBar.swift
//  AutoPlan
//
//  Created by 荣子鱼 on 2026/5/20.
//

import Charts
import SwiftUI
import Foundation

// MARK: - TimeSheetBar
/// 周日程时间条形图表，展示不同列表的日程在每天的时间分布。
public struct TimeSheetBar: View {
    let events: [EventEntry]
    var firstWeekday: Int? /// 1: Sunday 2: Monday
    var chartHeight: CGFloat = 200
    var listOrder: [String]? = nil
    public init(
        events: [EventEntry],
        firstWeekday: Int? = nil,
        chartHeight: CGFloat = 200,
        listOrder: [String]? = nil
    ) {
        self.events = events
        self.firstWeekday = firstWeekday
        self.chartHeight = chartHeight
        self.listOrder = listOrder
    }
    public var body: some View {
        let validEvents = events.filter { $0.startTime != nil && $0.endTime != nil }
        let range = weekRange(validEvents: validEvents)
        let weekEvents = validEvents.filter {
            $0.startTime! >= range.start && $0.startTime! < range.end
        }

        let yDomain: [String] = {
            let allDepts = Set(weekEvents.map(\.listName))
            if let order = listOrder {
                let ordered = order.filter { allDepts.contains($0) }
                let missing = allDepts.subtracting(order).sorted()
                return ordered + missing
            } else {
                return allDepts.sorted()
            }
        }()

        let listColors: [String: Color] = {
            var dict = [String: Color]()
            for event in weekEvents {
                guard dict[event.listName] == nil else { continue }
                dict[event.listName] = Color(hex: event.listColorHex)
            }
            return dict
        }()

        return VStack(alignment: .leading, spacing: 10) {
            Text(range.title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Divider()
            Text("Total: \(totalDuration(weekEvents))")
                .font(.title3.bold())

            Chart {
                ForEach(weekEvents, id: \.id) { event in
                    BarMark(
                        xStart: .value("Start", event.startTime!),
                        xEnd: .value("End", event.endTime!),
                        y: .value("Department", event.listName),
                        height: .fixed(13)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .foregroundStyle(
                        (listColors[event.listName] ?? .gray).gradient
                    )
                }
            }
            .chartBackground { _ in
                Color.white
            }
            .frame(height: chartHeight)
            .chartXScale(domain: range.start...range.end)
            .chartYScale(domain: yDomain)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day))
            }
        }
        .padding()
    }

    // MARK: - Helpers

    private var calendar: Calendar {
        var cal = Calendar.current
        if let firstWeekday { cal.firstWeekday = firstWeekday }
        return cal
    }

    private func weekRange(validEvents: [EventEntry]) -> (title: String, start: Date, end: Date) {
        guard let earliest = validEvents.compactMap(\.startTime).min() else {
            return ("No Data", Date(), Date().addingTimeInterval(7 * 86400))
        }
        let weekOfYear = calendar.component(.weekOfYear, from: earliest)
        let year = calendar.component(.year, from: earliest)
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: earliest) else {
            return ("Week \(weekOfYear) - \(year)", earliest, earliest.addingTimeInterval(7 * 86400))
        }
        return ("Week \(weekOfYear) - \(year)", weekInterval.start, weekInterval.end)
    }

    private func totalDuration(_ events: [EventEntry]) -> String {
        let total = events.reduce(0.0) { $0 + $1.startTime!.distance(to: $1.endTime!) }
        return Self.getFormattedDuration(seconds: total)
    }

    static func getFormattedDuration(seconds: Double) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .pad
        formatter.allowedUnits = [.hour, .minute]
        return formatter.string(from: seconds) ?? "N/A"
    }
}

// MARK: - Preview Data (migrated to EventEntry)

public func date(year: Int, month: Int, day: Int = 1, hour: Int = 0, minutes: Int = 0, seconds: Int = 0) -> Date {
    Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minutes, second: seconds)) ?? Date()
}

public enum TimeSheetData {
    public static let lastWeek: [EventEntry] = [
        // Monday
        makeEntry(listName: "Bread", hex: "#FFD700",
                  start: date(year: 2022, month: 6, day: 13, hour: 08, minutes: 00),
                  end:   date(year: 2022, month: 6, day: 13, hour: 09, minutes: 28)),
        makeEntry(listName: "Bread", hex: "#FFD700",
                  start: date(year: 2022, month: 6, day: 13, hour: 09, minutes: 47),
                  end:   date(year: 2022, month: 6, day: 13, hour: 12, minutes: 04)),
        makeEntry(listName: "Butchery", hex: "#FF0000",
                  start: date(year: 2022, month: 6, day: 13, hour: 13, minutes: 01),
                  end:   date(year: 2022, month: 6, day: 13, hour: 15, minutes: 10)),
        makeEntry(listName: "hey", hex: "#0000FF",
                  start: date(year: 2022, month: 6, day: 13, hour: 13, minutes: 01),
                  end:   date(year: 2022, month: 6, day: 13, hour: 15, minutes: 10)),
        makeEntry(listName: "Butchery", hex: "#FF0000",
                  start: date(year: 2022, month: 6, day: 13, hour: 15, minutes: 33),
                  end:   date(year: 2022, month: 6, day: 13, hour: 17, minutes: 01)),
        makeEntry(listName: "Vegetables", hex: "#00FF00",
                  start: date(year: 2022, month: 6, day: 13, hour: 17, minutes: 02),
                  end:   date(year: 2022, month: 6, day: 13, hour: 18, minutes: 08)),
        // Tuesday
        makeEntry(listName: "Bread", hex: "#FFD700",
                  start: date(year: 2022, month: 6, day: 14, hour: 08, minutes: 00),
                  end:   date(year: 2022, month: 6, day: 14, hour: 09, minutes: 28)),
        makeEntry(listName: "Bread", hex: "#FFD700",
                  start: date(year: 2022, month: 6, day: 14, hour: 09, minutes: 47),
                  end:   date(year: 2022, month: 6, day: 14, hour: 12, minutes: 04)),
        makeEntry(listName: "Bread", hex: "#FFD700",
                  start: date(year: 2022, month: 6, day: 14, hour: 13, minutes: 01),
                  end:   date(year: 2022, month: 6, day: 14, hour: 15, minutes: 10)),
        makeEntry(listName: "Bread", hex: "#FFD700",
                  start: date(year: 2022, month: 6, day: 14, hour: 15, minutes: 33),
                  end:   date(year: 2022, month: 6, day: 14, hour: 17, minutes: 01)),
        // Wednesday
        makeEntry(listName: "Counter", hex: "#000000",
                  start: date(year: 2022, month: 6, day: 15, hour: 15, minutes: 58),
                  end:   date(year: 2022, month: 6, day: 15, hour: 18, minutes: 34)),
        makeEntry(listName: "Counter", hex: "#000000",
                  start: date(year: 2022, month: 6, day: 15, hour: 19, minutes: 03),
                  end:   date(year: 2022, month: 6, day: 15, hour: 22, minutes: 10)),
        // Friday
        makeEntry(listName: "Vegetables", hex: "#00FF00",
                  start: date(year: 2022, month: 6, day: 17, hour: 05, minutes: 15),
                  end:   date(year: 2022, month: 6, day: 17, hour: 06, minutes: 01)),
        makeEntry(listName: "Vegetables", hex: "#00FF00",
                  start: date(year: 2022, month: 6, day: 17, hour: 06, minutes: 33),
                  end:   date(year: 2022, month: 6, day: 17, hour: 08, minutes: 52)),
        makeEntry(listName: "Vegetables", hex: "#00FF00",
                  start: date(year: 2022, month: 6, day: 17, hour: 09, minutes: 15),
                  end:   date(year: 2022, month: 6, day: 17, hour: 11, minutes: 46)),
        makeEntry(listName: "Vegetables", hex: "#00FF00",
                  start: date(year: 2022, month: 6, day: 17, hour: 12, minutes: 58),
                  end:   date(year: 2022, month: 6, day: 17, hour: 14, minutes: 26)),
        makeEntry(listName: "Vegetables", hex: "#00FF00",
                  start: date(year: 2022, month: 6, day: 17, hour: 15, minutes: 05),
                  end:   date(year: 2022, month: 6, day: 17, hour: 15, minutes: 52)),
        makeEntry(listName: "Vegetables", hex: "#00FF00",
                  start: date(year: 2022, month: 6, day: 17, hour: 19, minutes: 33),
                  end:   date(year: 2022, month: 6, day: 17, hour: 21, minutes: 01))
    ]

    // 工厂方法：快速生成预览 EventEntry
    private static func makeEntry(listName: String, hex: String, start: Date, end: Date) -> EventEntry {
        EventEntry(
            id: UUID().uuidString,
            title: listName,
            type: .event,
            isAllDayReminder: false,
            startTime: start,
            endTime: end,
            dueDate: nil,
            completionDate: nil,
            isCompleted: false,
            recurrenceRule: nil,
            listName: listName,
            listID: "",
            listColorHex: hex,
            notes: nil,
            location: nil,
            url: nil
        )
    }
}

// MARK: - Preview

struct TimeSheetBar_Previews: PreviewProvider {
    static var previews: some View {
        TimeSheetBar(events: TimeSheetData.lastWeek, firstWeekday: 2)
    }
}
