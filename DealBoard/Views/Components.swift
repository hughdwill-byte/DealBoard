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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Weekday.allCases) { day in
                    let isOn = selection.contains(day.rawValue)
                    Button {
                        toggle(day.rawValue)
                    } label: {
                        Text(singleSelect ? day.short : day.narrow)
                            .font(.subheadline.weight(.semibold))
                            .frame(minWidth: singleSelect ? 44 : 34, minHeight: 34)
                            .padding(.horizontal, 6)
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

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 4) {
                Text(deal.title.isEmpty ? "Untitled deal" : deal.title)
                    .font(.headline)
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)
                if let name = deal.establishment?.name, !name.isEmpty {
                    Label(name, systemImage: "mappin.and.ellipse")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                }
                HStack(spacing: 8) {
                    TypeBadge(type: deal.dealType)
                    if let price = deal.price, !price.isEmpty {
                        Text(price)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                    }
                }
                HStack(spacing: 6) {
                    Text(deal.weekdays.weekdaySummary)
                    if let time = deal.timeSummary {
                        Text("·")
                        Label(time, systemImage: "clock")
                            .labelStyle(.titleAndIcon)
                    }
                }
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.secondaryBackground, lineWidth: 1))
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image = ImageStore.load(deal.imageFilename) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(deal.dealType.accent.opacity(0.15))
                .frame(width: 64, height: 64)
                .overlay(Image(systemName: deal.dealType.symbol).foregroundStyle(deal.dealType.accent))
        }
    }
}
