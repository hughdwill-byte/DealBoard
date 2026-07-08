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
    @State private var selectedDays: Set<Int> = [Weekday.today.rawValue]
    @State private var price = ""
    @State private var notes = ""
    @State private var establishment: Establishment?

    // Optional time-of-day window
    @State private var hasTime = false
    @State private var startTime = DealEditorView.defaultTime(hour: 17)
    @State private var endTime = DealEditorView.defaultTime(hour: 19)

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
                timeSection
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
                Image(uiImage: image)
                    .resizable().scaledToFit()
                    .frame(maxHeight: 220)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
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
            Picker("Type", selection: $dealType) {
                ForEach(DealType.allCases) { Text($0.label).tag($0) }
            }
            TextField("Price (optional)", text: $price)
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

    private var timeSection: some View {
        Section {
            Toggle("Specific times", isOn: $hasTime.animation())
            if hasTime {
                DatePicker("Starts", selection: $startTime, displayedComponents: .hourAndMinute)
                DatePicker("Ends", selection: $endTime, displayedComponents: .hourAndMinute)
            }
        } header: {
            Text("Time")
        } footer: {
            Text(hasTime
                 ? "For a place with more than one deal at different times, add each as its own deal."
                 : "Leave off for all-day deals.")
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
                Text("Keeps \(establishment!.name) and the photo; clears the day, title and price for the next deal.")
            } else {
                Text("Saves this deal and keeps the photo so you can add another straight away.")
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
        price = deal.price ?? ""
        notes = deal.notes ?? ""
        establishment = deal.establishment
        existingFilename = deal.imageFilename
        image = ImageStore.load(deal.imageFilename)
        hasTime = deal.startMinutes != nil || deal.endMinutes != nil
        if let s = deal.startMinutes { startTime = Self.time(fromMinutes: s) }
        if let e = deal.endMinutes { endTime = Self.time(fromMinutes: e) }
    }
    @State private var isEditingLoaded = false

    private func save(keepGoing: Bool = false) {
        // Persist the photo (if newly picked) and clean up any replaced file.
        var filename = existingFilename
        if let image, existingFilename == nil {
            filename = ImageStore.save(image)
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
        target.price = price.isEmpty ? nil : price
        target.notes = notes.isEmpty ? nil : notes
        target.startMinutes = hasTime ? Self.minutes(from: startTime) : nil
        target.endMinutes = hasTime ? Self.minutes(from: endTime) : nil
        target.imageFilename = filename
        target.establishment = establishment

        Haptics.success()

        if keepGoing {
            // Ready the form for the next deal at the same place: keep the
            // establishment and photo, clear the per-deal fields.
            title = ""; keyPoints = ""; price = ""; notes = ""
            selectedDays = [Weekday.today.rawValue]
            hasTime = false
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
