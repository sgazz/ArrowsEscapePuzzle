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

    @MainActor
    @Test func monumentCanBeCompletedAndRestarted() {
        let arrow = MonumentArrow(
            id: 1,
            points: [.init(x: 10, y: 10), .init(x: 30, y: 10)],
            color: .init(red: 0.5, green: 0.2, blue: 0.8, alpha: 1)
        )
        let level = MonumentLevel(
            formatVersion: 1,
            title: "Test",
            width: 40,
            height: 20,
            arrows: [arrow]
        )
        let game = MonumentGame(level: level)

        #expect(!game.didWin)
        #expect(game.progress == 0)
        game.tap(worldPoint: SIMD2(30, 10), tolerance: 2)
        #expect(game.didWin)
        #expect(game.progress == 1)

        game.restart()
        #expect(!game.didWin)
        #expect(game.remainingCount == 1)
    }

}
