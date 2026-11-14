import SwiftUI

struct GridPoint: Hashable {
    let row: Int
    let column: Int

    func moved(_ direction: ArrowDirection) -> GridPoint {
        let delta = direction.delta
        return GridPoint(row: row + delta.row, column: column + delta.column)
    }
}

enum ArrowDirection: CaseIterable {
    case up, right, down, left

    var delta: (row: Int, column: Int) {
        switch self {
        case .up: (-1, 0)
        case .right: (0, 1)
        case .down: (1, 0)
        case .left: (0, -1)
        }
    }

    var accessibilityName: String {
        switch self {
        case .up: "gore"
        case .right: "desno"
        case .down: "dole"
        case .left: "levo"
        }
    }

    var exitTransition: AnyTransition {
        let distance: CGFloat = 800
        return switch self {
        case .up: AnyTransition.offset(CGSize(width: 0, height: -distance)).combined(with: .opacity)
        case .right: AnyTransition.offset(CGSize(width: distance, height: 0)).combined(with: .opacity)
        case .down: AnyTransition.offset(CGSize(width: 0, height: distance)).combined(with: .opacity)
        case .left: AnyTransition.offset(CGSize(width: -distance, height: 0)).combined(with: .opacity)
        }
    }

    static func between(_ start: GridPoint, _ end: GridPoint) -> ArrowDirection? {
        switch (end.row - start.row, end.column - start.column) {
        case (-1, 0): .up
        case (0, 1): .right
        case (1, 0): .down
        case (0, -1): .left
        default: nil
        }
    }
}

struct ArrowPiece: Identifiable, Equatable {
    let id = UUID()
    let points: [GridPoint]
    let color: Color

    var head: GridPoint { points[points.count - 1] }
    var direction: ArrowDirection { ArrowDirection.between(points[points.count - 2], head) ?? .up }
}

struct ArrowLevel {
    let rows: Int
    let columns: Int
    let arrows: [ArrowPiece]
    let themeName: String
}

@Observable
final class ArrowGame {
    static let maximumMistakes = 3

    private static let savedLevelKey = "selectedArrowLevel"
    private static let unlockedLevelKey = "highestUnlockedArrowLevel"

    private(set) var levelIndex: Int
    private(set) var activeArrows: [ArrowPiece] = []
    private(set) var mistakes = 0
    private(set) var hintsUsed = 0
    private(set) var removedArrows: [ArrowPiece] = []
    private let levels = ArrowLevel.generatedLevels

    init() {
        let savedLevel = UserDefaults.standard.integer(forKey: Self.savedLevelKey)
        levelIndex = min(max(0, savedLevel), levels.count - 1)
        loadLevel()
    }

    var levelNumber: Int { levelIndex + 1 }
    var levelCount: Int { levels.count }
    var totalStars: Int { (0..<levelCount).reduce(0) { $0 + stars(for: $1) } }
    var highestUnlockedLevel: Int {
        min(max(levelIndex, UserDefaults.standard.integer(forKey: Self.unlockedLevelKey)), levelCount - 1)
    }
    var rows: Int { levels[levelIndex].rows }
    var columns: Int { levels[levelIndex].columns }
    var difficultyName: String {
        switch levelIndex {
        case 0..<10: "Teško"
        case 10..<20: "Veoma teško"
        case 20..<29: "Ekspert"
        default: "Ekspert"
        }
    }
    var themeName: String { levels[levelIndex].themeName }
    var remainingHearts: Int { max(0, Self.maximumMistakes - mistakes) }
    var remainingCount: Int { activeArrows.count }
    var totalCount: Int { levels[levelIndex].arrows.count }
    var progress: Double { totalCount == 0 ? 1 : Double(totalCount - remainingCount) / Double(totalCount) }
    var canUndo: Bool { !removedArrows.isEmpty && !didWin }
    var didWin: Bool { activeArrows.isEmpty }
    var isLastLevel: Bool { levelIndex == levels.count - 1 }
    var hint: ArrowPiece? { activeArrows.first(where: canRemove) }
    var starsEarned: Int {
        if mistakes == 0 && hintsUsed == 0 { return 3 }
        if mistakes <= 1 && hintsUsed <= 1 { return 2 }
        return 1
    }
    var bestStars: Int { UserDefaults.standard.integer(forKey: starsKey) }

