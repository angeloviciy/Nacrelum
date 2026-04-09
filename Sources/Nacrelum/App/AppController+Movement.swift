import Cocoa

extension AppController {
    func updateDisplayedLookDirection(from rawLook: CGFloat) {
        let enterThreshold: CGFloat = 0.38
        let exitThreshold: CGFloat = 0.18

        switch eyeLookStep {
        case 1:
            if rawLook < exitThreshold {
                eyeLookStep = 0
            }
        case -1:
            if rawLook > -exitThreshold {
                eyeLookStep = 0
            }
        default:
            if rawLook > enterThreshold {
                eyeLookStep = 1
            } else if rawLook < -enterThreshold {
                eyeLookStep = -1
            } else {
                eyeLookStep = 0
            }
        }

        catView.lookDir = eyeLookStep
    }

    func updateLookDirection(dt: CGFloat, fallbackX: CGFloat, smoothing: CGFloat = 14) {
        let targetLook: CGFloat
        let dx = lookTargetX(fallback: fallbackX) - catX
        let maxDist: CGFloat = 300
        let closeRangeEyeDeadzone: CGFloat = 8
        let effectiveDX = abs(dx) <= closeRangeEyeDeadzone ? 0 : dx
        var directionalLook = max(-1, min(1, effectiveDX / maxDist))
        if !catView.facingRight {
            directionalLook *= -1
        }
        targetLook = directionalLook

        let blend = min(1, smoothing * dt)
        lookDirVelocity = (targetLook - rawLookDir) * blend
        rawLookDir += lookDirVelocity
        updateDisplayedLookDirection(from: rawLookDir)
    }

