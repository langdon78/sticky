# Sticky

[![Platforms](https://img.shields.io/cocoapods/p/AFNetworking.svg)](https://cocoapods.org/pods/)

Use Sticky to quickly persist common Swift objects using the Swift 4 `Codable` type and local file storage.

# How it works

Simply define an object in Swift (use your value types!) and conform it to the `Stickable` protocol. In order to take full advantage of **Sticky**, make sure to add `Equatable` conformance to your object as well. 
> Note: In Swift 4.1, conformance will be [synthesized for you](https://github.com/apple/swift-evolution/blob/master/proposals/0185-synthesize-equatable-hashable.md).

```swift
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
```

