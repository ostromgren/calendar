import EventKit
import SwiftUI
import WidgetKit

private struct CalendarEntry: TimelineEntry {
  let date: Date
  let events: [CalendarWidgetEvent]
  let hasCalendarAccess: Bool
}

private struct CalendarWidgetEvent: Identifiable {
  let id: String
  let title: String
  let startDate: Date
  let isAllDay: Bool
}

private struct CalendarProvider: TimelineProvider {
  private let appGroupIdentifier = "group.com.example.calendar"

  func placeholder(in context: Context) -> CalendarEntry {
    CalendarEntry(
      date: .now,
      events: [
        CalendarWidgetEvent(
          id: "placeholder",
          title: "Team meeting",
          startDate: .now,
          isAllDay: false
        )
      ],
      hasCalendarAccess: true
    )
  }

  func getSnapshot(in context: Context, completion: @escaping (CalendarEntry) -> Void) {
    completion(makeEntry())
  }

  func getTimeline(
    in context: Context,
    completion: @escaping (Timeline<CalendarEntry>) -> Void
  ) {
    let entry = makeEntry()
    let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
    completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
  }

  private func makeEntry() -> CalendarEntry {
    let now = Date()
    let status = EKEventStore.authorizationStatus(for: .event)
    let startOfToday = Calendar.current.startOfDay(for: now)
    let end = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
    let localEvents = loadLocalEvents(from: startOfToday, through: end, after: now)
    guard status == .fullAccess else {
      return CalendarEntry(date: now, events: localEvents, hasCalendarAccess: false)
    }

    let store = EKEventStore()
    let predicate = store.predicateForEvents(withStart: startOfToday, end: end, calendars: nil)
    let deviceEvents = store.events(matching: predicate)
      .filter { $0.endDate > now && $0.startDate < end }
      .sorted { $0.startDate < $1.startDate }
      .map {
        CalendarWidgetEvent(
          id: "\($0.eventIdentifier ?? UUID().uuidString)-\($0.startDate.timeIntervalSince1970)",
          title: $0.title ?? "Untitled event",
          startDate: $0.startDate,
          isAllDay: $0.isAllDay
        )
      }
    let events = (deviceEvents + localEvents).sorted {
      $0.startDate < $1.startDate
    }
    return CalendarEntry(date: now, events: events, hasCalendarAccess: true)
  }

  private func loadLocalEvents(
    from start: Date,
    through end: Date,
    after now: Date
  ) -> [CalendarWidgetEvent] {
    guard
      let encoded = UserDefaults(suiteName: appGroupIdentifier)?
        .string(forKey: "localCalendarEvents"),
      let data = encoded.data(using: .utf8),
      let values = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
    else {
      return []
    }

    return values.flatMap { value -> [CalendarWidgetEvent] in
      guard
        let id = value["id"] as? String,
        let title = value["title"] as? String,
        let startDate = parseDate(value["startTime"]),
        let endDate = parseDate(value["endTime"])
      else {
        return []
      }

      let isAllDay = value["isAllDay"] as? Bool ?? false
      let frequency = value["recurrenceFrequency"] as? String
      let recurrenceEnd = parseDate(value["recurrenceEndDate"])
      let excludedDates = Set(value["excludedOccurrenceDates"] as? [String] ?? [])
      let duration = endDate.timeIntervalSince(startDate)
      var occurrences: [CalendarWidgetEvent] = []
      var index = 0

      while true {
        guard let occurrenceStart = occurrenceStart(
          original: startDate,
          frequency: frequency,
          index: index
        ) else {
          break
        }
        if occurrenceStart >= end { break }
        if let recurrenceEnd,
           Calendar.current.startOfDay(for: occurrenceStart) >
            Calendar.current.startOfDay(for: recurrenceEnd) {
          break
        }
        if occurrenceStart.addingTimeInterval(duration) > now,
           occurrenceStart >= start || occurrenceStart.addingTimeInterval(duration) > start {
          let dateKey = localDateKey(occurrenceStart)
          if !excludedDates.contains(dateKey) {
            occurrences.append(
              CalendarWidgetEvent(
                id: "\(id)-\(occurrenceStart.timeIntervalSince1970)",
                title: title,
                startDate: occurrenceStart,
                isAllDay: isAllDay
              )
            )
          }
        }
        if frequency == nil { break }
        index += 1
      }
      return occurrences
    }
  }

