import Cocoa
import Carbon.HIToolbox

extension AppController {
    @objc func feedStar() {
        guard window != nil else { return }
        let allFrame = NSScreen.screens.reduce(CGRect.null) { $0.union($1.frame) }

        let starView = StarView(frame: NSRect(x: 0, y: 0, width: starSize, height: starSize))
        starView.wantsLayer = true
        starView.layer?.backgroundColor = NSColor.clear.cgColor
        window.contentView?.addSubview(starView)

        let x = starSpawnX(in: allFrame)
        let onDock = x >= dockLeft && x <= dockRight

        var star = StarState(view: starView)
        star.x = x
        // Drop from top of whichever screen the star spawns on
        let spawnScreenTop = NSScreen.screens.first { s in
            x >= s.frame.origin.x && x <= s.frame.origin.x + s.frame.width
        }?.frame.maxY ?? allFrame.maxY
        star.y = spawnScreenTop
        let fallDirection: CGFloat = Bool.random() ? 1 : -1
        star.velocityX = fallDirection * CGFloat.random(in: 120...180)
        star.rotation = CGFloat.random(in: -0.12...0.12)
        star.rotationSpeed = CGFloat.random(in: 3...7) * (Bool.random() ? 1 : -1)
        star.floorY = (onDock ? dockFloorY : groundFloorYForX(x)) - STAR_PADDING
        stars.append(star)
    }

    func starSpawnX(in screenFrame: CGRect) -> CGFloat {
        let minX = screenFrame.origin.x + 100
        let maxX = screenFrame.origin.x + screenFrame.width - 100
        guard minX < maxX else { return screenFrame.midX }

        let catAvoidance = max(starSize * 1.4, catHitRect().width * 0.9)
        let safeMin = max(minX, catX - catAvoidance)
        let safeMax = min(maxX, catX + catAvoidance)

        if safeMin >= safeMax {
            return CGFloat.random(in: minX...maxX)
        }

        for _ in 0..<8 {
            let candidate = CGFloat.random(in: minX...maxX)
            if candidate < safeMin || candidate > safeMax {
                return candidate
            }
        }

        let leftRangeWidth = max(0, safeMin - minX)
        let rightRangeWidth = max(0, maxX - safeMax)
        if leftRangeWidth == 0 && rightRangeWidth == 0 {
            return safeMin < screenFrame.midX ? maxX : minX
        }
        if rightRangeWidth > leftRangeWidth {
            return CGFloat.random(in: safeMax...maxX)
        }
        return CGFloat.random(in: minX...safeMin)
    }

    @objc func exitApp() {
        accessibilityPollTimer?.invalidate()
        accessibilityPollTimer = nil
        releaseCheckTimer?.invalidate()
        releaseCheckTimer = nil
        updateCheckTask?.cancel()
        updateCheckTask = nil
        updateTimer?.invalidate()
        if let feedHotKeyRef {
            UnregisterEventHotKey(feedHotKeyRef)
            self.feedHotKeyRef = nil
        }
        NSApp.terminate(nil)
    }