    func update() {
        let now = CACurrentMediaTime()
        let dt = CGFloat(now - lastTime)
        lastTime = now
        debugSnapshot(now: now)

        updateStars(dt)

        if now - lastDockCheck > dockCheckInterval {
            lastDockCheck = now
            refreshDockBounds()
        }

        // Cat keeps moving even when dock is obscured (just stays on ground)

        let mouseLocation = NSEvent.mouseLocation
        let mouseX = mouseLocation.x

        if jumpPhase != .none {
            catView.isWalking = false
            catView.walkFacing = landingTravelDirection != 0 ? landingTravelDirection : jumpDirection
            updateJump(dt)
            updateVisuals(dt, isWalking: false)
            positionSprite()
            return
        }

        let timeSinceMove = now - lastMouseMoveTime
        if !isSeekingStars, let pending = pendingTargetX, abs(mouseX - pending) > 2 {
            lastMouseMoveTime = now
            mouseSettled = false
            if !isAsleep {
                lastActivityTime = now
                if catView.sitAmount > 0.1 {
                    wakingUp = true
                }
            }
        }
        pendingTargetX = mouseX

        if wakingUp && catView.sitAmount < 0.05 {
            wakingUp = false
        }

        if isAsleep {
            updateVisuals(dt, isWalking: false)
            positionSprite()
            return
        }

        if wakingUp {
            updateVisuals(dt, isWalking: false)
            updateLookDirection(dt: dt, fallbackX: mouseX, smoothing: 10)
            positionSprite()
            return
        }

        let minX = currentMinX()
        let maxX = currentMaxX()

        if isSeekingStars {
            lastActivityTime = now
            if now - starSeekStartTime < starSeekDelay {
                autoTargetX = nil
            } else if let starX = currentStarSeekTargetX() {
                autoTargetX = max(screenLeft, min(screenRight, starX))
            } else if stars.isEmpty {
                endStarSeek(now: now)
            } else {
                autoTargetX = nil
            }
        } else {
            if !mouseSettled && timeSinceMove > settleDelay {
                mouseSettled = true
                let targetX = max(screenLeft, min(screenRight, mouseX))
                if abs(targetX - catX) > autoThresh * 2 {
                    autoTargetX = targetX
                }
            }

            if let target = autoTargetX, !mouseSettled {
                if abs(mouseX - target) > 80 {
                    autoTargetX = nil
                } else {
                    autoTargetX = max(screenLeft, min(screenRight, mouseX))
                }
            }
        }

        var isWalking = false
        var walkFacing: CGFloat = 0

        if let target = autoTargetX {
            var movementTarget = target
            let jumpOffMargin: CGFloat = 30
            let onDockArea = catX >= dockLeft && catX <= dockRight
            if level == .dock && onDockArea && (target < dockLeft || target > dockRight) {
                let exitDir: CGFloat = target < dockLeft ? -1 : 1
                let nearExitEdge = (exitDir < 0 && catX <= dockLeft + jumpOffMargin)
                    || (exitDir > 0 && catX >= dockRight - jumpOffMargin)
                if nearExitEdge {
                    debugLog(String(format: "jumpDown target=%.1f dir=%.0f x=%.1f dock=[%.1f,%.1f]", target, exitDir, catX, dockLeft, dockRight))
                    startJump(down: true, direction: exitDir)
                    updateVisuals(dt, isWalking: false)
                    positionSprite()
                    return
                }
            }

            let shouldTransitionUpToDock = level == .ground && (
                (target >= dockLeft && target <= dockRight)
                    || (isSeekingStars && pathCrossesDockOnGround(from: catX, to: target))
            )
            if shouldTransitionUpToDock {
                let entryDir = dockEntryDirection(for: target)
                let approachX = dockEntryApproachX(for: target)
                let jumpMargin: CGFloat = 50
                let underDock = catX >= dockLeft && catX <= dockRight
                let nearDockEntry = abs(catX - approachX) <= jumpMargin
                if nearDockEntry {
                    debugLog(String(format: "jumpUp target=%.1f entryDir=%.0f x=%.1f approachX=%.1f dock=[%.1f,%.1f]", target, entryDir, catX, approachX, dockLeft, dockRight))
                    startJump(down: false, direction: entryDir)
                    updateVisuals(dt, isWalking: false)
                    positionSprite()
                    return
                }
                if underDock {
                    debugLog(String(format: "underDock reroute target=%.1f approachX=%.1f entryDir=%.0f x=%.1f", target, approachX, entryDir, catX))
                    movementTarget = approachX
                    autoTargetX = approachX
                }
            }

            let dx = movementTarget - catX
            if abs(dx) > autoThresh {
                let dir: CGFloat = dx > 0 ? 1 : -1
                let activeWalkSpeed = isSeekingStars ? walkSpeed * 1.6 : walkSpeed
                let nextX = catX + dir * min(activeWalkSpeed * dt, abs(dx))

                if level == .dock && onDockArea
                    && (nextX < dockLeft + jumpOffMargin || nextX > dockRight - jumpOffMargin)
                    && (target < dockLeft || target > dockRight) {
                    debugLog(String(format: "jumpDown target=%.1f dir=%.0f nextX=%.1f dock=[%.1f,%.1f]", target, dir, nextX, dockLeft, dockRight))
                    startJump(down: true, direction: dir)
                    updateVisuals(dt, isWalking: false)
                    positionSprite()
                    return
                }

                if shouldStartStarHop(remainingDistance: abs(dx), direction: dir) {
                    debugLog(String(format: "starHop target=%.1f dir=%.0f x=%.1f", target, dir, catX))
                    startHop(direction: dir)
                    updateVisuals(dt, isWalking: false)
                    positionSprite()
                    return
                }

                catX = nextX
                catView.facingRight = dir > 0
                walkFacing = dir
                isWalking = true

                if catX >= minX && catX <= maxX {
                    catX = max(minX, min(maxX, catX))
                }

                if abs(catX - target) <= autoThresh {
                    catX = max(minX, min(maxX, movementTarget))
                    autoTargetX = nil
                }
            } else {
                catX = max(minX, min(maxX, movementTarget))
                autoTargetX = nil
            }
        }

        catView.isWalking = isWalking
        catView.walkFacing = walkFacing
        if isWalking {
            lastActivityTime = now
        }

        updateLookDirection(dt: dt, fallbackX: mouseX)

        updateVisuals(dt, isWalking: isWalking)
        positionSprite()
    }

    func startJump(down: Bool, direction: CGFloat) {
        debugLog(String(format: "startJump down=%@ dir=%.0f from=(%.1f,%.1f) toY=%.1f", down.description, direction, catX, catY, down ? groundFloorY : dockFloorY))
        jumpPhase = .squish
        jumpTimer = 0
        jumpStartY = catY
        jumpEndY = down ? groundFloorY : dockFloorY
        jumpDirection = direction
        currentJumpHorizontalDistance = jumpHorizontalDistance
        landingTravelDirection = direction
        autoTargetX = nil
        catView.facingRight = direction > 0
    }

