import Cocoa
import Carbon.HIToolbox

final class AppController: NSObject, NSApplicationDelegate {
    let debugEnabled: Bool
    var window: NSWindow!
    var aboutWindowController: AboutWindowController?
    var accessibilityPrePromptShownThisLaunch = false
    var accessibilityPromptRequestedThisLaunch = false
    var accessibilityPollTimer: Timer?
    var releaseCheckTimer: Timer?
    var crabView: CrabView!
    var shadowView: ShadowView!
    var crabX: CGFloat = 0
    var crabY: CGFloat = 0
    var walkSpeed: CGFloat = 120
    var lastTime: TimeInterval = 0
    var walkTimer: CGFloat = 0
    var breatheTimer: CGFloat = 0
    var settleTimer: CGFloat = 0
    var rawLookDir: CGFloat = 0
    var lookDirVelocity: CGFloat = 0
    var eyeLookStep: CGFloat = 0
    let settleDuration: CGFloat = 0.35
    let drowsyDelay: TimeInterval = 3.0
    let sleepDelay: TimeInterval = 5.0
    var lastActivityTime: TimeInterval = 0
    var blinkTimer: CGFloat = 0
    var wakingUp = false
    var isAsleep = false

    var dockLeft: CGFloat = 0
    var dockRight: CGFloat = 0
    var dockFloorY: CGFloat = 0
    var groundFloorY: CGFloat = 0
    var screenLeft: CGFloat = 0
    var screenRight: CGFloat = 0

    var level: CrabLevel = .dock
    var jumpPhase: JumpPhase = .none
    var jumpTimer: CGFloat = 0
    var jumpStartY: CGFloat = 0
    var jumpEndY: CGFloat = 0
    var jumpDirection: CGFloat = 0
    var currentJumpHorizontalDistance: CGFloat = 0
    var landingTravelDirection: CGFloat = 0

    let squishDur: CGFloat = 0.09
    let airDur: CGFloat = 0.35
    let landDur: CGFloat = 0.11
    let jumpArcHeight: CGFloat = 40
    let jumpHorizontalDistance: CGFloat = 108

    var autoTargetX: CGFloat? = nil
    let autoThresh: CGFloat = 15
    let settleDelay: TimeInterval = 0.52
    var lastMouseMoveTime: TimeInterval = 0
    var mouseSettled = false
    var pendingTargetX: CGFloat? = nil
    var isSeekingApples = false
    var appleSeekStartTime: TimeInterval = 0
    var appleSeekDelay: TimeInterval = 0
    var appleSeekTargetID: ObjectIdentifier? = nil
    var appleSeekHopTriggers: [CGFloat] = []

    var spriteW: CGFloat = 30 * SCALE
    var spriteH: CGFloat = 16 * SCALE
    var lastDockCheck: TimeInterval = 0
    let dockCheckInterval: TimeInterval = 2.0
    var dockVisible = true

    var statusItem: NSStatusItem!
    var accessibilityMenuItem: NSMenuItem?
    var feedMenuItem: NSMenuItem?
    var checkForUpdatesMenuItem: NSMenuItem?
    var aboutMenuItem: NSMenuItem?
    var globalMouseMonitor: Any?
    var localMouseMonitor: Any?
    var accessibilityFeaturesActive = false
    var updateTimer: Timer?
    var feedHotKeyRef: EventHotKeyRef?
    var hotKeyHandlerRef: EventHandlerRef?
    var lastDebugSnapshot = ""
    var lastDebugSnapshotTime: TimeInterval = 0
    var appUpdater = AppUpdater()
    var appUpdateState: AppUpdateState = .idle
    var updateCheckTask: Task<Void, Never>?

    var apples: [AppleState] = []
    let appleGravity: CGFloat = -600
    let appleSize: CGFloat = CGFloat(appleGrid.count) * APPLE_SCALE + APPLE_PADDING * 2
    let appleContactSeparation: CGFloat = 0.70
    let appleContactRowTolerance: CGFloat = 0.5

    init(debugEnabled: Bool = false) {
        self.debugEnabled = debugEnabled
        super.init()
    }
}
