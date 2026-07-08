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
        // All seven days share the width equally, so nothing scrolls off-screen.
        HStack(spacing: 5) {
            ForEach(Weekday.allCases) { day in
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

/// Deal card: thumbnail, title, establishment, day summary, type + price.
struct DealCardView: View {
    let deal: Deal

    /// Establishment name is the headline; the deal title becomes the subtitle.
    private var headline: String {
        if let name = deal.establishment?.name, !name.isEmpty { return name }
        return deal.title.isEmpty ? "Untitled deal" : deal.title
    }
    private var subtitle: String? {
        guard deal.establishment?.name.isEmpty == false else { return nil }
        return deal.title.isEmpty ? nil : deal.title
    }

    var body: some View {
        HStack(spacing: 10) {
            thumbnail
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(headline)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    if let price = deal.price, !price.isEmpty {
                        Text(price)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.accent)
                            .lineLimit(1)
                    }
                }
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    Image(systemName: deal.dealType.symbol)
                        .foregroundStyle(deal.dealType.accent)
                    Text(deal.weekdays.weekdaySummary)
                    if let time = deal.timeSummary {
                        Text("·")
                        Text(time)
                    }
                }
                .font(.caption2)
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(1)
            }
        }
        .padding(10)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.secondaryBackground, lineWidth: 1))
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image = ImageStore.load(deal.imageFilename) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(deal.dealType.accent.opacity(0.15))
                .frame(width: 50, height: 50)
                .overlay(Image(systemName: deal.dealType.symbol).foregroundStyle(deal.dealType.accent))
        }
    }
}