    func startHop(direction: CGFloat) {
        debugLog(String(format: "startHop dir=%.0f from=(%.1f,%.1f)", direction, catX, catY))
        jumpPhase = .squish
        jumpTimer = 0
        jumpStartY = catY
        jumpEndY = catY
        jumpDirection = direction
        currentJumpHorizontalDistance = jumpHorizontalDistance
        landingTravelDirection = direction
        autoTargetX = nil
        catView.facingRight = direction > 0
    }

    func startInPlaceJump() {
        jumpPhase = .squish
        jumpTimer = 0
        jumpStartY = catY
        jumpEndY = catY
        jumpDirection = catView.facingRight ? 1 : -1
        currentJumpHorizontalDistance = 0
        landingTravelDirection = 0
    }

    func smoothstep(_ t: CGFloat) -> CGFloat {
        let clamped = max(0, min(1, t))
        return clamped * clamped * (3 - 2 * clamped)
    }

    func updateJump(_ dt: CGFloat) {
        jumpTimer += dt

        switch jumpPhase {
        case .squish:
            if jumpTimer >= squishDur {
                jumpPhase = .airborne
                jumpTimer = 0
            }
            let t = jumpTimer / squishDur
            catView.scaleX = 1 + 0.18 * t
            catView.scaleY = 1 - 0.18 * t
            catView.currentLegs = pawsSquish
            catView.armsRaised = false

        case .airborne:
            let t = min(1, jumpTimer / airDur)
            let linearY = jumpStartY + (jumpEndY - jumpStartY) * t
            let arc = 4 * jumpArcHeight * t * (1 - t)
            catY = linearY + arc

            catX += jumpDirection * (currentJumpHorizontalDistance / airDur) * dt
            catX = max(screenLeft, min(screenRight, catX))

            if t < 0.5 {
                catView.currentLegs = pawsRising
                catView.armsRaised = true
                catView.scaleX = 0.88
                catView.scaleY = 1.18
            } else {
                catView.currentLegs = pawsFalling
                catView.armsRaised = false
                catView.scaleX = 0.92
                catView.scaleY = 1.10
            }

            if t >= 1 {
                catY = jumpEndY
                jumpPhase = .land
                jumpTimer = 0
                level = jumpEndY == dockFloorY ? .dock : .ground
            }

        case .land:
            if jumpTimer >= landDur {
                jumpPhase = .none
                jumpTimer = 0
                catY = jumpEndY
                catView.scaleX = 1
                catView.scaleY = 1
                catView.currentLegs = pawsIdle
                catView.armsRaised = false
                landingTravelDirection = 0
                settleTimer = 0
                mouseSettled = false
                lastMouseMoveTime = CACurrentMediaTime()
                return
            }

            let landT = min(1, jumpTimer / landDur)
            let impactT = smoothstep(min(1, landT / 0.42))
            let recoveryT = smoothstep(max(0, (landT - 0.42) / 0.58))
            let movingLanding = landingTravelDirection != 0

            catY = jumpEndY
            catView.scaleX = 1 + 0.22 * impactT - 0.10 * recoveryT
            catView.scaleY = 1 - 0.24 * impactT + 0.10 * recoveryT
            if landT < 0.42 {
                catView.currentLegs = pawsLand
            } else if landT < 0.78 {
                catView.currentLegs = pawsLandRecover
            } else {
                catView.currentLegs = movingLanding ? pawsWalk : pawsIdle
            }
            catView.armsRaised = false

        case .none:
            break
        }

        let look: CGFloat
        if currentJumpHorizontalDistance == 0 {
            look = 0
        } else {
            var jumpLook: CGFloat = jumpDirection > 0 ? 1 : -1
            if !catView.facingRight {
                jumpLook *= -1
            }
            look = jumpLook
        }
        rawLookDir = look
        lookDirVelocity = 0
        eyeLookStep = look == 0 ? 0 : (look > 0 ? 1 : -1)
        catView.lookDir = eyeLookStep
    }

