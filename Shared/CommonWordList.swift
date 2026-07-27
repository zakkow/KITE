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
        "end","send","sand","land","hand","band","stand","understand","yes","yet","year","young","yours","yo","hi","hey","ok","am","is",
        "are","was","were","has","had","been","much","many","very","much","too","also","well","good","better","best","bad","worse","worst",
        "here","there","where","when","why","how","what","which","who","whom","whose","this","that","these","those","then","than","thus",
        "such","some","any","every","all","both","half","either","neither","each","few","more","most","other","another","such",
        "own","same","different","similar","certain","sure","true","false","right","wrong","real","fake","good","bad","big","small",
        "long","short","high","low","hard","soft","hot","cold","warm","cool","new","old","young","early","late","fast","slow",
        "happy","sad","angry","mad","glad","tired","sick","well","fine","okay","cool","awesome","great","terrible","horrible",
        "car","bus","train","plane","bike","walk","run","jump","swim","fly","drive","ride","stop","go","wait","hurry",
        "eat","drink","sleep","wake","dream","read","write","speak","talk","listen","hear","see","look","watch","feel","touch",
        "buy","sell","pay","cost","price","money","cash","card","bank","store","shop","mall","market","job","work","office",
        "man","woman","boy","girl","child","kid","baby","person","people","family","friend","mom","dad","mother","father",
        "brother","sister","son","daughter","wife","husband","uncle","aunt","cousin","grandma","grandpa",
        "cat","dog","bird","fish","mouse","horse","cow","pig","sheep","chicken","duck","bear","lion","tiger","elephant",
        "house","home","room","door","window","wall","floor","roof","bed","chair","table","desk","couch","sofa",
        "sun","moon","star","sky","cloud","rain","snow","wind","storm","weather","tree","flower","grass","leaf","plant",
        "book","pen","pencil","paper","note","letter","word","sentence","page","chapter","story","poem",
        "music","song","dance","art","draw","paint","picture","photo","movie","film","video","game","play","sport",
        "thing","stuff","part","piece","whole","lot","bit","little","few","some","many","much","more","most",
        "time","day","night","morning","afternoon","evening","week","month","year","hour","minute","second",
        "always","never","often","sometimes","usually","rarely","seldom","forever","now","then","soon","later",
        "here","there","everywhere","nowhere","somewhere","anywhere","up","down","left","right","front","back",
        "top","bottom","side","edge","corner","middle","center","inside","outside","above","below","under","over",
        "life","death","birth","live","die","dead","alive","born","grow","change","stay","keep","hold","let","make",
        "let","put","take","give","get","have","has","had","do","does","did","done","doing","make","makes","made","making",
        "can","could","will","would","shall","should","may","might","must","ought","need","dare","used","going",
        "about","above","across","after","against","along","among","around","before","behind","below","beneath","beside",
        "between","beyond","down","during","except","from","inside","into","like","near","over","past","since","through",
        "toward","under","until","upon","with","within","without","according","because","instead","out","outside",
        "everything","anything","nothing","something","everyone","anyone","noone","someone","everybody","anybody","nobody",
        "somebody","everything","anything","nothing","something","everywhere","anywhere","nowhere","somewhere"
    ]

    static let contractions: [String: String] = [
        "dont": "don't", "cant": "can't", "wont": "won't", "im": "I'm",
        "youre": "you're", "theyre": "they're", "weve": "we've", "isnt": "isn't",
        "arent": "aren't", "wasnt": "wasn't", "werent": "weren't", "doesnt": "doesn't",
        "didnt": "didn't", "hasnt": "hasn't", "havent": "haven't", "hadnt": "hadn't",
        "couldnt": "couldn't", "shouldnt": "shouldn't", "wouldnt": "wouldn't",
        "thats": "that's", "whats": "what's", "theres": "there's", "lets": "let's"
    ]

    static func hasWordWithPrefix(_ prefix: String) -> Bool {
        let lower = prefix.lowercased()
        return words.contains { $0.hasPrefix(lower) }
    }

    static func isCompleteWord(_ word: String) -> Bool {
        words.contains(word.lowercased())
    }
}
