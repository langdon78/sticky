import Foundation
import Sticky
import PlaygroundSupport

PlaygroundPage.current.needsIndefiniteExecution = true

let stickyConfig = StickyConfiguration(preloadCache: false, clearDirectory: false, async: false, logStyle: .verbose)
Sticky.configure(with: .custom(stickyConfig))

enum Rating: Int {
    case one = 1
    case two
    case three
    case four
}

extension Rating: Codable {}

struct Candy: Stickable, StickyKey, Equatable {
    typealias Key = Int
    var key: Key {
        return productId
    }
    var productId: Int
    var name: String
    var rating: Rating
}

var candyBar = Candy(productId: 1, name: "Snickers", rating: .four)
candyBar.isStored

candyBar.stickWithKey()

candyBar.name = "Milky Way"

Candy.read()

candyBar.name = "Almond Joy"

candyBar.stickWithKey()

Candy.read()

candyBar.unstick()


print(Sticky.shared.configuration.localDirectory)

Candy.read()