    private var starsKey: String { "arrowLevelStars_\(levelIndex)" }

    func canRemove(_ arrow: ArrowPiece) -> Bool {
        let occupied = Set(activeArrows.filter { $0.id != arrow.id }.flatMap(\.points))
        return Self.rayIsClear(from: arrow.head, direction: arrow.direction, rows: rows, columns: columns, occupied: occupied)
    }

    func remove(_ arrow: ArrowPiece) {
        guard canRemove(arrow) else { return }
        activeArrows.removeAll { $0.id == arrow.id }
        removedArrows.append(arrow)
        if didWin {
            UserDefaults.standard.set(max(bestStars, starsEarned), forKey: starsKey)
            let newlyUnlocked = min(levelIndex + 1, levelCount - 1)
            UserDefaults.standard.set(max(highestUnlockedLevel, newlyUnlocked), forKey: Self.unlockedLevelKey)
        }
    }

    func undo() {
        guard let arrow = removedArrows.popLast(), !didWin else { return }
        activeArrows.append(arrow)
    }

    func registerHint() { hintsUsed += 1 }

    func stars(for level: Int) -> Int {
        UserDefaults.standard.integer(forKey: "arrowLevelStars_\(level)")
    }

    func isUnlocked(_ level: Int) -> Bool {
        level >= 0 && level <= highestUnlockedLevel
    }

    func selectLevel(_ level: Int) {
        guard level >= 0, level < levelCount, isUnlocked(level) else { return }
        levelIndex = level
        UserDefaults.standard.set(levelIndex, forKey: Self.savedLevelKey)
        loadLevel()
    }

    func registerMistake() {
        mistakes += 1
        if mistakes >= Self.maximumMistakes { restart() }
    }

    func restart() { loadLevel() }

    func advance() {
        levelIndex = isLastLevel ? 0 : levelIndex + 1
        UserDefaults.standard.set(levelIndex, forKey: Self.savedLevelKey)
        loadLevel()
    }

    private func loadLevel() {
        activeArrows = levels[levelIndex].arrows
        mistakes = 0
        hintsUsed = 0
        removedArrows = []
    }

    fileprivate static func rayIsClear(
        from point: GridPoint,
        direction: ArrowDirection,
        rows: Int,
        columns: Int,
        occupied: Set<GridPoint>
    ) -> Bool {
        var next = point.moved(direction)
        while next.row >= 0, next.row < rows, next.column >= 0, next.column < columns {
            if occupied.contains(next) { return false }
            next = next.moved(direction)
        }
        return true
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}

@MainActor
private extension ArrowLevel {
    static let palette: [Color] = [
        Color(red: 0.16, green: 0.18, blue: 0.27),
        .indigo, .teal, .pink, .orange, .purple
    ]

    static let generatedLevels: [ArrowLevel] = (0..<30).map(hardLevel)

