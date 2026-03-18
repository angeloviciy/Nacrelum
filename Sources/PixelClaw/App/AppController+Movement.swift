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

        crabView.lookDir = eyeLookStep
    }

    func updateLookDirection(dt: CGFloat, fallbackX: CGFloat, smoothing: CGFloat = 14) {
        let targetLook: CGFloat
        let dx = lookTargetX(fallback: fallbackX) - crabX
        let maxDist: CGFloat = 300
        let closeRangeEyeDeadzone: CGFloat = 8
        let effectiveDX = abs(dx) <= closeRangeEyeDeadzone ? 0 : dx
        var directionalLook = max(-1, min(1, effectiveDX / maxDist))
        if !crabView.facingRight {
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

        updateApples(dt)

        if now - lastDockCheck > dockCheckInterval {
            lastDockCheck = now
            refreshDockBounds()
        }

        if !dockVisible {
            lastActivityTime = now
            return
        }

        let mouseLocation = NSEvent.mouseLocation
        let mouseX = mouseLocation.x

        if jumpPhase != .none {
            crabView.isWalking = false
            crabView.walkFacing = landingTravelDirection != 0 ? landingTravelDirection : jumpDirection
            updateJump(dt)
            updateVisuals(dt, isWalking: false)
            positionSprite()
            return
        }

        let timeSinceMove = now - lastMouseMoveTime
        if !isSeekingApples, let pending = pendingTargetX, abs(mouseX - pending) > 2 {
            lastMouseMoveTime = now
            mouseSettled = false
            if !isAsleep {
                lastActivityTime = now
                if crabView.sitAmount > 0.1 {
                    wakingUp = true
                }
            }
        }
        pendingTargetX = mouseX

        if wakingUp && crabView.sitAmount < 0.05 {
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

        if isSeekingApples {
            lastActivityTime = now
            if now - appleSeekStartTime < appleSeekDelay {
                autoTargetX = nil
            } else if let appleX = currentAppleSeekTargetX() {
                autoTargetX = max(screenLeft, min(screenRight, appleX))
            } else if apples.isEmpty {
                endAppleSeek(now: now)
            } else {
                autoTargetX = nil
            }
        } else {
            if !mouseSettled && timeSinceMove > settleDelay {
                mouseSettled = true
                let targetX = max(screenLeft, min(screenRight, mouseX))
                if abs(targetX - crabX) > autoThresh * 2 {
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
            let onDockArea = crabX >= dockLeft && crabX <= dockRight
            if level == .dock && onDockArea && (target < dockLeft || target > dockRight) {
                let exitDir: CGFloat = target < dockLeft ? -1 : 1
                let nearExitEdge = (exitDir < 0 && crabX <= dockLeft + jumpOffMargin)
                    || (exitDir > 0 && crabX >= dockRight - jumpOffMargin)
                if nearExitEdge {
                    debugLog(String(format: "jumpDown target=%.1f dir=%.0f x=%.1f dock=[%.1f,%.1f]", target, exitDir, crabX, dockLeft, dockRight))
                    startJump(down: true, direction: exitDir)
                    updateVisuals(dt, isWalking: false)
                    positionSprite()
                    return
                }
            }

            let shouldTransitionUpToDock = level == .ground && (
                (target >= dockLeft && target <= dockRight)
                    || (isSeekingApples && pathCrossesDockOnGround(from: crabX, to: target))
            )
            if shouldTransitionUpToDock {
                let entryDir = dockEntryDirection(for: target)
                let approachX = dockEntryApproachX(for: target)
                let jumpMargin: CGFloat = 50
                let underDock = crabX >= dockLeft && crabX <= dockRight
                let nearDockEntry = abs(crabX - approachX) <= jumpMargin
                if nearDockEntry {
                    debugLog(String(format: "jumpUp target=%.1f entryDir=%.0f x=%.1f approachX=%.1f dock=[%.1f,%.1f]", target, entryDir, crabX, approachX, dockLeft, dockRight))
                    startJump(down: false, direction: entryDir)
                    updateVisuals(dt, isWalking: false)
                    positionSprite()
                    return
                }
                if underDock {
                    debugLog(String(format: "underDock reroute target=%.1f approachX=%.1f entryDir=%.0f x=%.1f", target, approachX, entryDir, crabX))
                    movementTarget = approachX
                    autoTargetX = approachX
                }
            }

            let dx = movementTarget - crabX
            if abs(dx) > autoThresh {
                let dir: CGFloat = dx > 0 ? 1 : -1
                let activeWalkSpeed = isSeekingApples ? walkSpeed * 1.6 : walkSpeed
                let nextX = crabX + dir * min(activeWalkSpeed * dt, abs(dx))

                if level == .dock && onDockArea
                    && (nextX < dockLeft + jumpOffMargin || nextX > dockRight - jumpOffMargin)
                    && (target < dockLeft || target > dockRight) {
                    debugLog(String(format: "jumpDown target=%.1f dir=%.0f nextX=%.1f dock=[%.1f,%.1f]", target, dir, nextX, dockLeft, dockRight))
                    startJump(down: true, direction: dir)
                    updateVisuals(dt, isWalking: false)
                    positionSprite()
                    return
                }

                if shouldStartAppleHop(remainingDistance: abs(dx), direction: dir) {
                    debugLog(String(format: "appleHop target=%.1f dir=%.0f x=%.1f", target, dir, crabX))
                    startHop(direction: dir)
                    updateVisuals(dt, isWalking: false)
                    positionSprite()
                    return
                }

                crabX = nextX
                crabView.facingRight = dir > 0
                walkFacing = dir
                isWalking = true

                if crabX >= minX && crabX <= maxX {
                    crabX = max(minX, min(maxX, crabX))
                }

                if abs(crabX - target) <= autoThresh {
                    crabX = max(minX, min(maxX, movementTarget))
                    autoTargetX = nil
                }
            } else {
                crabX = max(minX, min(maxX, movementTarget))
                autoTargetX = nil
            }
        }

        crabView.isWalking = isWalking
        crabView.walkFacing = walkFacing
        if isWalking {
            lastActivityTime = now
        }

        updateLookDirection(dt: dt, fallbackX: mouseX)

        updateVisuals(dt, isWalking: isWalking)
        positionSprite()
    }

    func startJump(down: Bool, direction: CGFloat) {
        debugLog(String(format: "startJump down=%@ dir=%.0f from=(%.1f,%.1f) toY=%.1f", down.description, direction, crabX, crabY, down ? groundFloorY : dockFloorY))
        jumpPhase = .squish
        jumpTimer = 0
        jumpStartY = crabY
        jumpEndY = down ? groundFloorY : dockFloorY
        jumpDirection = direction
        currentJumpHorizontalDistance = jumpHorizontalDistance
        landingTravelDirection = direction
        autoTargetX = nil
        crabView.facingRight = direction > 0
    }

    func startHop(direction: CGFloat) {
        debugLog(String(format: "startHop dir=%.0f from=(%.1f,%.1f)", direction, crabX, crabY))
        jumpPhase = .squish
        jumpTimer = 0
        jumpStartY = crabY
        jumpEndY = crabY
        jumpDirection = direction
        currentJumpHorizontalDistance = jumpHorizontalDistance
        landingTravelDirection = direction
        autoTargetX = nil
        crabView.facingRight = direction > 0
    }

    func startInPlaceJump() {
        jumpPhase = .squish
        jumpTimer = 0
        jumpStartY = crabY
        jumpEndY = crabY
        jumpDirection = crabView.facingRight ? 1 : -1
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
            crabView.scaleX = 1 + 0.18 * t
            crabView.scaleY = 1 - 0.18 * t
            crabView.currentLegs = legsSquish
            crabView.armsRaised = false

        case .airborne:
            let t = min(1, jumpTimer / airDur)
            let linearY = jumpStartY + (jumpEndY - jumpStartY) * t
            let arc = 4 * jumpArcHeight * t * (1 - t)
            crabY = linearY + arc

            crabX += jumpDirection * (currentJumpHorizontalDistance / airDur) * dt
            crabX = max(screenLeft, min(screenRight, crabX))

            if t < 0.5 {
                crabView.currentLegs = legsRising
                crabView.armsRaised = true
                crabView.scaleX = 0.88
                crabView.scaleY = 1.18
            } else {
                crabView.currentLegs = legsFalling
                crabView.armsRaised = false
                crabView.scaleX = 0.92
                crabView.scaleY = 1.10
            }

            if t >= 1 {
                crabY = jumpEndY
                jumpPhase = .land
                jumpTimer = 0
                level = jumpEndY == dockFloorY ? .dock : .ground
            }

        case .land:
            if jumpTimer >= landDur {
                jumpPhase = .none
                jumpTimer = 0
                crabY = jumpEndY
                crabView.scaleX = 1
                crabView.scaleY = 1
                crabView.currentLegs = legsIdle
                crabView.armsRaised = false
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

            crabY = jumpEndY
            crabView.scaleX = 1 + 0.22 * impactT - 0.10 * recoveryT
            crabView.scaleY = 1 - 0.24 * impactT + 0.10 * recoveryT
            if landT < 0.42 {
                crabView.currentLegs = legsLand
            } else if landT < 0.78 {
                crabView.currentLegs = legsLandRecover
            } else {
                crabView.currentLegs = movingLanding ? legsWalk : legsIdle
            }
            crabView.armsRaised = false

        case .none:
            break
        }

        let look: CGFloat
        if currentJumpHorizontalDistance == 0 {
            look = 0
        } else {
            var jumpLook: CGFloat = jumpDirection > 0 ? 1 : -1
            if !crabView.facingRight {
                jumpLook *= -1
            }
            look = jumpLook
        }
        rawLookDir = look
        lookDirVelocity = 0
        eyeLookStep = look == 0 ? 0 : (look > 0 ? 1 : -1)
        crabView.lookDir = eyeLookStep
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
                crabView.legFrame = crabView.legFrame == 0 ? 1 : 0
                walkTimer = 0
                if settling && crabView.legFrame == 0 {
                    settleTimer = 0
                }
            }
            crabView.currentLegs = crabView.legFrame == 0 ? legsIdle : legsWalk
            crabView.scaleX = 1
            crabView.scaleY = 1
            crabView.armsRaised = false
            targetLegYBob = crabView.legFrame == 1 ? SCALE * 0.4 : 0
        } else if jumpPhase == .none {
            crabView.legFrame = 0
            walkTimer = 0
            settleTimer = 0
            crabView.scaleX = 1
            crabView.scaleY = 1
            crabView.armsRaised = false

            let now = CACurrentMediaTime()
            let idleTime = now - lastActivityTime
            let isDrowsy = idleTime > drowsyDelay && idleTime <= sleepDelay
            let isSleeping = idleTime > sleepDelay

            if isDrowsy {
                blinkTimer += dt
                let blinkCycle = blinkTimer.truncatingRemainder(dividingBy: 0.8)
                if blinkCycle < 0.12 {
                    crabView.eyeClose = min(max(crabView.eyeClose, 0.85), 1)
                } else {
                    crabView.eyeClose = max(crabView.eyeClose - dt * 8, 0)
                }
                crabView.sitAmount = max(crabView.sitAmount - dt * 6, 0)
            } else if isSleeping || isAsleep {
                blinkTimer = 0

                if !isAsleep {
                    let sleepSpeed: CGFloat = 1.5
                    crabView.eyeClose += (1 - crabView.eyeClose) * min(1, sleepSpeed * dt)
                    crabView.sitAmount += (1 - crabView.sitAmount) * min(1, sleepSpeed * dt)
                    if crabView.eyeClose > 0.95 && crabView.sitAmount > 0.95 {
                        isAsleep = true
                    }
                }

                if isAsleep {
                    crabView.eyeClose = 1
                    crabView.sitAmount = 1
                }
            } else {
                blinkTimer = 0
                crabView.eyeClose = max(crabView.eyeClose - dt * 6, 0)
                crabView.sitAmount = max(crabView.sitAmount - dt * 6, 0)
            }

            crabView.currentLegs = legsIdle
            targetLegYBob = -2 * SCALE * crabView.sitAmount
        } else {
            targetLegYBob = 0
        }

        let smoothSpeed: CGFloat = 6
        crabView.legYBob += (targetLegYBob - crabView.legYBob) * min(1, smoothSpeed * dt)

        if jumpPhase != .airborne {
            let breatheSpeed: CGFloat = crabView.sitAmount > 0.5 ? 0.6 : 1.0
            breatheTimer += dt * breatheSpeed
        }
        let bob = jumpPhase == .airborne ? 0 :
            max(0, sin(breatheTimer * CGFloat.pi * 2 / 1.2)) * SCALE * 0.2
        crabView.bodyBob = round(bob)
    }

    func positionSprite() {
        crabView.frame.origin.x = crabX - spriteW / 2
        crabView.frame.origin.y = crabY
        crabView.needsDisplay = true

        shadowView.frame.origin.x = crabX - spriteW / 2
        shadowView.frame.origin.y = currentShadowFloorY() - SHADOW_FLOOR_MARGIN
        shadowView.facingRight = crabView.facingRight
        shadowView.legRows = crabView.currentLegs.count
        shadowView.needsDisplay = true
    }

    func currentShadowFloorY() -> CGFloat {
        if jumpPhase != .none {
            return min(jumpStartY, jumpEndY)
        }
        return level == .dock ? dockFloorY : groundFloorY
    }
}
