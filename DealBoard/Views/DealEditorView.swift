import SwiftUI
import SwiftData
import PhotosUI
import CoreLocation

/// Add or edit a deal. Works fully offline; the photo → OCR → establishment
/// pipeline is all optional enrichment layered on top of manual entry.
struct DealEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// nil = adding a new deal; non-nil = editing an existing one.
    let deal: Deal?
    /// When adding, pre-selects this establishment (e.g. "add another deal here").
    var prefillEstablishment: Establishment? = nil

    // Editable fields
    @State private var title = ""
    @State private var keyPoints = ""
    @State private var rawText = ""
    @State private var dealType: DealType = .food
    @State private var selectedDays: Set<Int> = []   // no day selected by default
    @State private var notes = ""
    @State private var otherDescription = ""
    @State private var establishment: Establishment?
    @State private var showingZoom = false

    // One or more time windows, each with its own optional price.
    @State private var slots: [EditSlot] = [EditSlot()]

    /// A time+price window while editing (Dates drive the pickers).
    struct EditSlot: Identifiable {
        let id = UUID()
        var price: String = ""
        var hasTime: Bool = false
        var start: Date = DealEditorView.defaultTime(hour: 17)
        var end: Date = DealEditorView.defaultTime(hour: 19)
    }

    // Photo / OCR
    @State private var image: UIImage?
    @State private var existingFilename: String?
    @State private var photoItem: PhotosPickerItem?
    @State private var isProcessing = false
    @State private var ocrFoundNothing = false
    @State private var showingCamera = false

    // Establishment matching
    @State private var photoCoordinate: CLLocationCoordinate2D?
    @State private var showingEstablishmentPicker = false

    private var isEditing: Bool { deal != nil }

    var body: some View {
        NavigationStack {
            Form {
                photoSection
                detailsSection
                daysSection
                timesAndPricesSection
                establishmentSection
                if !rawText.isEmpty { rawTextSection }
                if !isEditing { saveAndAddSection }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle(isEditing ? "Edit Deal" : "New Deal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showingCamera) {
                CameraPicker { captured in
                    Task { await handlePicked(image: captured, item: nil) }
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showingEstablishmentPicker) {
                EstablishmentPickerView(coordinate: photoCoordinate, selection: $establishment)
            }
            .fullScreenCover(isPresented: $showingZoom) {
                if let image { PhotoZoomView(image: image) }
            }
            .onAppear(perform: loadExisting)
            .onChange(of: photoItem) { _, newItem in
                guard let newItem else { return }
                Task { await handlePicked(item: newItem) }
            }
            .tint(Theme.accent)
        }
    }

    // MARK: Sections

    private var photoSection: some View {
        Section {
            if let image {
                Button {
                    showingZoom = true
                } label: {
                    Image(uiImage: image)
                        .resizable().scaledToFit()
                        .frame(maxHeight: 220)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right.magnifyingglass")
                                .font(.caption.weight(.semibold))
                                .padding(6)
                                .background(.black.opacity(0.45), in: Circle())
                                .foregroundStyle(.white)
                                .padding(8)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Zoom into photo")
            }
            HStack {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("Photo Library", systemImage: "photo")
                }
                .buttonStyle(.borderless) // isolate hit region from the Camera button
                Spacer()
                Button {
                    showingCamera = true
                } label: {
                    Label("Camera", systemImage: "camera")
                }
                .buttonStyle(.borderless) // otherwise the Form row merges both taps
                .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
            }
            if isProcessing {
                Label("Reading text…", systemImage: "text.viewfinder")
                    .foregroundStyle(Theme.secondaryText)
            }
            if ocrFoundNothing {
                Label("No text found — type the details in by hand.", systemImage: "exclamationmark.bubble")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
            }
        } header: {
            Text("Photo (optional)")
        }
    }

    private var detailsSection: some View {
        Section("Details") {
            TextField("Title", text: $title)
                .textInputAutocapitalization(.words)   // capitalise each word
            Picker("Type", selection: $dealType) {
                ForEach(DealType.allCases) { Text($0.label).tag($0) }
            }
            if dealType == .other {
                VStack(alignment: .leading) {
                    Text("What's on").font(.caption).foregroundStyle(Theme.secondaryText)
                    TextField("e.g. Trivia night, live poker, comedy", text: $otherDescription,
                              axis: .vertical)
                        .lineLimit(1...3)
                }
            }
            VStack(alignment: .leading) {
                Text("Key points").font(.caption).foregroundStyle(Theme.secondaryText)
                TextField("One per line", text: $keyPoints, axis: .vertical)
                    .lineLimit(2...6)
            }
            VStack(alignment: .leading) {
                Text("Notes (optional)").font(.caption).foregroundStyle(Theme.secondaryText)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(1...4)
            }
        }
    }

    /// Ensure every number in the price carries a "$": "10" → "$10",
    /// "10-15" → "$10-$15". Idempotent and tolerant of partial input
    /// (a trailing "-" while typing is preserved).
    static func formatPrice(_ raw: String) -> String {
        guard !raw.isEmpty else { return "" }
        return raw.components(separatedBy: "-").map { part -> String in
            let stripped = part.replacingOccurrences(of: "$", with: "")
                .trimmingCharacters(in: .whitespaces)
            return stripped.isEmpty ? "" : "$\(stripped)"
        }.joined(separator: "-")
    }

    private var daysSection: some View {
        Section("Runs on") {
            WeekdayChips(selection: $selectedDays)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            if selectedDays.isEmpty {
                Text("Pick at least one day.")
                    .font(.footnote).foregroundStyle(.red)
            }
        }
    }

    private var timesAndPricesSection: some View {
        Section {
            ForEach($slots) { $slot in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Price").foregroundStyle(Theme.secondaryText)
                        Spacer()
                        TextField("Free / optional", text: $slot.price)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numbersAndPunctuation)
                            .onChange(of: slot.price) { _, newValue in
                                slot.price = Self.formatPrice(newValue)
                            }
                    }
                    Toggle("All day", isOn: Binding(
                        get: { !$slot.hasTime.wrappedValue },
                        set: { $slot.hasTime.wrappedValue = !$0 }
                    ).animation())
                    if slot.hasTime {
                        DatePicker("Starts", selection: $slot.start, displayedComponents: .hourAndMinute)
                        DatePicker("Ends", selection: $slot.end, displayedComponents: .hourAndMinute)
                    }
                    if slots.count > 1 {
                        Button(role: .destructive) {
                            slots.removeAll { $0.id == slot.id }
                        } label: {
                            Label("Remove this time", systemImage: "minus.circle")
                                .font(.footnote)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.vertical, 2)
            }
            Button {
                slots.append(EditSlot())
            } label: {
                Label("Add another time / price", systemImage: "plus.circle")
            }
        } header: {
            Text("Times & prices")
        } footer: {
            Text("Add more than one to combine a repeated deal — e.g. $6 from 4–6pm and $8 from 8–10pm at the same place on the same day.")
        }
    }

    private var establishmentSection: some View {
        Section("Establishment") {
            Button {
                showingEstablishmentPicker = true
            } label: {
                HStack {
                    Label(establishment?.name ?? "Choose establishment",
                          systemImage: "mappin.and.ellipse")
                        .foregroundStyle(establishment == nil ? Theme.secondaryText : Theme.text)
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(Theme.secondaryText)
                }
            }
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && !selectedDays.isEmpty
    }

    /// Save this deal and immediately start another at the same place — the quick
    /// way to enter e.g. steak Tue, parma Wed, pasta Thu for one establishment.
    private var saveAndAddSection: some View {
        Section {
            Button {
                save(keepGoing: true)
            } label: {
                Label("Save & add another here", systemImage: "plus.square.on.square")
                    .frame(maxWidth: .infinity)
            }
            .disabled(!canSave)
        } footer: {
            if establishment != nil {
                Text("Keeps \(establishment!.name), the photo and key points; clears the title, day and times for the next deal.")
            } else {
                Text("Saves this deal and keeps the photo and key points so you can add another straight away.")
            }
        }
    }

    private var rawTextSection: some View {
        Section("Extracted text") {
            TextField("Raw text", text: $rawText, axis: .vertical)
                .lineLimit(3...10)
                .font(.callout)
                .foregroundStyle(Theme.secondaryText)
        }
    }

    // MARK: Load / Save

    private func loadExisting() {
        guard !isEditingLoaded else { return }
        isEditingLoaded = true
        guard let deal else {
            // New deal — carry over a pre-selected establishment if given.
            establishment = prefillEstablishment
            return
        }
        title = deal.title
        keyPoints = deal.keyPoints
        rawText = deal.rawText
        dealType = deal.dealType
        selectedDays = Set(deal.weekdays)
        notes = deal.notes ?? ""
        otherDescription = deal.otherDescription ?? ""
        establishment = deal.establishment
        existingFilename = deal.imageFilename
        image = ImageStore.load(deal.imageFilename)
        slots = deal.orderedSlots.map { ts in
            EditSlot(
                price: ts.price ?? "",
                hasTime: ts.startMinutes != nil || ts.endMinutes != nil,
                start: ts.startMinutes.map(Self.time(fromMinutes:)) ?? Self.defaultTime(hour: 17),
                end: ts.endMinutes.map(Self.time(fromMinutes:)) ?? Self.defaultTime(hour: 19)
            )
        }
        if slots.isEmpty { slots = [EditSlot()] }
    }
    @State private var isEditingLoaded = false

    /// Convert the editable slots into stored TimeSlots.
    private func buildSlots() -> [TimeSlot] {
        slots.map { s in
            let price = s.price.trimmingCharacters(in: .whitespaces)
            return TimeSlot(
                startMinutes: s.hasTime ? Self.minutes(from: s.start) : nil,
                endMinutes: s.hasTime ? Self.minutes(from: s.end) : nil,
                price: price.isEmpty ? nil : price
            )
        }
    }

    private func save(keepGoing: Bool = false) {
        // Persist the photo (if newly picked).
        var filename = existingFilename
        if let image, existingFilename == nil {
            filename = ImageStore.save(image)
        }
        let newSlots = buildSlots()

        // Combine with an existing identical deal (same place/day/title/details)
        // instead of creating a duplicate — for new deals only.
        if deal == nil, let match = findMatchingDeal() {
            match.timeSlots = DealMerger.combinedSlots(existing: match.orderedSlots, adding: newSlots)
            DealMerger.syncLegacyFields(of: match)
            if match.imageFilename == nil { match.imageFilename = filename }
            else if let filename, filename != match.imageFilename { ImageStore.delete(filename) }
            finish(keepGoing: keepGoing)
            return
        }

        let target: Deal
        if let deal {
            target = deal
        } else {
            target = Deal()
            context.insert(target)
        }
        target.title = title.trimmingCharacters(in: .whitespaces)
        target.keyPoints = keyPoints
        target.rawText = rawText
        target.dealType = dealType
        target.weekdays = Array(selectedDays).sorted()
        target.notes = notes.isEmpty ? nil : notes
        target.otherDescription = (dealType == .other && !otherDescription.trimmingCharacters(in: .whitespaces).isEmpty)
            ? otherDescription : nil
        target.timeSlots = newSlots
        target.imageFilename = filename
        target.establishment = establishment
        DealMerger.syncLegacyFields(of: target)

        finish(keepGoing: keepGoing)
    }

    /// Find an existing deal this new one should combine into (same identity key).
    private func findMatchingDeal() -> Deal? {
        let key = DealMerger.identityKey(
            establishmentID: establishment?.id,
            weekdays: Array(selectedDays).sorted(),
            title: title.trimmingCharacters(in: .whitespaces),
            dealTypeRaw: dealType.rawValue,
            keyPoints: keyPoints,
            notes: notes.isEmpty ? nil : notes,
            otherDescription: (dealType == .other && !otherDescription.trimmingCharacters(in: .whitespaces).isEmpty) ? otherDescription : nil
        )
        let all = (try? context.fetch(FetchDescriptor<Deal>())) ?? []
        return all.first { DealMerger.identityKey($0) == key }
    }

    private func finish(keepGoing: Bool) {
        Haptics.success()
        if keepGoing {
            // Ready the form for the next deal at the same place. Keep the
            // establishment, photo and key points (often shared across a venue's
            // deals); clear the fields that differ per deal.
            title = ""; notes = ""
            selectedDays = []
            slots = [EditSlot()]
            existingFilename = nil  // next save writes its own copy of the photo
        } else {
            dismiss()
        }
    }

    // MARK: Time <-> minutes helpers

    static func defaultTime(hour: Int) -> Date {
        Calendar.current.date(from: DateComponents(hour: hour, minute: 0)) ?? Date()
    }
    static func time(fromMinutes m: Int) -> Date {
        Calendar.current.date(from: DateComponents(hour: m / 60, minute: m % 60)) ?? Date()
    }
    static func minutes(from date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    // MARK: Photo handling

    private func handlePicked(item: PhotosPickerItem) async {
        // Load the original data so EXIF (incl. GPS) survives the import.
        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else { return }
        await handlePicked(image: uiImage, data: data, item: item)
    }

    private func handlePicked(image uiImage: UIImage, data: Data? = nil, item: PhotosPickerItem?) async {
        isProcessing = true
        ocrFoundNothing = false
        image = uiImage
        existingFilename = nil    // new photo replaces any prior one on save

        // 1) On-device OCR + heuristic suggestions.
        let lines = await OCRService.recognize(in: uiImage)
        if lines.isEmpty {
            ocrFoundNothing = true
        } else {
            let suggestion = DealHeuristics.suggest(from: lines)
            // Only fill empty fields so we never clobber the user's edits.
            if title.isEmpty { title = suggestion.title }
            if keyPoints.isEmpty { keyPoints = suggestion.keyPoints }
            rawText = suggestion.rawText
            dealType = DealHeuristics.guessType(from: suggestion.rawText)
        }

        // 2) Try to recover a coordinate for establishment matching.
        var coordinate: CLLocationCoordinate2D?
        if let data { coordinate = PhotoMetadata.coordinate(fromImageData: data) }
        if coordinate == nil {
            coordinate = await PhotoMetadata.coordinate(fromAssetIdentifier: item?.itemIdentifier)
        }
        photoCoordinate = coordinate

        isProcessing = false
    }
}

#Preview {
    DealEditorView(deal: nil)
        .modelContainer(PreviewData.container)
}
