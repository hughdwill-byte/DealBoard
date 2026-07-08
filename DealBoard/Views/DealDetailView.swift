import SwiftUI
import SwiftData

struct DealDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var deal: Deal

    @State private var showingEdit = false
    @State private var showingDeleteConfirm = false
    @State private var showingZoom = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let image = ImageStore.load(deal.imageFilename) {
                    Button { showingZoom = true } label: {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(alignment: .bottomTrailing) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right.magnifyingglass")
                                    .font(.subheadline.weight(.semibold))
                                    .padding(8)
                                    .background(.black.opacity(0.45), in: Circle())
                                    .foregroundStyle(.white)
                                    .padding(10)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Zoom into photo")
                    .fullScreenCover(isPresented: $showingZoom) {
                        PhotoZoomView(image: image)
                    }
                }

                HStack {
                    TypeBadge(type: deal.dealType)
                    if let price = deal.price, !price.isEmpty {
                        Text(price).font(.title3.weight(.bold)).foregroundStyle(Theme.accent)
                    }
                }

                if let place = deal.establishment, !place.name.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Label(place.name, systemImage: "mappin.and.ellipse")
                            .font(.headline)
                            .foregroundStyle(Theme.text)
                        if let specials = place.specials, !specials.isEmpty {
                            Text(specials).font(.subheadline).foregroundStyle(Theme.secondaryText)
                        }
                    }
                }

                infoRow(symbol: "calendar", text: deal.weekdays.weekdaySummary)
                if let time = deal.timeSummary {
                    infoRow(symbol: "clock", text: time)
                }

                if deal.dealType == .other, let desc = deal.otherDescription, !desc.isEmpty {
                    section("What's on") { Text(desc).foregroundStyle(Theme.text) }
                }
                if !deal.keyPoints.isEmpty {
                    section("Key points") {
                        Text(deal.keyPoints).foregroundStyle(Theme.text)
                    }
                }
                if let notes = deal.notes, !notes.isEmpty {
                    section("Notes") { Text(notes).foregroundStyle(Theme.text) }
                }
                if !deal.rawText.isEmpty {
                    section("Extracted text") {
                        Text(deal.rawText)
                            .font(.callout)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }

                Button(role: .destructive) {
                    showingDeleteConfirm = true
                } label: {
                    Label("Delete deal", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .padding(.top, 8)
            }
            .padding()
        }
        .background(Theme.background)
        .navigationTitle(deal.title.isEmpty ? "Deal" : deal.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showingEdit = true }
            }
        }
        .sheet(isPresented: $showingEdit) {
            DealEditorView(deal: deal)
        }
        .confirmationDialog("Delete this deal?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                ImageStore.delete(deal.imageFilename)
                context.delete(deal)
                Haptics.success()
                dismiss()
            }
        }
    }

    private func infoRow(symbol: String, text: String) -> some View {
        Label(text, systemImage: symbol)
            .foregroundStyle(Theme.text)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
            content()
        }
    }
}

#Preview {
    NavigationStack {
        DealDetailView(deal: PreviewData.container.mainContext.firstDeal)
    }
    .modelContainer(PreviewData.container)
}
