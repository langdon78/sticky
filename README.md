# Sticky

[![Platforms](https://img.shields.io/cocoapods/p/AFNetworking.svg)](https://cocoapods.org/pods/)

Use Sticky to quickly persist common Swift objects using the Swift 4 `Codable` type and local file storage.

# How it works

## Setup
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

Once you conform your object to `Stickable`, all you need to do is instantiate it and call the `stick()` method to persist it.

## Writing
```swift
var candyBar = Candy(productId: 1, name: "Snickers", rating: .four)
candyBar.stick()
```

## Reading
Want to get your data back out?

```swift
Candy.read()
//  [{productId: 1, name: "Snickers", rating: 4}]
```

If you're following along at home, you also need to define the `Rating` type used above and make sure it's also Codable.

```swift
enum Rating: Int {
    case one = 1
    case two
    case three
    case four
}

extension Rating: Codable {}
```

So what if you want to add a new candy bar?

```swift
candyBar.name = "Milky Way"
candyBar.stick()

Candy.read()
// [
//  {productId: 1, name: "Snickers", rating: 4},
//  {productId: 1, name: "Milky Way", rating: 4}
// ]
```

Wait, I didn't want to create a new candy bar, just wanted to update the name...

No problem, just create a `StickyKey`:

## Updating
```swift
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
// [
//  {productId: 1, name: "Almond Joy", rating: 4},
//  {productId: 1, name: "Milky Way", rating: 4}
// ]
```
## Deleting
Probably want to get rid of that duplicate productId now...

A couple ways to do that. First, you can simply create or use the `Milky Way` object to unstick.

```swift
let milkyWay = Candy(productId: 1, name: "Milky Way", rating: .four)
milkyWay.unstick()

Candy.read()
// [{productId: 1, name: "Almond Joy", rating: 4}]
```

### Configuration
```swift
let stickyConfig = StickyConfiguration(
    preloadCache: false, 
    clearDirectory: true, 
    async: false, 
    logging: true)
    
Sticky.configure(with: .custom(stickyConfig))
```