import Cocoa

enum CatLevel {
    case dock
    case ground
}

enum JumpPhase {
    case none
    case squish
    case airborne
    case land
}

enum StarPhase {
    case falling
    case bounce
    case resting
}

struct StarState {
    var view: StarView
    var phase: StarPhase = .falling
    var x: CGFloat = 0
    var y: CGFloat = 0
    var previousX: CGFloat = 0
    var previousY: CGFloat = 0
    var catHitCooldown: CGFloat = 0
    var velocityX: CGFloat = 0
    var velocityY: CGFloat = 0
    var rotation: CGFloat = 0
    var rotationSpeed: CGFloat = 0
    var floorY: CGFloat = 0
    var bounceCount = 0
    var settleRotation: CGFloat = 0
    var settleWobbleTime: CGFloat = 0
}