    static func hardLevel(number: Int) -> ArrowLevel {
        let dimensions: (rows: Int, columns: Int, minimum: Int, maximum: Int)
        switch number {
        case 0..<10: dimensions = (18, 14, 10, 24)
        case 10..<20: dimensions = (22, 16, 12, 28)
        default: dimensions = (28, 20, 16, 38)
        }

        let basePath = horizontalSnake(
            rows: 0..<dimensions.rows,
            columns: 0..<dimensions.columns,
            startFromLeft: true
        )
        var bestLevel: ArrowLevel?
        var bestScore = -Double.infinity

        for attempt in 0..<10 {
            let path = attempt == 0 ? basePath : randomizedHamiltonian(
                basePath,
                rows: dimensions.rows,
                columns: dimensions.columns,
                seed: UInt64(500_009 + number * 31_337 + attempt * 7_919),
                moves: 100 + number * 4 + attempt * 16
            )
            let pieces = splitSnake(
                path,
                seed: UInt64(80_021 + number * 12_277 + attempt * 613),
                minimumLength: dimensions.minimum,
                maximumLength: dimensions.maximum
            )
            let arrows = pieces.enumerated().map { index, points in
                ArrowPiece(points: points, color: palette[(index + number) % palette.count])
            }
            let level = ArrowLevel(
                rows: dimensions.rows,
                columns: dimensions.columns,
                arrows: arrows,
                themeName: "Gusta tabla"
            )
            guard level.isSolvable else { continue }
            let score = level.hardnessScore
            if score > bestScore {
                bestLevel = level
                bestScore = score
            }
        }

        guard let selected = bestLevel else {
            preconditionFailure("A hard level candidate must always be available")
        }
        assert(selected.coverage == 1, "Hard levels must cover the entire board")
        assert(selected.hardnessScore >= 68, "Hard level \(number + 1) did not pass the difficulty threshold")
        return selected
    }

    static func generate(number: Int) -> ArrowLevel {
        if number == 29 { return densePrototype() }

        let size = min(7 + number / 8, 10)
        let theme = levelMask(number: number, size: size)
        let maximumPieces = min(7 + number / 2, 20)
        let maximumLength = min(4 + number / 6, 8)
        let targetDensity = min(0.46 + Double(number) * 0.011, 0.76)
        let targetCells = Int(Double(theme.cells.count) * targetDensity)
        var generator = SeededGenerator(seed: UInt64(41_221 + number * 9_973))
        var occupied = Set<GridPoint>()
        var arrows: [ArrowPiece] = []

        while arrows.count < maximumPieces && occupied.count < targetCells {
            guard let points = makePath(
                size: size,
                maximumLength: maximumLength,
                allowed: theme.cells,
                occupied: occupied,
                generator: &generator
            ) else { break }

            let arrow = ArrowPiece(points: points, color: palette[(arrows.count + number) % palette.count])
            arrows.append(arrow)
            occupied.formUnion(points)
        }

        let level = ArrowLevel(rows: size, columns: size, arrows: arrows, themeName: theme.name)
        assert(level.isSolvable && arrows.count >= 4, "Generated level \(number + 1) must be playable")
        return level
    }

    static func densePrototype() -> ArrowLevel {
        let rows = 28
        let columns = 20
        let basePath = horizontalSnake(rows: 0..<rows, columns: 0..<columns, startFromLeft: true)

        for attempt in 0..<18 {
            let path = randomizedHamiltonian(
                basePath,
                rows: rows,
                columns: columns,
                seed: UInt64(170_041 + attempt * 13_337),
                moves: 260 + attempt * 20
            )
            let pieces = splitSnake(path, seed: UInt64(91_003 + attempt * 977))
            let arrows = pieces.enumerated().map { index, points in
                ArrowPiece(points: points, color: palette[index % palette.count])
            }
            let level = ArrowLevel(rows: rows, columns: columns, arrows: arrows, themeName: "Ultra gusta")
            let coveredCells = Set(arrows.flatMap(\.points)).count
            if coveredCells == rows * columns && level.isSolvable { return level }
        }

        let fallbackPieces = splitSnake(basePath, seed: 91_003)
        let fallbackArrows = fallbackPieces.enumerated().map { index, points in
            ArrowPiece(points: points, color: palette[index % palette.count])
        }
        let fallback = ArrowLevel(rows: rows, columns: columns, arrows: fallbackArrows, themeName: "Ultra gusta")
        assert(fallback.isSolvable, "Dense prototype fallback must be solvable")
        return fallback
    }

