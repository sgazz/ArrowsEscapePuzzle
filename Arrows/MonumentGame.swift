import SwiftUI
import simd

@Observable
final class MonumentGame {
    let level: MonumentLevel
    private(set) var activeIDs: Set<UInt32>
    private(set) var blockedArrowID: UInt32?

    private let arrowsByID: [UInt32: MonumentArrow]
    private let blockers: [UInt32: Set<UInt32>]
    private let spatialIndex: MonumentSpatialIndex

    init(level: MonumentLevel) {
        self.level = level
        activeIDs = Set(level.arrows.map(\.id))
        arrowsByID = Dictionary(uniqueKeysWithValues: level.arrows.map { ($0.id, $0) })
        blockers = Self.makeBlockerGraph(level: level)
        spatialIndex = MonumentSpatialIndex(arrows: level.arrows)
    }

    var activeArrows: [MonumentArrow] {
        level.arrows.filter { activeIDs.contains($0.id) }
    }

    var remainingCount: Int { activeIDs.count }
    var progress: Double { 1 - Double(remainingCount) / Double(max(1, level.arrows.count)) }
    var didWin: Bool { activeIDs.isEmpty }

    func tap(worldPoint: SIMD2<Float>, tolerance: Float) {
        guard let arrowID = spatialIndex.closestArrow(
            to: worldPoint,
            tolerance: tolerance,
            activeIDs: activeIDs,
            arrowsByID: arrowsByID
        ) else { return }

        if isRemovable(arrowID) {
            activeIDs.remove(arrowID)
            blockedArrowID = nil
        } else {
            blockedArrowID = arrowID
        }
    }

    func restart() {
        activeIDs = Set(level.arrows.map(\.id))
        blockedArrowID = nil
    }

    func isRemovable(_ id: UInt32) -> Bool {
        blockers[id, default: []].isDisjoint(with: activeIDs)
    }

    private static func makeBlockerGraph(level: MonumentLevel) -> [UInt32: Set<UInt32>] {
        var result: [UInt32: Set<UInt32>] = [:]
        let collisionRadius: Float = 5
        let collisionIndex = MonumentCollisionIndex(level: level, padding: collisionRadius)
        let arrowsByID = Dictionary(uniqueKeysWithValues: level.arrows.map { ($0.id, $0) })

        for arrow in level.arrows where arrow.points.count >= 2 {
            let head = SIMD2(arrow.points.last!.x, arrow.points.last!.y)
            let previous = SIMD2(arrow.points[arrow.points.count - 2].x, arrow.points[arrow.points.count - 2].y)
            let direction = simd_normalize(head - previous)
            var arrowBlockers: Set<UInt32> = []

            let candidateIDs = collisionIndex.candidates(
                from: head,
                direction: direction,
                boardWidth: level.width,
                boardHeight: level.height
            )
            for candidateID in candidateIDs where candidateID != arrow.id {
                guard let candidate = arrowsByID[candidateID] else { continue }
                if rayHitsArrow(origin: head, direction: direction, arrow: candidate, radius: collisionRadius) {
                    arrowBlockers.insert(candidate.id)
                }
            }
            result[arrow.id] = arrowBlockers
        }
        return result
    }

    private static func rayHitsArrow(
        origin: SIMD2<Float>,
        direction: SIMD2<Float>,
        arrow: MonumentArrow,
        radius: Float
    ) -> Bool {
        for index in 0..<(arrow.points.count - 1) {
            let a = SIMD2(arrow.points[index].x, arrow.points[index].y)
            let b = SIMD2(arrow.points[index + 1].x, arrow.points[index + 1].y)
            if rayIntersectsSegment(origin: origin, direction: direction, a: a, b: b, radius: radius) {
                return true
            }
        }
        return false
    }

    private static func rayIntersectsSegment(
        origin: SIMD2<Float>,
        direction: SIMD2<Float>,
        a: SIMD2<Float>,
        b: SIMD2<Float>,
        radius: Float
    ) -> Bool {
        if abs(direction.x) > 0.5 {
            let minimumX = min(a.x, b.x) - radius
            let maximumX = max(a.x, b.x) + radius
            let crossesY = origin.y >= min(a.y, b.y) - radius && origin.y <= max(a.y, b.y) + radius
            let ahead = direction.x > 0 ? maximumX > origin.x + radius : minimumX < origin.x - radius
            return crossesY && ahead
        }

        let minimumY = min(a.y, b.y) - radius
        let maximumY = max(a.y, b.y) + radius
        let crossesX = origin.x >= min(a.x, b.x) - radius && origin.x <= max(a.x, b.x) + radius
        let ahead = direction.y > 0 ? maximumY > origin.y + radius : minimumY < origin.y - radius
        return crossesX && ahead
    }
}

