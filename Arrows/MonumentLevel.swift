import Foundation
import simd

struct MonumentPoint: Codable, Hashable, Sendable {
    let x: Float
    let y: Float
}

struct MonumentColor: Codable, Hashable, Sendable {
    let red: Float
    let green: Float
    let blue: Float
    let alpha: Float
}

struct MonumentArrow: Codable, Identifiable, Sendable {
    let id: UInt32
    let points: [MonumentPoint]
    let color: MonumentColor
}

struct MonumentLevel: Codable, Sendable {
    let formatVersion: Int
    let title: String
    let width: Float
    let height: Float
    let arrows: [MonumentArrow]

    static let stressTest10000 = preparedGrid(rows: 100, columns: 100)

    private static func preparedGrid(rows: Int, columns: Int) -> MonumentLevel {
        let arrowCount = rows * columns
        let cell: Float = 18
        let margin: Float = 16
        let palette: [MonumentColor] = [
            .init(red: 0.10, green: 0.48, blue: 0.86, alpha: 1),
            .init(red: 0.09, green: 0.67, blue: 0.57, alpha: 1),
            .init(red: 0.91, green: 0.25, blue: 0.35, alpha: 1),
            .init(red: 0.58, green: 0.25, blue: 0.88, alpha: 1),
            .init(red: 0.95, green: 0.58, blue: 0.08, alpha: 1),
            .init(red: 0.82, green: 0.16, blue: 0.48, alpha: 1)
        ]

        let arrows = (0..<arrowCount).map { index in
            let row = index / columns
            let column = index % columns
            let left = margin + Float(column) * cell
            let top = margin + Float(row) * cell
            let inset: Float = 3
            let low = top + cell - inset
            let high = top + inset
            let exitsRight = row % 2 == 0
            let bendsUp = column % 2 == 0
            let points: [MonumentPoint]

            if exitsRight && bendsUp {
                points = [
                    .init(x: left + inset, y: low),
                    .init(x: left + inset, y: high),
                    .init(x: left + cell - inset, y: high)
                ]
            } else if exitsRight {
                points = [
                    .init(x: left + inset, y: high),
                    .init(x: left + inset, y: low),
                    .init(x: left + cell - inset, y: low)
                ]
            } else if bendsUp {
                points = [
                    .init(x: left + cell - inset, y: low),
                    .init(x: left + cell - inset, y: high),
                    .init(x: left + inset, y: high)
                ]
            } else {
                points = [
                    .init(x: left + cell - inset, y: high),
                    .init(x: left + cell - inset, y: low),
                    .init(x: left + inset, y: low)
                ]
            }

            return MonumentArrow(
                id: UInt32(index),
                points: points,
                color: palette[(index * 7 + row) % palette.count]
            )
        }

        return MonumentLevel(
            formatVersion: 1,
            title: "Monument 10K",
            width: margin * 2 + Float(columns) * cell,
            height: margin * 2 + Float(rows) * cell,
            arrows: arrows
        )
    }
}
