import Cocoa

extension AppController {
    func debugLog(_ message: String) {
        guard debugEnabled else { return }
        print("[Nacrelum] \(message)")
        fflush(stdout)
    }

    func debugSnapshot(now: TimeInterval) {
        guard debugEnabled else { return }
        guard now - lastDebugSnapshotTime >= 0.25 else { return }

        let autoTarget = autoTargetX.map { String(format: "%.1f", $0) } ?? "nil"
        let nearestStar = nearestStarIndex().map { index in
            let star = stars[index]
            return String(format: "idx=%d x=%.1f y=%.1f phase=%@", index, star.x, star.y, String(describing: star.phase))
        } ?? "none"
        let snapshot = String(
            format: "state level=%@ jump=%@ seek=%@ asleep=%@ waking=%@ x=%.1f y=%.1f auto=%@ stars=%d nearest=%@",
            String(describing: level),
            String(describing: jumpPhase),
            isSeekingStars.description,
            isAsleep.description,
            wakingUp.description,
            catX,
            catY,
            autoTarget,
            stars.count,
            nearestStar
        )

        guard snapshot != lastDebugSnapshot else { return }
        lastDebugSnapshot = snapshot
        lastDebugSnapshotTime = now
        debugLog(snapshot)
    }

    func isDockObscured(screen: NSScreen) -> Bool {
        let screenFrame = screen.frame

        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return false }
        if frontApp.bundleIdentifier == "com.star.dock" ||
            frontApp.bundleIdentifier == "com.star.finder" {
            return false
        }

