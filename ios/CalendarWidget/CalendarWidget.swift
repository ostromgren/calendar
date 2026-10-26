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
    guard status == .fullAccess else {
      return CalendarEntry(date: now, events: [], hasCalendarAccess: false)
    }

    let store = EKEventStore()
    let startOfToday = Calendar.current.startOfDay(for: now)
    let end = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
    let predicate = store.predicateForEvents(withStart: startOfToday, end: end, calendars: nil)
    let events = store.events(matching: predicate)
      .filter { $0.endDate > now && $0.startDate < end }
      .sorted { $0.startDate < $1.startDate }
      .prefix(1)
      .map {
        CalendarWidgetEvent(
          id: $0.eventIdentifier ?? UUID().uuidString,
          title: $0.title ?? "Untitled event",
          startDate: $0.startDate,
          isAllDay: $0.isAllDay
        )
      }
    return CalendarEntry(date: now, events: events, hasCalendarAccess: true)
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
