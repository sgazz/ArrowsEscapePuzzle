//
//  ArrowsTests.swift
//  ArrowsTests
//
//  Created by Gazza on 14. 11. 2026..
//

import Testing
@testable import Arrows

struct ArrowsTests {

    @MainActor
    @Test func monument10KIsPlayable() {
        let clock = ContinuousClock()
        let start = clock.now
        let game = MonumentGame(level: .stressTest10000)
        let elapsed = start.duration(to: clock.now)

        #expect(game.remainingCount == 10_000)
        #expect(game.isRemovable(99))
        #expect(!game.isRemovable(98))

        let exitArrow = game.level.arrows[99]
        let head = exitArrow.points.last!
        game.tap(worldPoint: SIMD2(head.x, head.y), tolerance: 4)

        #expect(game.remainingCount == 9_999)
        #expect(game.isRemovable(98))
        print("Monument 10K initialization: \(elapsed)")
    }

}
