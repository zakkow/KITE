import Foundation

/// Single shared word list — used by WordPredictionEngine AND
/// LinguisticPlausibilityGate, so they can never drift apart. Fast,
/// reliable, no OS dependency — this is the PRIMARY signal for the
/// linguistic gate specifically, since UITextChecker's completion API
/// alone is known to be sparse/inconsistent.
enum CommonWordList {
    static let words: Set<String> = [
        "the","be","to","of","and","a","in","that","have","i","it","for","not","on","with","he","as","you","do","at",
        "this","but","his","by","from","they","we","say","her","she","or","an","will","my","one","all","would","there","their","what",
        "so","up","out","if","about","who","get","which","go","me","when","make","can","like","time","no","just","him","know","take",
        "people","into","year","your","good","some","could","them","see","other","than","then","now","look","only","come","its","over","think","also",
        "back","after","use","two","how","our","work","first","well","way","even","new","want","because","any","these","give","day","most","us",
        "hello","thanks","please","need","help","today","tomorrow","really","sure","great","love","home","school","food","water","phone","message","call","later","soon",
        "name","names","named","game","same","came","made","cake","lake","fine","find","kind","mind","line","nine",
        "end","send","sand","land","hand","band","stand","understand","yes","yet","year","young","yours"
    ]

    static func hasWordWithPrefix(_ prefix: String) -> Bool {
        let lower = prefix.lowercased()
        return words.contains { $0.hasPrefix(lower) }
    }

    static func isCompleteWord(_ word: String) -> Bool {
        words.contains(word.lowercased())
    }
}