        let pid = frontApp.processIdentifier
        let options = CGWindowListOption([.optionOnScreenOnly, .excludeDesktopElements])
        guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }

        let pidKey = kCGWindowOwnerPID as String
        let boundsKey = "kCGWindowBounds"
        let layerKey = kCGWindowLayer as String

        for window in windows {
            guard let windowPid = window[pidKey] as? Int32, windowPid == pid,
                  let layer = window[layerKey] as? Int, layer == 0,
                  let bounds = window[boundsKey] as? [String: CGFloat],
                  let width = bounds["Width"], let height = bounds["Height"] else {
                continue
            }

            if width >= screenFrame.width - 1 && height >= screenFrame.height - 1 {
                return true
            }
        }

        return false
    }

    func refreshDockBounds() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame

        let wasVisible = dockVisible
        dockVisible = !isDockObscured(screen: screen)
        window?.alphaValue = dockVisible ? 1 : 0

        if dockVisible && !wasVisible {
            if level == .dock {
                catY = dockFloorY
            } else {
                catY = groundFloorY
            }
        }

        let dock = DockInfo.get(screen: screen)
        let halfBody: CGFloat = 6 * SCALE
        let catFeetInSprite: CGFloat = 4 * SCALE

        dockLeft = dock.x + halfBody
        dockRight = dock.x + dock.width - halfBody
        screenLeft = screenFrame.origin.x + halfBody + 10
        screenRight = screenFrame.origin.x + screenFrame.width - halfBody - 10
        groundFloorY = -5
        dockFloorY = dock.height - catFeetInSprite + 21

        let windowHeight = screenFrame.height
        window?.setFrame(
            NSRect(
                x: screenFrame.origin.x,
                y: screenFrame.origin.y,
                width: screenFrame.width,
                height: windowHeight
            ),
            display: false
        )

        if let contentView = window?.contentView {
            contentView.frame.size = NSSize(width: screenFrame.width, height: windowHeight)
        }

        if level == .dock {
            catY = dockFloorY
        } else {
            catY = groundFloorY
        }
    }

    func currentMinX() -> CGFloat {
        level == .dock ? dockLeft : screenLeft
    }

    func currentMaxX() -> CGFloat {
        level == .dock ? dockRight : screenRight
    }

    func nearestStarIndex(chaseableOnly: Bool = false) -> Int? {
        let candidates = stars.indices.filter { !chaseableOnly || stars[$0].phase != .falling }
        return candidates.min { lhs, rhs in
            let leftDist = starSeekDistance(to: stars[lhs])
            let rightDist = starSeekDistance(to: stars[rhs])
            if leftDist == rightDist {
                return stars[lhs].x < stars[rhs].x
            }
            return leftDist < rightDist
        }
    }

    func nearestStarX(chaseableOnly: Bool = false) -> CGFloat? {
        guard let index = nearestStarIndex(chaseableOnly: chaseableOnly) else { return nil }
        return stars[index].x
    }

    func currentStarSeekIndex() -> Int? {
        if let targetID = starSeekTargetID,
           let lockedIndex = stars.firstIndex(where: { ObjectIdentifier($0.view) == targetID }) {
            let lockedStar = stars[lockedIndex]
            if lockedStar.phase != .falling || nearestStarIndex(chaseableOnly: true) == nil {
                return lockedIndex
            }
        }

        let preferredIndex = nearestStarIndex(chaseableOnly: true) ?? nearestStarIndex()
        guard let index = preferredIndex else {
            starSeekTargetID = nil
            starSeekHopTriggers.removeAll()
            return nil
        }

        let star = stars[index]
        let targetID = ObjectIdentifier(star.view)
        if starSeekTargetID != targetID {
            starSeekTargetID = targetID

            let hopCount = Int.random(in: 0...3)
            let distance = abs(star.x - catX)
            if hopCount == 0 || distance < 70 {
                starSeekHopTriggers.removeAll()
            } else {
                let minTrigger: CGFloat = 35
                let maxTrigger = max(minTrigger + 5, distance - 20)
                starSeekHopTriggers = (0..<hopCount)
                    .map { _ in CGFloat.random(in: minTrigger...maxTrigger) }
                    .sorted(by: >)
            }
        }

        return index
    }

    func currentStarSeekTargetX() -> CGFloat? {
        guard let index = currentStarSeekIndex() else { return nil }
        let star = stars[index]
        return starSeekTargetX(for: star)
    }

    func starSeekDistance(to star: StarState) -> CGFloat {
        let starLevel = levelForStar(star)
        if starLevel == level {
            return abs(star.x - catX)
        }

        let leftPath = abs(catX - dockLeft) + abs(star.x - dockLeft)
        let rightPath = abs(catX - dockRight) + abs(star.x - dockRight)
        return min(leftPath, rightPath) + jumpHorizontalDistance * 0.35
    }

    func starSeekTargetX(for star: StarState) -> CGFloat {
        let starLevel = levelForStar(star)
        if starLevel == level {
            return star.x
        }

        let leftPath = abs(catX - dockLeft) + abs(star.x - dockLeft)
        let rightPath = abs(catX - dockRight) + abs(star.x - dockRight)
        if level == .dock && starLevel == .ground {
            return leftPath <= rightPath ? dockLeft - 2 : dockRight + 2
        }
        return leftPath <= rightPath ? dockLeft + 2 : dockRight - 2
    }

    func canLandHop(on level: CatLevel, direction: CGFloat) -> Bool {
        let landingX = catX + direction * jumpHorizontalDistance
        switch level {
        case .dock:
            return landingX >= dockLeft && landingX <= dockRight
        case .ground:
            return landingX >= screenLeft && landingX <= screenRight
        }
    }

    func isStarHopTooCloseToDockEdge(direction: CGFloat) -> Bool {
        guard level == .dock else { return false }

        let hopEdgeMargin = jumpHorizontalDistance * 0.45
        let landingX = catX + direction * jumpHorizontalDistance
        let minSafeX = dockLeft + hopEdgeMargin
        let maxSafeX = dockRight - hopEdgeMargin
        return catX < minSafeX || catX > maxSafeX || landingX < minSafeX || landingX > maxSafeX
    }

    func pathCrossesDockOnGround(from startX: CGFloat, to targetX: CGFloat) -> Bool {
        let pathMinX = min(startX, targetX)
        let pathMaxX = max(startX, targetX)
        return pathMaxX >= dockLeft && pathMinX <= dockRight
    }

    func dockEntryDirection(for targetX: CGFloat) -> CGFloat {
        // When approaching from the ground, always enter from the side the cat is
        // already on. Otherwise it can jump onto the dock from the opposite edge,
        // land near an exit, and immediately jump back down into a loop.
        if catX < dockLeft {
            return 1
        }
        if catX > dockRight {
            return -1
        }

        let leftApproachX = dockLeft - 2
        let rightApproachX = dockRight + 2
        let leftCost = abs(catX - leftApproachX) + abs(targetX - dockLeft)
        let rightCost = abs(catX - rightApproachX) + abs(targetX - dockRight)
        if abs(leftCost - rightCost) < 0.5 {
            return abs(catX - leftApproachX) <= abs(catX - rightApproachX) ? 1 : -1
        }
        return leftCost < rightCost ? 1 : -1
    }

    func dockEntryApproachX(for targetX: CGFloat) -> CGFloat {
        let entryDir = dockEntryDirection(for: targetX)
        return entryDir > 0 ? dockLeft - 2 : dockRight + 2
    }

    func currentStarSeekTargetLevel() -> CatLevel? {
        guard let index = nearestStarIndex(chaseableOnly: true) ?? nearestStarIndex() else { return nil }
        return levelForStar(stars[index])
    }

    func shouldStartStarHop(remainingDistance: CGFloat, direction: CGFloat) -> Bool {
        guard isSeekingStars, let nextTrigger = starSeekHopTriggers.first else { return false }
        guard remainingDistance > autoThresh * 2 else { return false }
        guard remainingDistance <= nextTrigger else { return false }
        guard canLandHop(on: level, direction: direction) else { return false }
        guard !isStarHopTooCloseToDockEdge(direction: direction) else { return false }

        starSeekHopTriggers.removeFirst()
        return true
    }

    func beginStarSeek(now: TimeInterval) {
        isSeekingStars = true
        starSeekStartTime = now
        starSeekDelay = TimeInterval.random(in: 1.0...2.0)
        starSeekTargetID = nil
        starSeekHopTriggers.removeAll()
        isAsleep = false
        wakingUp = catView.sitAmount > 0.05 || catView.eyeClose > 0.05
        autoTargetX = nil
        lastActivityTime = now
        lastMouseMoveTime = now
        mouseSettled = false
        pendingTargetX = NSEvent.mouseLocation.x
        debugLog(String(format: "beginStarSeek x=%.1f y=%.1f stars=%d", catX, catY, stars.count))
    }

    func resetWalkAnimation() {
        settleTimer = 0
        walkTimer = 0
        catView.legFrame = 0
        catView.currentLegs = pawsIdle
        catView.isWalking = false
        catView.walkFacing = 0
    }

    func endStarSeek(now: TimeInterval) {
        isSeekingStars = false
        starSeekTargetID = nil
        starSeekHopTriggers.removeAll()
        autoTargetX = nil
        resetWalkAnimation()
        lastActivityTime = now
        lastMouseMoveTime = now
        mouseSettled = false
        pendingTargetX = NSEvent.mouseLocation.x
        debugLog(String(format: "endStarSeek x=%.1f y=%.1f stars=%d", catX, catY, stars.count))
    }

    func lookTargetX(fallback mouseX: CGFloat) -> CGFloat {
        if let groundedStarX = groundedStarLookTargetX() {
            return groundedStarX
        }
        if isSeekingStars {
            if let targetID = starSeekTargetID,
               let trackedStar = stars.first(where: { ObjectIdentifier($0.view) == targetID }) {
                return trackedStar.x
            }
            if let index = currentStarSeekIndex() {
                return stars[index].x
            }
            return catX
        }
        return mouseX
    }

    func groundedStarLookTargetX() -> CGFloat? {
        let groundedThreshold: CGFloat = 0.5

        if let targetID = starSeekTargetID,
           let trackedStar = stars.first(where: { ObjectIdentifier($0.view) == targetID }),
           trackedStar.y <= trackedStar.floorY + groundedThreshold {
            return trackedStar.x
        }

        guard let groundedStar = stars
            .filter({ $0.y <= $0.floorY + groundedThreshold })
            .min(by: { abs($0.x - catX) < abs($1.x - catX) }) else {
            return nil
        }
        return groundedStar.x
    }

    func dockStarFloorY() -> CGFloat {
        dockFloorY - STAR_PADDING
    }

    func groundStarFloorY() -> CGFloat {
        groundFloorY - STAR_PADDING
    }

    func levelForStar(_ star: StarState) -> CatLevel {
        let dockFloor = dockStarFloorY()
        let groundFloor = groundStarFloorY()
        return abs(star.floorY - dockFloor) < abs(star.floorY - groundFloor) ? .dock : .ground
    }

    func starHorizontalBounds() -> ClosedRange<CGFloat> {
        let starHalf = starSize / 2
        let width = window.contentView?.bounds.width ?? (screenRight + starHalf)
        return starHalf...(width - starHalf)
    }

    func starTopYLimit() -> CGFloat {
        let height = window.contentView?.bounds.height ?? 0
        return max(0, height - starSize)
    }

    func starCrossedDockTop(fromX previousX: CGFloat, y previousY: CGFloat, toX x: CGFloat, y currentY: CGFloat) -> Bool {
        let dockFloor = dockStarFloorY()
        let crossedDockBand = max(previousX, x) >= dockLeft && min(previousX, x) <= dockRight
        let crossedDockTop = previousY >= dockFloor && currentY <= dockFloor
        return crossedDockBand && crossedDockTop
    }

    func starFloorY(forX x: CGFloat, currentY: CGFloat, previousX: CGFloat? = nil, previousY: CGFloat? = nil) -> CGFloat {
        let dockFloor = dockStarFloorY()
        let groundFloor = groundStarFloorY()

        if let previousX, let previousY,
           starCrossedDockTop(fromX: previousX, y: previousY, toX: x, y: currentY) {
            return dockFloor
        }

        let overDock = x >= dockLeft && x <= dockRight
        let aboveDockTop = currentY >= dockFloor
        return overDock && aboveDockTop ? dockFloor : groundFloor
    }

    func constrainStarAgainstDock(_ index: Int, previousX: CGFloat? = nil) {
        let dockFloor = dockStarFloorY()
        let groundFloor = groundStarFloorY()
        guard stars[index].floorY <= groundFloor + 0.5 else { return }
        guard stars[index].y < dockFloor - 0.5 else { return }

        let starHalf = starSize / 2
        let leftBarrier = dockLeft - starHalf
        let rightBarrier = dockRight + starHalf
        guard stars[index].x > leftBarrier && stars[index].x < rightBarrier else { return }

        let targetX: CGFloat
        if let previousX {
            if previousX <= leftBarrier {
                targetX = leftBarrier
            } else if previousX >= rightBarrier {
                targetX = rightBarrier
            } else {
                targetX = abs(stars[index].x - leftBarrier) < abs(stars[index].x - rightBarrier) ? leftBarrier : rightBarrier
            }
        } else {
            targetX = abs(stars[index].x - leftBarrier) < abs(stars[index].x - rightBarrier) ? leftBarrier : rightBarrier
        }

        stars[index].x = targetX
        stars[index].velocityX = (targetX == leftBarrier ? -1 : 1) * max(18, abs(stars[index].velocityX) * 0.45)
        stars[index].rotationSpeed += stars[index].velocityX * 0.01
        stars[index].settleWobbleTime = 0
    }

    func isFullyAwake() -> Bool {
        let now = CACurrentMediaTime()
        let idleTime = now - lastActivityTime
        return !isAsleep
            && !wakingUp
            && jumpPhase == .none
            && idleTime <= drowsyDelay
            && catView.sitAmount < 0.05
            && catView.eyeClose < 0.05
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
