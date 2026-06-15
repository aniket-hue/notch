import Combine
import SwiftUI

struct CalendarView: View {
    @ObservedObject var service: CalendarService
    @EnvironmentObject var settings: Settings
    @Environment(\.slotContext) private var slot

    @State private var now = Date()

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { now = $0 }
        .onAppear { service.ensureAccess() }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: -1) {
                Text(service.selectedDate.formatted(.dateTime.month(.abbreviated)))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(service.selectedDate.formatted(.dateTime.year()))
                    .font(.system(size: 15, weight: .light, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
            }
            .fixedSize()
            wheel
        }
        .frame(height: 52)
    }

    private var wheel: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let days = (-7 ... 14).compactMap { cal.date(byAdding: .day, value: $0, to: today) }
        return ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(days, id: \.self) { day in
                        dayCell(day, today: today).id(day)
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding(.trailing, -slot.endBleed(.horizontal))
            .edgeFade(.trailing)
            .onAppear { proxy.scrollTo(cal.startOfDay(for: service.selectedDate), anchor: .center) }
            .onChange(of: service.selectedDate) { _, new in
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(cal.startOfDay(for: new), anchor: .center)
                }
            }
        }
    }

    private func dayCell(_ day: Date, today: Date) -> some View {
        let cal = Calendar.current
        let isSelected = cal.isDate(day, inSameDayAs: service.selectedDate)
        let isToday = cal.isDate(day, inSameDayAs: today)
        let numberColor: Color = isSelected ? .white : (isToday ? settings.accentColor : .white.opacity(0.85))
        return Button {
            service.select(day)
        } label: {
            VStack(spacing: 5) {
                Text(day.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .tracking(0.4)
                    .foregroundStyle(Theme.textTertiary)
                ZStack {
                    if isSelected {
                        Circle().fill(settings.accentColor)
                    } else if isToday {
                        Circle().strokeBorder(settings.accentColor.opacity(0.85), lineWidth: 1.5)
                    }
                    Text("\(cal.component(.day, from: day))")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(numberColor)
                }
                .frame(width: 27, height: 27)
            }
            .frame(width: 38)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var content: some View {
        switch service.auth {
        case .denied:
            deniedState
        case .unknown:
            enableState
        case .authorized:
            if service.events.isEmpty { emptyState } else { eventList }
        }
    }

    private var eventList: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(service.events) { event in
                        eventRow(event).id(event.id)
                    }
                }
                .padding(.top, 8)
            }
            .onAppear { scrollToNext(proxy) }
            .onChange(of: service.events) { _, _ in scrollToNext(proxy) }
        }
    }

    private func scrollToNext(_ proxy: ScrollViewProxy) {
        guard Calendar.current.isDateInToday(service.selectedDate),
              let next = service.events.first(where: { $0.end > now }) else { return }
        proxy.scrollTo(next.id, anchor: .top)
    }

    private func eventRow(_ e: CalEvent) -> some View {
        let isToday = Calendar.current.isDateInToday(e.start)
        let ended = isToday && e.end < now
        let isNext = isToday && e.end > now && service.events.first(where: { $0.end > now })?.id == e.id
        return HStack(alignment: .top, spacing: 9) {
            Capsule().fill(e.color)
                .frame(width: 3)
                .frame(maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 2) {
                Text(e.title)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let loc = e.location {
                    Text(loc)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 6)
            if let url = e.meetingURL, !ended {
                joinPill(url)
            }
            timeColumn(e)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 5)
        .background(
            isNext ? settings.accentColor.opacity(0.12) : .clear,
            in: RoundedRectangle(cornerRadius: 8),
        )
        .opacity(ended ? 0.45 : 1)
        .overlay(alignment: .bottom) {
            Rectangle().fill(.white.opacity(0.06))
                .frame(height: 0.5)
                .padding(.horizontal, 5)
        }
        .contentShape(Rectangle())
        .onTapGesture { openInCalendar() }
    }

    private func timeColumn(_ e: CalEvent) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            if e.isAllDay {
                Text("All-day")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
            } else {
                Text(e.start, style: .time)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text(e.end, style: .time)
                    .font(.system(size: 11, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(minWidth: 48, alignment: .trailing)
    }

    private func joinPill(_ url: URL) -> some View {
        Button {
            NSWorkspace.shared.open(url)
        } label: {
            HStack(spacing: 4) {
                Icon(.video, size: 11, weight: 1.8)
                Text("Join").font(.system(size: 10, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(settings.accentColor, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func openInCalendar() {
        if let url = URL(string: "ical://") { NSWorkspace.shared.open(url) }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Icon(.calendarClear, size: 22, weight: 1.8)
                .foregroundStyle(.white.opacity(0.26))
            Text("Nothing scheduled")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var enableState: some View {
        VStack(spacing: 7) {
            Icon(.calendar, size: 22, weight: 1.8)
                .foregroundStyle(.white.opacity(0.3))
            Text("Show your calendar")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
            Button {
                service.ensureAccess()
            } label: {
                Text("Enable")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(settings.accentColor, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var deniedState: some View {
        VStack(spacing: 7) {
            Icon(.lock, size: 22, weight: 1.8)
                .foregroundStyle(.white.opacity(0.3))
            Text("Calendar access needed")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
            Button {
                service.openSystemSettings()
            } label: {
                Text("Open Settings")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(settings.accentColor, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
