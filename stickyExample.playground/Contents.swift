//: Playground - noun: a place where people can play

import UIKit
import Sticky

let stickyConfig = StickyConfiguration(async: false, logging: true)
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

var snickers = Candy(productId: 1, name: "Snickers", rating: .four)
snickers.isStored

snickers.stick()
snickers.isStored


