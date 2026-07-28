import Foundation
import UIKit

let checker = UITextChecker()
let text = "I went o the mall"
let range = NSRange(location: 7, length: 1)
if let guesses = checker.guesses(forWordRange: range, in: text, language: "en_US") {
    print(guesses)
}