    func updateVisuals(_ dt: CGFloat, isWalking: Bool) {
        let targetLegYBob: CGFloat
        let settling = !isWalking && settleTimer > 0 && jumpPhase == .none

        if (isWalking || settling) && jumpPhase == .none {
            if isWalking {
                settleTimer = settleDuration
            } else {
                settleTimer -= dt
            }

            let cycleSpeed: CGFloat = settling ? 0.20 : 0.15
            walkTimer += dt
            if walkTimer > cycleSpeed {
                catView.legFrame = catView.legFrame == 0 ? 1 : 0
                walkTimer = 0
                if settling && catView.legFrame == 0 {
                    settleTimer = 0
                }
            }
            catView.currentLegs = catView.legFrame == 0 ? pawsIdle : pawsWalk
            catView.scaleX = 1
            catView.scaleY = 1
            catView.armsRaised = false
            targetLegYBob = catView.legFrame == 1 ? SCALE * 0.4 : 0
        } else if jumpPhase == .none {
            catView.legFrame = 0
            walkTimer = 0
            settleTimer = 0
            catView.scaleX = 1
            catView.scaleY = 1
            catView.armsRaised = false

            let now = CACurrentMediaTime()
            let idleTime = now - lastActivityTime
            let isDrowsy = idleTime > drowsyDelay && idleTime <= sleepDelay
            let isSleeping = idleTime > sleepDelay

            if isDrowsy {
                blinkTimer += dt
                let blinkCycle = blinkTimer.truncatingRemainder(dividingBy: 0.8)
                if blinkCycle < 0.12 {
                    catView.eyeClose = min(max(catView.eyeClose, 0.85), 1)
                } else {
                    catView.eyeClose = max(catView.eyeClose - dt * 8, 0)
                }
                catView.sitAmount = max(catView.sitAmount - dt * 6, 0)
            } else if isSleeping || isAsleep {
                blinkTimer = 0

                if !isAsleep {
                    let sleepSpeed: CGFloat = 1.5
                    catView.eyeClose += (1 - catView.eyeClose) * min(1, sleepSpeed * dt)
                    catView.sitAmount += (1 - catView.sitAmount) * min(1, sleepSpeed * dt)
                    if catView.eyeClose > 0.95 && catView.sitAmount > 0.95 {
                        isAsleep = true
                    }
                }

                if isAsleep {
                    catView.eyeClose = 1
                    catView.sitAmount = 1
                }
            } else {
                blinkTimer = 0
                catView.eyeClose = max(catView.eyeClose - dt * 6, 0)
                catView.sitAmount = max(catView.sitAmount - dt * 6, 0)
            }

            catView.currentLegs = pawsIdle
            targetLegYBob = -2 * SCALE * catView.sitAmount
        } else {
            targetLegYBob = 0
        }

        let smoothSpeed: CGFloat = 6
        catView.legYBob += (targetLegYBob - catView.legYBob) * min(1, smoothSpeed * dt)

        if jumpPhase != .airborne {
            let breatheSpeed: CGFloat = catView.sitAmount > 0.5 ? 0.6 : 1.0
            breatheTimer += dt * breatheSpeed
        }
        let bob = jumpPhase == .airborne ? 0 :
            max(0, sin(breatheTimer * CGFloat.pi * 2 / 1.2)) * SCALE * 0.2
        catView.bodyBob = round(bob)

        // Tail wag animation
        catView.tailWag = sin(breatheTimer * CGFloat.pi * 2 / 0.8)

        // Halo bob with lag (floaty feel)
        catView.haloBob += (catView.bodyBob - catView.haloBob) * min(1, 4 * dt)
    }

    func positionSprite() {
        catView.frame.origin.x = catX - spriteW / 2
        catView.frame.origin.y = catY
        catView.needsDisplay = true

        shadowView.frame.origin.x = catX - spriteW / 2
        shadowView.frame.origin.y = currentShadowFloorY() - SHADOW_FLOOR_MARGIN
        shadowView.facingRight = catView.facingRight
        shadowView.legRows = catView.currentLegs.count
        shadowView.needsDisplay = true
    }

    func currentShadowFloorY() -> CGFloat {
        if jumpPhase != .none {
            return min(jumpStartY, jumpEndY)
        }
        return level == .dock ? dockFloorY : groundFloorY
    }
}
