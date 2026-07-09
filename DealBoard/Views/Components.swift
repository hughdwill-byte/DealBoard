import SwiftUI

/// Friendly empty/error state: SF Symbol + short helpful text.
struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 44))
                .foregroundStyle(Theme.accent)
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.text)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 300)
        .padding()
        .accessibilityElement(children: .combine)
    }
}

/// Small pill showing a deal's type with its icon and accent colour.
struct TypeBadge: View {
    let type: DealType
    var body: some View {
        Label(type.label, systemImage: type.symbol)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(type.accent.opacity(0.15), in: Capsule())
            .foregroundStyle(type.accent)
            .accessibilityLabel("\(type.label) deal")
    }
}

/// The weekday chips shown at the top of the home screen and in the editor.
struct WeekdayChips: View {
    @Binding var selection: Set<Int>
    /// When true only one day can be active at a time (home browser).
    var singleSelect = false

    var body: some View {
        // All seven days share the width equally (Mon → Sun), nothing scrolls off.
        HStack(spacing: 5) {
            ForEach(Weekday.mondayFirst) { day in
                let isOn = selection.contains(day.rawValue)
                Button {
                    toggle(day.rawValue)
                } label: {
                    Text(day.narrow)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(isOn ? Theme.accent : Theme.secondaryBackground, in: Capsule())
                        .foregroundStyle(isOn ? Color.white : Theme.text)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day.full)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(.horizontal)
    }

    private func toggle(_ day: Int) {
        if singleSelect {
            selection = [day]
        } else if selection.contains(day) {
            selection.remove(day)
        } else {
            selection.insert(day)
        }
    }
}

/// A single deal within a venue group: title, type, day, time, price and key
/// details. The venue name is the section header, so it isn't repeated here.
struct DealRowView: View {
    let deal: Deal

    private var details: String? {
        var parts: [String] = []
        if deal.dealType == .other, let d = deal.otherDescription, !d.isEmpty { parts.append(d) }
        let points = deal.keyPoints.trimmingCharacters(in: .whitespacesAndNewlines)
        if !points.isEmpty { parts.append(points.replacingOccurrences(of: "\n", with: " · ")) }
        let joined = parts.joined(separator: " · ")
        return joined.isEmpty ? nil : joined
    }

    var body: some View {
        HStack(spacing: 10) {
            thumbnail
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(deal.title.isEmpty ? "Untitled deal" : deal.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.text)
                        .fixedSize(horizontal: false, vertical: true) // wrap, don't truncate
                    Spacer(minLength: 4)
                    // Uniform price shows here; varying prices show per time below.
                    if let price = deal.displayPrice {
                        Text(price)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.accent)
                            .lineLimit(1)
                    }
                }
                HStack(spacing: 6) {
                    TypeBadge(type: deal.dealType)
                    Text(deal.weekdays.weekdaySummary)
                    if !deal.pricesVary, let time = deal.timesLine {
                        Text("·")
                        Label(time, systemImage: "clock").labelStyle(.titleAndIcon)
                    }
                }
                .font(.caption2)
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(2)
                if deal.pricesVary, let priced = deal.pricedTimesLine {
                    Label(priced, systemImage: "clock")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.accent)
                        .lineLimit(2)
                }
                if let details {
                    Text(details)
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(2)
                }
            }
        }
        .padding(10)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.secondaryBackground, lineWidth: 1))
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image = ImageStore.load(deal.imageFilename) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 46, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(deal.dealType.accent.opacity(0.15))
                .frame(width: 46, height: 46)
                .overlay(Image(systemName: deal.dealType.symbol).foregroundStyle(deal.dealType.accent))
        }
    }
}
