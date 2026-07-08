import CoreGraphics

/// Turns raw OCR lines into an editable first guess: a title and a few key
/// points. Deliberately simple — a decent starting point the user then edits.
enum DealHeuristics {
    private static let dayWords = ["monday", "tuesday", "wednesday", "thursday",
                                   "friday", "saturday", "sunday"]
    private static let foodDrinkWords = ["taco", "wing", "burger", "pizza", "beer",
                                         "wine", "cocktail", "happy hour", "pint",
                                         "margarita", "special", "half price",
                                         "half-price", "bottomless", "brunch",
                                         "steak", "sushi", "oyster", "deal"]

    struct Suggestion {
        var title: String
        var keyPoints: String
        var rawText: String
    }

    static func suggest(from lines: [OCRLine]) -> Suggestion {
        let rawText = lines.map(\.text).joined(separator: "\n")

        // Title = the visually largest line (tallest bounding box). Falls back to
        // the first line if heights are all similar.
        let title = lines.max(by: { $0.height < $1.height })?.text ?? ""

        // Key points = lines that look "dealy": a price, a day name, or a
        // food/drink keyword. Keep them short and de-duplicated, minus the title.
        var seen = Set<String>()
        let points = lines
            .map(\.text)
            .filter { $0 != title }
            .filter { isInteresting($0) }
            .filter { seen.insert($0.lowercased()).inserted }
            .prefix(6)

        return Suggestion(
            title: title,
            keyPoints: points.joined(separator: "\n"),
            rawText: rawText
        )
    }

    private static func isInteresting(_ line: String) -> Bool {
        let lower = line.lowercased()
        if line.contains("$") || line.contains("£") || line.contains("€") { return true }
        if dayWords.contains(where: lower.contains) { return true }
        if foodDrinkWords.contains(where: lower.contains) { return true }
        return false
    }

    /// Best-effort guess at deal type from the text, used to pre-select the picker.
    static func guessType(from rawText: String) -> DealType {
        let lower = rawText.lowercased()
        let drink = ["beer", "wine", "cocktail", "pint", "margarita", "happy hour",
                     "bottomless", "spirits"].contains(where: lower.contains)
        let food = ["taco", "wing", "burger", "pizza", "brunch", "steak", "sushi",
                    "oyster", "food"].contains(where: lower.contains)
        switch (food, drink) {
        case (true, true): return .both
        case (false, true): return .drink
        default: return .food
        }
    }
}