    func registerFeedHotKey() {
        let eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            guard status == noErr, hotKeyID.id == 1 else { return noErr }
            DispatchQueue.main.async {
                (NSApp.delegate as? AppController)?.feedStar()
            }
            return noErr
        }, 1, [eventSpec], nil, &hotKeyHandlerRef)

        let hotKeyID = EventHotKeyID(signature: 0x46454544, id: 1)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_F),
            UInt32(optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &feedHotKeyRef
        )
    }

    func updateStars(_ dt: CGFloat) {
        var toRemove: [Int] = []
        let xBounds = starHorizontalBounds()
        let topYLimit = starTopYLimit()
        let catCollisionRect = catHitRect().insetBy(dx: 8, dy: 2)
        let catHeadRect = catHeadHitRect(from: catCollisionRect)
        let catBodyRect = catBodyHitRect(from: catCollisionRect)

        for i in 0..<stars.count {
            stars[i].catHitCooldown = max(0, stars[i].catHitCooldown - dt)
            switch stars[i].phase {
            case .falling, .bounce:
                let previousX = stars[i].x
                let previousY = stars[i].y
                stars[i].previousX = previousX
                stars[i].previousY = previousY
                stars[i].x += stars[i].velocityX * dt
                stars[i].velocityY += starGravity * dt
                stars[i].y += stars[i].velocityY * dt
                stars[i].rotation += stars[i].rotationSpeed * dt

                if stars[i].x < xBounds.lowerBound {
                    stars[i].x = xBounds.lowerBound
                    stars[i].velocityX = abs(stars[i].velocityX) * 0.78
                    stars[i].rotationSpeed *= -0.7
                } else if stars[i].x > xBounds.upperBound {
                    stars[i].x = xBounds.upperBound
                    stars[i].velocityX = -abs(stars[i].velocityX) * 0.78
                    stars[i].rotationSpeed *= -0.7
                }

                if stars[i].y > topYLimit {
                    stars[i].y = topYLimit
                    stars[i].velocityY = -abs(stars[i].velocityY) * 0.72
                    stars[i].rotationSpeed *= -0.75
                }

                stars[i].floorY = starFloorY(
                    forX: stars[i].x,
                    currentY: stars[i].y,
                    previousX: previousX,
                    previousY: previousY
                )
                constrainStarAgainstDock(i, previousX: previousX)

                if stars[i].y <= stars[i].floorY {
                    stars[i].y = stars[i].floorY
                    stars[i].bounceCount += 1
                    if stars[i].bounceCount == 1 && !isSeekingStars {
                        beginStarSeek(now: CACurrentMediaTime())
                    }
                    if stars[i].bounceCount < 3 {
                        stars[i].velocityY = abs(stars[i].velocityY) * 0.35
                        stars[i].velocityX *= 0.72
                        stars[i].rotationSpeed *= 0.5
                        stars[i].phase = .bounce
                    } else {
                        stars[i].velocityX *= 0.42
                        stars[i].velocityY = 0
                        stars[i].rotationSpeed *= 0.35
                        stars[i].settleWobbleTime = 0
                        stars[i].phase = .resting
                    }
                }

            case .resting:
                let previousX = stars[i].x
                let previousY = stars[i].y
                stars[i].previousX = previousX
                stars[i].previousY = previousY
                stars[i].x += stars[i].velocityX * dt
                stars[i].floorY = starFloorY(forX: stars[i].x, currentY: stars[i].floorY)
                stars[i].y = stars[i].floorY
                stars[i].rotation += stars[i].rotationSpeed * dt
                constrainStarAgainstDock(i, previousX: previousX)

                if stars[i].x < xBounds.lowerBound {
                    stars[i].x = xBounds.lowerBound
                    stars[i].velocityX = 0
                } else if stars[i].x > xBounds.upperBound {
                    stars[i].x = xBounds.upperBound
                    stars[i].velocityX = 0
                }

                let slideDrag = max(0, 1 - 4.8 * dt)
                let spinDrag = max(0, 1 - 6.5 * dt)
                stars[i].velocityX *= slideDrag
                stars[i].rotationSpeed *= spinDrag

                if abs(stars[i].velocityX) < 6 {
                    stars[i].velocityX = 0
                }
                if abs(stars[i].rotationSpeed) < 0.2 {
                    stars[i].rotationSpeed = 0
                }
                if stars[i].velocityX == 0 && stars[i].rotationSpeed == 0 {
                    if stars[i].settleWobbleTime == 0 {
                        stars[i].settleRotation = stars[i].rotation
                    }
                    let wobbleDuration: CGFloat = 0.22
                    stars[i].settleWobbleTime = min(wobbleDuration, stars[i].settleWobbleTime + dt)
                    let wobbleT = stars[i].settleWobbleTime / wobbleDuration
                    let wobbleAmplitude: CGFloat = 0.045
                    let wobble = sin(wobbleT * CGFloat.pi) * (1 - wobbleT) * wobbleAmplitude
                    stars[i].rotation = stars[i].settleRotation + wobble
                    if stars[i].settleWobbleTime >= wobbleDuration {
                        stars[i].rotation = stars[i].settleRotation
                    }
                } else {
                    stars[i].settleWobbleTime = 0
                }
            }
        }

        resolveStarContacts()

        for i in 0..<stars.count {
            guard level == levelForStar(stars[i]) else {
                stars[i].view.rotation = stars[i].rotation
                stars[i].view.frame.origin.x = stars[i].x - starSize / 2 - (window?.frame.origin.x ?? 0)
                stars[i].view.frame.origin.y = stars[i].y - (window?.frame.origin.y ?? 0)
                stars[i].view.needsDisplay = true
                continue
            }

            let winOX = window?.frame.origin.x ?? 0
            let winOY = window?.frame.origin.y ?? 0
            let starRect = CGRect(
                x: stars[i].x - starSize / 2 - winOX,
                y: stars[i].y - winOY,
                width: starSize,
                height: starSize
            )
            if starHitsCatHead(star: stars[i], starRect: starRect, catHeadRect: catHeadRect) {
                if stars[i].catHitCooldown > 0 {
                    stars[i].view.rotation = stars[i].rotation
                    stars[i].view.frame.origin.x = stars[i].x - starSize / 2
                    stars[i].view.frame.origin.y = stars[i].y
                    stars[i].view.needsDisplay = true
                    continue
                }
                reactToTopStarHit(from: stars[i])
                deflectStarAfterCatHit(at: i, catRect: catCollisionRect)
                stars[i].view.rotation = stars[i].rotation
                stars[i].view.frame.origin.x = stars[i].x - starSize / 2 - (window?.frame.origin.x ?? 0)
                stars[i].view.frame.origin.y = stars[i].y - (window?.frame.origin.y ?? 0)
                stars[i].view.needsDisplay = true
                continue
            }

            if catBodyRect.intersects(starRect) {
                toRemove.append(i)
                continue
            }

            stars[i].view.rotation = stars[i].rotation
            stars[i].view.frame.origin.x = stars[i].x - starSize / 2
            stars[i].view.frame.origin.y = stars[i].y
            stars[i].view.needsDisplay = true
        }

        for i in toRemove.reversed() {
            stars[i].view.removeFromSuperview()
            stars.remove(at: i)
        }

        if isSeekingStars && stars.isEmpty {
            endStarSeek(now: CACurrentMediaTime())
        }
    }

    func starHitsCatHead(star: StarState, starRect: CGRect, catHeadRect: CGRect) -> Bool {
        guard jumpPhase == .none else { return false }
        guard star.catHitCooldown <= 0 else { return false }
        guard star.velocityY < -20 else { return false }
        guard star.phase != .resting else { return false }

        let starRadius = starCollisionRadius()
        let previousStarCenterY = star.previousY + starSize / 2
        let currentStarCenterY = starRect.midY
        let previousStarBottom = previousStarCenterY - starRadius
        let currentStarBottom = currentStarCenterY - starRadius
        let topContactTolerance = max(CGFloat(16), starSize * 0.55)

        let horizontalOverlap = min(star.x + starRadius, catHeadRect.maxX) - max(star.x - starRadius, catHeadRect.minX)
        guard horizontalOverlap >= min(starRadius * 2, catHeadRect.width) * 0.12 else {
            return false
        }

        return previousStarBottom >= catHeadRect.minY - topContactTolerance
            && currentStarBottom <= catHeadRect.maxY + topContactTolerance
    }

    func catHeadHitRect(from catRect: CGRect) -> CGRect {
        let headHeight = max(CGFloat(18), catRect.height * 0.42)
        let headInset = max(CGFloat(2), catRect.width * 0.06)
        return CGRect(
            x: catRect.minX + headInset,
            y: catRect.maxY - headHeight,
            width: catRect.width - headInset * 2,
            height: headHeight
        )
    }

    func catBodyHitRect(from catRect: CGRect) -> CGRect {
        let headHeight = max(CGFloat(18), catRect.height * 0.42)
        return CGRect(
            x: catRect.minX,
            y: catRect.minY,
            width: catRect.width,
            height: max(CGFloat(1), catRect.height - headHeight * 0.68)
        )
    }

    func starCollisionRadius() -> CGFloat {
        let visibleStarSize = CGFloat(starGrid.count) * STAR_SCALE
        return visibleStarSize * 0.42
    }

    func reactToTopStarHit(from star: StarState) {
        let direction: CGFloat
        if abs(star.x - catX) < 3 {
            if level == .dock {
                direction = catX < (dockLeft + dockRight) * 0.5 ? -1 : 1
            } else {
                direction = catView.facingRight ? -1 : 1
            }
        } else {
            direction = star.x < catX ? 1 : -1
        }

        lastActivityTime = CACurrentMediaTime()
        isAsleep = false
        wakingUp = false

        if level == .dock {
            startJump(down: true, direction: direction)
        } else {
            startHop(direction: direction)
        }
        currentJumpHorizontalDistance = jumpHorizontalDistance * 2
    }

    func deflectStarAfterCatHit(at index: Int, catRect: CGRect) {
        stars[index].y = max(stars[index].y, catRect.maxY - starSize + 2)
        stars[index].velocityY = max(abs(stars[index].velocityY) * 0.55, 180)
        let horizontalDirection: CGFloat = stars[index].x < catX ? -1 : 1
        stars[index].velocityX = horizontalDirection * max(abs(stars[index].velocityX) * 0.4, 90)
        stars[index].rotationSpeed += horizontalDirection * 4
        stars[index].phase = .bounce
        stars[index].bounceCount = min(stars[index].bounceCount, 1)
        stars[index].settleWobbleTime = 0
        stars[index].catHitCooldown = 0.35
    }

    func resolveStarContacts() {
        guard stars.count > 1 else { return }

        let contactDistance = starSize * starContactSeparation
        let rowTolerance = starSize * starContactRowTolerance
        let cellSize = max(contactDistance, 1)
        var dockBuckets: [Int: [Int]] = [:]
        var groundBuckets: [Int: [Int]] = [:]

        for index in stars.indices {
            let bucket = Int(floor(stars[index].x / cellSize))
            switch levelForStar(stars[index]) {
            case .dock:
                dockBuckets[bucket, default: []].append(index)
            case .ground:
                groundBuckets[bucket, default: []].append(index)
            }
        }

        resolveStarContacts(in: dockBuckets, contactDistance: contactDistance, rowTolerance: rowTolerance)
        resolveStarContacts(in: groundBuckets, contactDistance: contactDistance, rowTolerance: rowTolerance)
    }

    func resolveStarContacts(
        in buckets: [Int: [Int]],
        contactDistance: CGFloat,
        rowTolerance: CGFloat
    ) {
        guard !buckets.isEmpty else { return }

        for bucket in buckets.keys.sorted() {
            guard let current = buckets[bucket] else { continue }
            resolveStarContactsWithinBucket(
                current,
                contactDistance: contactDistance,
                rowTolerance: rowTolerance
            )

            guard let neighbor = buckets[bucket + 1] else { continue }
            resolveStarContactsBetweenBuckets(
                current,
                neighbor,
                contactDistance: contactDistance,
                rowTolerance: rowTolerance
            )
        }
    }

    func resolveStarContactsWithinBucket(
        _ indices: [Int],
        contactDistance: CGFloat,
        rowTolerance: CGFloat
    ) {
        guard indices.count > 1 else { return }

        for offset in 0..<(indices.count - 1) {
            let i = indices[offset]
            for nextOffset in (offset + 1)..<indices.count {
                let j = indices[nextOffset]
                resolveStarContactPair(
                    i,
                    j,
                    contactDistance: contactDistance,
                    rowTolerance: rowTolerance
                )
            }
        }
    }

    func resolveStarContactsBetweenBuckets(
        _ lhs: [Int],
        _ rhs: [Int],
        contactDistance: CGFloat,
        rowTolerance: CGFloat
    ) {
        for i in lhs {
            for j in rhs {
                resolveStarContactPair(
                    i,
                    j,
                    contactDistance: contactDistance,
                    rowTolerance: rowTolerance
                )
            }
        }
    }

    func resolveStarContactPair(
        _ i: Int,
        _ j: Int,
        contactDistance: CGFloat,
        rowTolerance: CGFloat
    ) {
        let minDistance: CGFloat = 0.001
        let separationBias: CGFloat = 0.82
        let restitution: CGFloat = 0.58

        let dx = stars[j].x - stars[i].x
        guard abs(dx) < contactDistance else { return }

        let dy = stars[j].y - stars[i].y
        guard abs(dy) < rowTolerance else { return }

        let distance = sqrt(dx * dx + dy * dy)
        guard distance < contactDistance else { return }

        let overlap = contactDistance - distance
        let normalX = distance > minDistance ? dx / distance : (stars[i].x <= stars[j].x ? 1 : -1)
        let normalY = distance > minDistance ? dy / distance : 0
        let push = overlap * 0.5 * separationBias

        stars[i].x -= normalX * push
        stars[j].x += normalX * push

        if stars[i].phase != .resting {
            stars[i].y -= normalY * push * 0.3
        }
        if stars[j].phase != .resting {
            stars[j].y += normalY * push * 0.3
        }

        let relativeVelocityX = stars[j].velocityX - stars[i].velocityX
        let relativeVelocityY = stars[j].velocityY - stars[i].velocityY
        let closingSpeed = relativeVelocityX * normalX + relativeVelocityY * normalY
        guard closingSpeed < -4 else { return }

        let impulse = -(1 + restitution) * closingSpeed * 0.5
        stars[i].velocityX -= impulse * normalX
        stars[j].velocityX += impulse * normalX
        stars[i].velocityY -= impulse * normalY * 0.45
        stars[j].velocityY += impulse * normalY * 0.45

        let tangentX = -normalY
        let tangentY = normalX
        let tangentSpeed = relativeVelocityX * tangentX + relativeVelocityY * tangentY
        let spinImpulse = tangentSpeed * 0.02 + impulse * normalX * 0.012
        stars[i].rotationSpeed -= spinImpulse
        stars[j].rotationSpeed += spinImpulse

        let groundedI = stars[i].y <= stars[i].floorY + 0.5
        let groundedJ = stars[j].y <= stars[j].floorY + 0.5
        if groundedI && stars[i].phase != .resting {
            stars[i].velocityY = max(stars[i].velocityY, CGFloat.random(in: 22...36))
        }
        if groundedJ && stars[j].phase != .resting {
            stars[j].velocityY = max(stars[j].velocityY, CGFloat.random(in: 22...36))
        }

        if stars[i].phase == .resting && abs(stars[i].velocityX) > 10 {
            stars[i].settleWobbleTime = 0
        }
        if stars[j].phase == .resting && abs(stars[j].velocityX) > 10 {
            stars[j].settleWobbleTime = 0
        }

        stars[i].rotationSpeed = max(-18, min(18, stars[i].rotationSpeed))
        stars[j].rotationSpeed = max(-18, min(18, stars[j].rotationSpeed))
    }

    func catHitRect() -> CGRect {
        let s = SCALE
        let ox: CGFloat = 10 * s  // body drawn at this offset within sprite
        let oy: CGFloat = 4 * s
        let legRows = CGFloat(catView.currentLegs.count)
        let bottom = oy - legRows * s
        let top = oy + CGFloat(bodyGrid.count) * s + catView.bodyBob + catView.legYBob
        return CGRect(
            x: catView.frame.origin.x + ox,
            y: catView.frame.origin.y + bottom,
            width: 16 * s,
            height: max(s, top - bottom)
        )
    }

    func catHitRectInScreen() -> CGRect? {
        guard let window else { return nil }
        return window.convertToScreen(catHitRect()).insetBy(dx: -2, dy: -2)
    }

    func starRectInScreen(_ star: StarState) -> CGRect? {
        guard let window else { return nil }
        let windowRect = star.view.convert(star.view.bounds, to: nil)
        return window.convertToScreen(windowRect).insetBy(dx: -2, dy: -2)
    }

    func throwStar(at index: Int, from screenPoint: CGPoint) {
        let starCenterX = stars[index].x
        let direction: CGFloat
        if abs(screenPoint.x - starCenterX) < 4 {
            direction = Bool.random() ? 1 : -1
        } else {
            direction = screenPoint.x < starCenterX ? 1 : -1
        }

        stars[index].phase = .falling
        stars[index].bounceCount = 0
        stars[index].velocityX = direction * CGFloat.random(in: 720...980)
        stars[index].velocityY = CGFloat.random(in: 1250...1550)
        stars[index].rotationSpeed = CGFloat.random(in: 12...18) * (direction > 0 ? 1 : -1)
        stars[index].floorY = starFloorY(forX: stars[index].x, currentY: stars[index].y)
    }

    func handleStarClick(at screenPoint: CGPoint) -> Bool {
        for i in stars.indices.reversed() {
            guard let starRect = starRectInScreen(stars[i]) else { continue }
            guard starRect.contains(screenPoint) else { continue }
            throwStar(at: i, from: screenPoint)
            return true
        }
        return false
    }

    func handleCatClick(at screenPoint: CGPoint) -> Bool {
        guard let hitRect = catHitRectInScreen(), hitRect.contains(screenPoint) else { return false }
        guard isFullyAwake() else { return false }

        lastActivityTime = CACurrentMediaTime()
        startInPlaceJump()
        return true
    }

    func handleMouseClick(at screenPoint: CGPoint) {
        if handleStarClick(at: screenPoint) {
            return
        }
        if handleCatClick(at: screenPoint) {
            return
        }
        handleWakeClick(at: screenPoint)
    }

    func handleWakeClick(at screenPoint: CGPoint) {
        guard isAsleep else { return }
        guard let hitRect = catHitRectInScreen(), hitRect.contains(screenPoint) else { return }
        let now = CACurrentMediaTime()

        isAsleep = false
        wakingUp = true
        lastActivityTime = now
        lastMouseMoveTime = now
        mouseSettled = false
    }
}