private struct MonumentCollisionIndex {
    private struct Cell: Hashable {
        let x: Int
        let y: Int
    }

    private let cellSize: Float = 24
    private var cells: [Cell: Set<UInt32>] = [:]

    init(level: MonumentLevel, padding: Float) {
        for arrow in level.arrows where !arrow.points.isEmpty {
            let xs = arrow.points.map(\.x)
            let ys = arrow.points.map(\.y)
            let minimumX = Int(floor((xs.min()! - padding) / cellSize))
            let maximumX = Int(floor((xs.max()! + padding) / cellSize))
            let minimumY = Int(floor((ys.min()! - padding) / cellSize))
            let maximumY = Int(floor((ys.max()! + padding) / cellSize))

            for y in minimumY...maximumY {
                for x in minimumX...maximumX {
                    cells[Cell(x: x, y: y), default: []].insert(arrow.id)
                }
            }
        }
    }

    func candidates(
        from origin: SIMD2<Float>,
        direction: SIMD2<Float>,
        boardWidth: Float,
        boardHeight: Float
    ) -> Set<UInt32> {
        let originX = Int(floor(origin.x / cellSize))
        let originY = Int(floor(origin.y / cellSize))
        let maximumX = Int(ceil(boardWidth / cellSize))
        let maximumY = Int(ceil(boardHeight / cellSize))
        var result: Set<UInt32> = []

        if abs(direction.x) > 0.5 {
            let range = direction.x > 0 ? originX...maximumX : 0...originX
            for x in range {
                for y in (originY - 1)...(originY + 1) {
                    result.formUnion(cells[Cell(x: x, y: y), default: []])
                }
            }
        } else {
            let range = direction.y > 0 ? originY...maximumY : 0...originY
            for y in range {
                for x in (originX - 1)...(originX + 1) {
                    result.formUnion(cells[Cell(x: x, y: y), default: []])
                }
            }
        }
        return result
    }
}

private struct MonumentSpatialIndex {
    private struct Cell: Hashable {
        let x: Int
        let y: Int
    }

    private let cellSize: Float = 48
    private var cells: [Cell: Set<UInt32>] = [:]

    init(arrows: [MonumentArrow]) {
        for arrow in arrows where !arrow.points.isEmpty {
            let xs = arrow.points.map(\.x)
            let ys = arrow.points.map(\.y)
            let minimumX = Int(floor((xs.min()! - 10) / cellSize))
            let maximumX = Int(floor((xs.max()! + 10) / cellSize))
            let minimumY = Int(floor((ys.min()! - 10) / cellSize))
            let maximumY = Int(floor((ys.max()! + 10) / cellSize))

            for y in minimumY...maximumY {
                for x in minimumX...maximumX {
                    cells[Cell(x: x, y: y), default: []].insert(arrow.id)
                }
            }
        }
    }

    func closestArrow(
        to point: SIMD2<Float>,
        tolerance: Float,
        activeIDs: Set<UInt32>,
        arrowsByID: [UInt32: MonumentArrow]
    ) -> UInt32? {
        let centerX = Int(floor(point.x / cellSize))
        let centerY = Int(floor(point.y / cellSize))
        let radius = max(1, Int(ceil(tolerance / cellSize)))
        var candidates: Set<UInt32> = []

        for y in (centerY - radius)...(centerY + radius) {
            for x in (centerX - radius)...(centerX + radius) {
                candidates.formUnion(cells[Cell(x: x, y: y), default: []])
            }
        }

        return candidates
            .filter(activeIDs.contains)
            .compactMap { id -> (UInt32, Float)? in
                guard let arrow = arrowsByID[id] else { return nil }
                let distance = Self.distance(from: point, to: arrow)
                return distance <= tolerance ? (id, distance) : nil
            }
            .min { $0.1 < $1.1 }?.0
    }

    private static func distance(from point: SIMD2<Float>, to arrow: MonumentArrow) -> Float {
        var best = Float.greatestFiniteMagnitude
        for index in 0..<(arrow.points.count - 1) {
            let a = SIMD2(arrow.points[index].x, arrow.points[index].y)
            let b = SIMD2(arrow.points[index + 1].x, arrow.points[index + 1].y)
            let segment = b - a
            let lengthSquared = simd_length_squared(segment)
            let t = lengthSquared == 0 ? 0 : min(1, max(0, simd_dot(point - a, segment) / lengthSquared))
            best = min(best, simd_distance(point, a + segment * t))
        }
        return best
    }
}