    static func randomizedHamiltonian(
        _ original: [GridPoint],
        rows: Int,
        columns: Int,
        seed: UInt64,
        moves: Int
    ) -> [GridPoint] {
        var path = original
        var generator = SeededGenerator(seed: seed)

        for _ in 0..<moves {
            let start = path[0]
            let candidates = ArrowDirection.allCases
                .map { start.moved($0) }
                .filter { point in
                    point.row >= 0 && point.row < rows && point.column >= 0 && point.column < columns && point != path[1]
                }
            guard let neighbor = candidates.randomElement(using: &generator),
                  let index = path.firstIndex(of: neighbor), index > 1 else { continue }

            path = Array(path[0..<index].reversed()) + Array(path[index...])
        }
        return path
    }

    static func horizontalSnake(
        rows: Range<Int>,
        columns: Range<Int>,
        startFromLeft: Bool
    ) -> [GridPoint] {
        var result: [GridPoint] = []
        for (offset, row) in rows.enumerated() {
            let leftToRight = offset.isMultiple(of: 2) == startFromLeft
            let values: [Int] = leftToRight
                ? Array(columns)
                : Array(stride(from: columns.upperBound - 1, through: columns.lowerBound, by: -1))
            result += values.map { GridPoint(row: row, column: $0) }
        }
        return result
    }

    static func verticalSnake(
        rows: Range<Int>,
        columns: Range<Int>,
        startFromTop: Bool
    ) -> [GridPoint] {
        var result: [GridPoint] = []
        for (offset, column) in columns.enumerated() {
            let topToBottom = offset.isMultiple(of: 2) == startFromTop
            let values: [Int] = topToBottom
                ? Array(rows)
                : Array(stride(from: rows.upperBound - 1, through: rows.lowerBound, by: -1))
            result += values.map { GridPoint(row: $0, column: column) }
        }
        return result
    }

    static func splitSnake(
        _ points: [GridPoint],
        seed: UInt64,
        minimumLength: Int = 22,
        maximumLength: Int = 44
    ) -> [[GridPoint]] {
        var generator = SeededGenerator(seed: seed)
        var pieces: [[GridPoint]] = []
        var start = 0

        while points.count - start >= 2 {
            let remaining = points.count - start
            if remaining <= maximumLength + 2 {
                pieces.append(Array(points[start...]))
                break
            }

            let desiredLength = Int.random(in: minimumLength...maximumLength, using: &generator)
            let targetEnd = start + desiredLength - 1
            let maximumEnd = min(start + maximumLength + 20, points.count - 3)
            let candidates = (start + 1...maximumEnd).filter { index in
                ArrowDirection.between(points[index - 1], points[index]) ==
                ArrowDirection.between(points[index], points[index + 1])
            }
            guard let end = candidates.min(by: {
                abs($0 - targetEnd) < abs($1 - targetEnd)
            }) else { break }

            pieces.append(Array(points[start...end]))
            start = end + 1
        }
        return pieces
    }

    static func makePath(
        size: Int,
        maximumLength: Int,
        allowed: Set<GridPoint>,
        occupied: Set<GridPoint>,
        generator: inout SeededGenerator
    ) -> [GridPoint]? {
        let empty = (0..<size).flatMap { row in
            (0..<size).map { GridPoint(row: row, column: $0) }
        }.filter { allowed.contains($0) && !occupied.contains($0) }

        guard !empty.isEmpty else { return nil }

        for _ in 0..<600 {
            guard let start = empty.randomElement(using: &generator) else { return nil }
            let targetLength = Int.random(in: 2...maximumLength, using: &generator)
            var path = [start]

            while path.count < targetLength {
                let current = path[path.count - 1]
                let options = ArrowDirection.allCases
                    .map { current.moved($0) }
                    .filter { point in
                        point.row >= 0 && point.row < size && point.column >= 0 && point.column < size &&
                        allowed.contains(point) && !occupied.contains(point) && !path.contains(point)
                    }
                guard let next = options.randomElement(using: &generator) else { break }
                path.append(next)
            }

            guard path.count >= max(2, targetLength - 1),
                  let direction = ArrowDirection.between(path[path.count - 2], path[path.count - 1]) else { continue }
            let blocked = occupied.union(path.dropLast())
            if ArrowGame.rayIsClear(
                from: path[path.count - 1],
                direction: direction,
                rows: size,
                columns: size,
                occupied: blocked
            ) {
                return path
            }
        }
        return nil
    }

