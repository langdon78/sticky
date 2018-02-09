//: Playground - noun: a place where people can play

import UIKit
import Sticky
import PlaygroundSupport

PlaygroundPage.current.needsIndefiniteExecution = true

let stickyConfig = StickyConfiguration(preloadCache: false, clearDirectory: true, async: false, logging: true)
Sticky.configure(with: .custom(stickyConfig))

enum Rating: Int {
    case one = 1
    case two
    case three
    case four
}

extension Rating: Codable {}

struct Candy: Stickable {
    var productId: Int
    var name: String
    var rating: Rating
}

// Needs to conform to Equatable
extension Candy: Equatable {
    static func == (lhs: Candy, rhs: Candy) -> Bool {
        return
            lhs.productId == rhs.productId &&
                lhs.name == rhs.name &&
                lhs.rating == rhs.rating
    }
}

var candyBar = Candy(productId: 1, name: "Snickers", rating: .four)
candyBar.isStored

candyBar.stick()

candyBar.name = "Milky Way"

Candy.read()

extension Candy: StickyKey {
    struct Key: Equatable {
        var productId: Int

        static func ==(lhs: Key, rhs: Key) -> Bool {
            return lhs.productId == rhs.productId
        }
    }

    var key: Candy.Key {
        return Candy.Key(productId: self.productId)
    }
}

candyBar.name = "Almond Joy"

candyBar.stickWithKey()

Candy.read()

candyBar.unstick()

Candy.read()
print(Sticky.shared.configuration.localDirectory)