  private func occurrenceStart(
    original: Date,
    frequency: String?,
    index: Int
  ) -> Date? {
    guard index > 0 else { return original }
    guard let frequency else { return nil }
    var components = Calendar.current.dateComponents(
      [.year, .month, .day, .hour, .minute, .second],
      from: original
    )
    switch frequency {
    case "weekly", "everyTwoWeeks", "everyThreeWeeks":
      let interval = switch frequency {
      case "everyTwoWeeks": 2
      case "everyThreeWeeks": 3
      default: 1
      }
      return Calendar.current.date(byAdding: .weekOfYear, value: interval * index, to: original)
    case "monthly":
      let targetMonth = (components.month ?? 1) - 1 + index
      let year = (components.year ?? 1) + targetMonth / 12
      let month = targetMonth % 12 + 1
      guard
        let firstOfMonth = Calendar.current.date(
          from: DateComponents(year: year, month: month, day: 1)
        ),
        let days = Calendar.current.range(of: .day, in: .month, for: firstOfMonth)
      else {
        return nil
      }
      components.year = year
      components.month = month
      components.day = min(components.day ?? 1, days.count)
      return Calendar.current.date(from: components)
    default:
      return nil
    }
  }

  private func parseDate(_ value: Any?) -> Date? {
    guard let value = value as? String else { return nil }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current
    for format in [
      "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
      "yyyy-MM-dd'T'HH:mm:ssXXXXX",
      "yyyy-MM-dd'T'HH:mm:ss.SSS",
      "yyyy-MM-dd'T'HH:mm:ss",
    ] {
      formatter.dateFormat = format
      if let date = formatter.date(from: value) { return date }
    }
    return nil
  }

  private func localDateKey(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
  }
}

private struct CalendarWidgetView: View {
  let entry: CalendarEntry
  @Environment(\.widgetFamily) private var family

  var body: some View {
    HStack(spacing: 14) {
      dateColumn
        .frame(width: family == .systemSmall ? nil : 72)

      if family != .systemSmall {
        Rectangle()
          .fill(.primary.opacity(0.14))
          .frame(width: 1)

        VStack(alignment: .leading, spacing: 12) {
          eventRow
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(.horizontal, 16)
    .padding(.vertical, 16)
    .containerBackground(.background, for: .widget)
  }

  private var dateColumn: some View {
    VStack(spacing: 2) {
      Text(entry.date, format: .dateTime.day())
        .font(.system(size: 46, weight: .bold, design: .rounded))
        .monospacedDigit()
        .minimumScaleFactor(0.7)
        .lineLimit(1)
      Text(entry.date, format: .dateTime.month(.abbreviated))
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.secondary)
        .lineLimit(1)
      if family == .systemSmall, additionalEventsOnFirstDay > 0 {
        Text("+\(additionalEventsOnFirstDay) more")
          .font(.system(size: 10, weight: .medium))
          .foregroundStyle(.tint)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }
    }
    .frame(maxWidth: .infinity)
  }

  @ViewBuilder
  private var eventRow: some View {
    if let event = entry.events.first {
      VStack(alignment: .leading, spacing: 3) {
        Text(eventSummary(for: event))
          .font(.caption.weight(.semibold))
          .foregroundStyle(.tint)
          .lineLimit(1)
        Text(event.title)
          .font(.subheadline.weight(.medium))
          .lineLimit(2)
          .multilineTextAlignment(.leading)
        if additionalEventsOnFirstDay > 0 {
          Text("+\(additionalEventsOnFirstDay) more that day")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }
    } else {
      Text(
        entry.hasCalendarAccess
          ? "No upcoming events"
          : "Open Calendar to allow calendar access"
      )
      .font(.subheadline)
      .foregroundStyle(.secondary)
      .lineLimit(3)
    }
  }

  private func eventSummary(for event: CalendarWidgetEvent) -> String {
    let time = event.isAllDay
      ? "All day"
      : event.startDate.formatted(date: .omitted, time: .shortened)
    guard
      event.startDate >= entry.date,
      let dateLimit = Calendar.current.date(byAdding: .day, value: 7, to: entry.date),
      event.startDate < dateLimit
    else {
      return time
    }

    let date = event.startDate.formatted(date: .abbreviated, time: .omitted)
    return "\(date) · \(time)"
  }

  private var additionalEventsOnFirstDay: Int {
    guard let firstEvent = entry.events.first else { return 0 }
    return max(
      0,
      entry.events.filter {
        Calendar.current.isDate($0.startDate, inSameDayAs: firstEvent.startDate)
      }.count - 1
    )
  }
}

@main
struct CalendarWidget: Widget {
  let kind = "CalendarWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: CalendarProvider()) { entry in
      CalendarWidgetView(entry: entry)
    }
    .configurationDisplayName("Calendar")
    .description("Today's date and your next events.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