    static func levelMask(number: Int, size: Int) -> (name: String, cells: Set<GridPoint>) {
        let allCells = Set((0..<size).flatMap { row in
            (0..<size).map { GridPoint(row: row, column: $0) }
        })
        guard number >= 18 else { return ("Klasična", allCells) }

        let center = Double(size - 1) / 2
        let scale = max(1, Double(size) / 2.15)
        let shape = (number - 18) % 4
        let cells = allCells.filter { point in
            let x = (Double(point.column) - center) / scale
            let y = (center - Double(point.row)) / scale
            switch shape {
            case 0:
                let heart = pow(x * x + y * y - 1, 3) - x * x * pow(y, 3)
                return heart <= 0.08
            case 1:
                return abs(x) + abs(y) <= 1.12
            case 2:
                return x * x + y * y <= 1.05
            default:
                return abs(x) <= 0.38 || abs(y) <= 0.38
            }
        }
        let name = ["Srce", "Dijamant", "Krug", "Krst"][shape]
        return (name, Set(cells))
    }

    var coverage: Double {
        Double(Set(arrows.flatMap(\.points)).count) / Double(rows * columns)
    }

    var hardnessScore: Double {
        let densityScore = min(coverage, 1) * 40
        let countScore = min(Double(arrows.count) / 20, 1) * 18

        var turns = 0
        var segments = 0
        for arrow in arrows {
            let directions = zip(arrow.points, arrow.points.dropFirst()).compactMap {
                ArrowDirection.between($0.0, $0.1)
            }
            segments += directions.count
            turns += zip(directions, directions.dropFirst()).filter { $0.0 != $0.1 }.count
        }
        let turnRatio = segments == 0 ? 0 : Double(turns) / Double(segments)
        let turnScore = min(turnRatio / 0.12, 1) * 16

        var remaining = arrows
        var narrowSteps = 0
        var samples = 0
        let initialChoices = removableArrows(in: remaining).count
        while !remaining.isEmpty {
            let available = removableArrows(in: remaining)
            guard let chosen = available.first else { break }
            samples += 1
            if available.count <= 3 { narrowSteps += 1 }
            remaining.removeAll { $0.id == chosen.id }
        }

        let initialScore = (1...3).contains(initialChoices) ? 12.0 : max(0, 12 - Double(initialChoices - 3) * 2)
        let narrowScore = samples == 0 ? 0 : Double(narrowSteps) / Double(samples) * 14
        return densityScore + countScore + turnScore + initialScore + narrowScore
    }

    func removableArrows(in remaining: [ArrowPiece]) -> [ArrowPiece] {
        remaining.filter { arrow in
            let occupied = Set(remaining.filter { $0.id != arrow.id }.flatMap(\.points))
            return ArrowGame.rayIsClear(
                from: arrow.head,
                direction: arrow.direction,
                rows: rows,
                columns: columns,
                occupied: occupied
            )
        }
    }

    var isSolvable: Bool {
        var remaining = arrows
        while !remaining.isEmpty {
            guard let index = remaining.firstIndex(where: { arrow in
                let occupied = Set(remaining.filter { $0.id != arrow.id }.flatMap(\.points))
                return ArrowGame.rayIsClear(
                    from: arrow.head,
                    direction: arrow.direction,
                    rows: rows,
                    columns: columns,
                    occupied: occupied
                )
            }) else { return false }
            remaining.remove(at: index)
        }
        return true
    }
}
