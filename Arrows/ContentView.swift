import SwiftUI

private enum AppScreen {
    case home, levels, game
}

struct ContentView: View {
    @State private var game = ArrowGame()
    @State private var shakingArrow: UUID?
    @State private var escapingArrows: Set<UUID> = []
    @State private var screen: AppScreen = .home
    @AppStorage("hasSeenArrowTutorial") private var hasSeenTutorial = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.95, green: 0.98, blue: 1), Color(red: 0.84, green: 0.93, blue: 1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            switch screen {
            case .home:
                homeScreen.transition(.opacity.combined(with: .scale(scale: 0.96)))
            case .levels:
                levelScreen.transition(.opacity.combined(with: .move(edge: .trailing)))
            case .game:
                gameScreen.transition(.opacity)
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.84), value: screen)
        .sensoryFeedback(.impact(weight: .light), trigger: game.remainingCount)
        .sensoryFeedback(.success, trigger: game.didWin)
    }

    private var gameScreen: some View {
        ZStack {
            VStack(spacing: 18) {
                header
                progressPanel
                board
                footer
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            if game.didWin {
                winCard.transition(.scale.combined(with: .opacity))
            }

            if !hasSeenTutorial {
                tutorialCard.transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.78), value: game.didWin)
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: hasSeenTutorial)
    }

    private var homeScreen: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "arrow.up.right.circle.fill")
                    .font(.system(size: 88, weight: .black))
                    .foregroundStyle(Color.indigo.gradient)
                    .shadow(color: .indigo.opacity(0.2), radius: 18, y: 10)
                Text("ARROWS")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundStyle(.indigo)
                Text("Oslobodi put. Pronađi redosled.")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 8) {
                Image(systemName: "star.fill").foregroundStyle(.yellow)
                Text("\(game.totalStars) / \(game.levelCount * 3)")
                    .font(.title3.bold())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.white.opacity(0.72), in: Capsule())

            VStack(spacing: 14) {
                Button {
                    screen = .game
                } label: {
                    Label("Nastavi — nivo \(game.levelNumber)", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GameButtonStyle(color: .indigo))

                Button {
                    screen = .levels
                } label: {
                    Label("Izaberi nivo", systemImage: "square.grid.3x3.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GameButtonStyle(color: .teal))
            }
            .frame(maxWidth: 360)

            Spacer()
            Text("30 logičkih izazova")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(28)
    }

    private var levelScreen: some View {
        VStack(spacing: 18) {
            HStack {
                Button { screen = .home } label: {
                    Image(systemName: "chevron.left")
                        .font(.title2.bold())
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.75), in: Circle())
                }
                .accessibilityLabel("Nazad")

                Spacer()
                VStack(spacing: 2) {
                    Text("Nivoi")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                    Text("\(game.totalStars) osvojenih zvezdica")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }

            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 14) {
                    ForEach(0..<game.levelCount, id: \.self) { level in
                        levelButton(level)
                    }
                }
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private func levelButton(_ level: Int) -> some View {
        let unlocked = game.isUnlocked(level)
        let stars = game.stars(for: level)

        return Button {
            game.selectLevel(level)
            screen = .game
        } label: {
            VStack(spacing: 7) {
                if unlocked {
                    Text("\(level + 1)")
                        .font(.title2.bold())
                    HStack(spacing: 2) {
                        ForEach(1...3, id: \.self) { star in
                            Image(systemName: star <= stars ? "star.fill" : "star")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(stars > 0 ? .yellow : .white.opacity(0.65))
                } else {
                    Image(systemName: "lock.fill")
                        .font(.title2)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(unlocked ? Color.indigo.gradient : Color.gray.gradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: unlocked ? .indigo.opacity(0.18) : .clear, radius: 7, y: 5)
        }
        .disabled(!unlocked)
        .accessibilityLabel(unlocked ? "Nivo \(level + 1), \(stars) zvezdice" : "Nivo \(level + 1), zaključan")
    }

    private var progressPanel: some View {
        VStack(spacing: 7) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.7))
                    Capsule()
                        .fill(Color.indigo.gradient)
                        .frame(width: proxy.size.width * game.progress)
                }
            }
            .frame(height: 9)

            HStack {
                Text("Napredak")
                Spacer()
                Text("Preostalo: \(game.remainingCount)")
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("ARROWS")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(Color.indigo)
                Text("Nivo \(game.levelNumber) od \(game.levelCount)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("\(game.difficultyName) • \(game.themeName)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.indigo.opacity(0.75))
            }
            Spacer()
            Button { screen = .home } label: {
                Image(systemName: "house.fill")
                    .foregroundStyle(.indigo)
                    .frame(width: 34, height: 34)
                    .background(.white.opacity(0.72), in: Circle())
            }
            .accessibilityLabel("Početni ekran")
            HStack(spacing: 5) {
                ForEach(0..<ArrowGame.maximumMistakes, id: \.self) { index in
                    Image(systemName: index < game.remainingHearts ? "heart.fill" : "heart")
                        .foregroundStyle(index < game.remainingHearts ? .pink : .gray.opacity(0.45))
                }
            }
            .font(.title3)
        }
    }

    private var board: some View {
        GeometryReader { proxy in
            let cell = min(proxy.size.width / CGFloat(game.columns), proxy.size.height / CGFloat(game.rows))
            let width = cell * CGFloat(game.columns)
            let height = cell * CGFloat(game.rows)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.white.opacity(0.72))
                    .shadow(color: .blue.opacity(0.12), radius: 20, y: 10)

                ThemeWatermark(name: game.themeName)
                    .padding(cell * 0.45)
                    .frame(width: width, height: height)

                ForEach(game.activeArrows) { arrow in
                    ArrowPathView(arrow: arrow, cellSize: cell, isEscaping: escapingArrows.contains(arrow.id))
                        .frame(width: width, height: height)
                        .contentShape(ArrowHitShape(points: arrow.points, cellSize: cell))
                        .offset(x: shakingArrow == arrow.id ? 7 : 0)
                        .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: arrow.direction.exitTransition))
                        .onTapGesture { tap(arrow) }
                        .accessibilityLabel("Savijena strelica usmerena \(arrow.direction.accessibilityName)")
                        .accessibilityHint(game.canRemove(arrow) ? "Dvostruki dodir uklanja strelicu" : "Put je trenutno blokiran")
                }
            }
            .frame(width: width, height: height)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .aspectRatio(CGFloat(game.columns) / CGFloat(game.rows), contentMode: .fit)
        .frame(maxHeight: 560)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button {
                escapingArrows.removeAll()
                withAnimation { game.restart() }
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .frame(width: 26)
            }
            .buttonStyle(GameButtonStyle(color: .indigo.opacity(0.82)))
            .accessibilityLabel("Ponovi nivo")

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) { game.undo() }
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .frame(width: 26)
            }
            .buttonStyle(GameButtonStyle(color: game.canUndo ? .teal : .gray.opacity(0.55)))
            .disabled(!game.canUndo)
            .accessibilityLabel("Vrati poslednji potez")

            Button {
                guard let hint = game.hint else { return }
                game.registerHint()
                withAnimation(.easeInOut(duration: 0.18).repeatCount(3, autoreverses: true)) { shakingArrow = hint.id }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { shakingArrow = nil }
            } label: {
                Label("Pomoć", systemImage: "lightbulb.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(GameButtonStyle(color: .orange))
        }
    }

    private var winCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 7) {
                ForEach(1...3, id: \.self) { star in
                    Image(systemName: star <= game.starsEarned ? "star.fill" : "star")
                        .foregroundStyle(star <= game.starsEarned ? .yellow : .gray.opacity(0.4))
                        .scaleEffect(star == 2 ? 1.2 : 1)
                }
            }
            .font(.system(size: 38, weight: .bold))
            Text(game.isLastLevel ? "Bravo!" : "Nivo završen!")
                .font(.system(size: 27, weight: .black, design: .rounded))
            Text(game.isLastLevel ? "Završio si sve nivoe." : "Sve strelice su oslobođene.")
                .foregroundStyle(.secondary)
            Button(game.isLastLevel ? "Igraj ponovo" : "Sledeći nivo") {
                withAnimation { game.advance() }
            }
            .buttonStyle(GameButtonStyle(color: .indigo))
        }
        .padding(28)
        .frame(maxWidth: 310)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .indigo.opacity(0.22), radius: 30, y: 14)
    }

    private var tutorialCard: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.up.right.circle.fill")
                .font(.system(size: 58))
                .foregroundStyle(Color.indigo.gradient)

            Text("Kako se igra?")
                .font(.system(size: 28, weight: .black, design: .rounded))

            VStack(alignment: .leading, spacing: 14) {
                TutorialRow(icon: "hand.tap.fill", text: "Dodirni strelicu čiji je put slobodan.")
                TutorialRow(icon: "arrow.up.right", text: "Strelica odleće samo u smeru u kom pokazuje.")
                TutorialRow(icon: "heart.fill", text: "Blokiran potez oduzima jedno srce.")
            }

            Button("Počni igru") {
                hasSeenTutorial = true
            }
            .buttonStyle(GameButtonStyle(color: .indigo))
        }
        .padding(28)
        .frame(maxWidth: 340)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: .indigo.opacity(0.25), radius: 35, y: 16)
        .padding(24)
    }

    private func tap(_ arrow: ArrowPiece) {
        guard escapingArrows.isEmpty else { return }
        if game.canRemove(arrow) {
            withAnimation(.easeInOut(duration: 0.32)) {
                _ = escapingArrows.insert(arrow.id)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                withAnimation(.easeIn(duration: 0.28)) {
                    game.remove(arrow)
                    _ = escapingArrows.remove(arrow.id)
                }
            }
        } else {
            game.registerMistake()
            withAnimation(.linear(duration: 0.07).repeatCount(5, autoreverses: true)) { shakingArrow = arrow.id }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { shakingArrow = nil }
        }
    }
}

private struct ThemeWatermark: View {
    let name: String

    var body: some View {
        Group {
            switch name {
            case "Srce":
                Image(systemName: "heart.fill").resizable()
            case "Dijamant":
                Image(systemName: "diamond.fill").resizable()
            case "Krug":
                Image(systemName: "circle.fill").resizable()
            case "Krst":
                Image(systemName: "plus").resizable()
            default:
                Color.clear
            }
        }
        .scaledToFit()
        .foregroundStyle(.indigo.opacity(0.045))
        .accessibilityHidden(true)
    }
}

private struct TutorialRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .foregroundStyle(.indigo)
                .frame(width: 28)
            Text(text)
                .font(.subheadline.weight(.semibold))
        }
    }
}

private struct ArrowPathView: View {
    let arrow: ArrowPiece
    let cellSize: CGFloat
    let isEscaping: Bool

    var body: some View {
        ArrowLineShape(points: arrow.points, cellSize: cellSize)
            .trim(from: isEscaping ? 0.78 : 0, to: 1)
            .stroke(
                arrow.color,
                style: StrokeStyle(lineWidth: max(5, cellSize * 0.16), lineCap: .round, lineJoin: .round)
            )
            .offset(escapeOffset)
            .shadow(color: arrow.color.opacity(0.18), radius: 3, y: 2)
    }

    private var escapeOffset: CGSize {
        guard isEscaping else { return .zero }
        let delta = arrow.direction.delta
        return CGSize(width: CGFloat(delta.column) * cellSize * 0.35, height: CGFloat(delta.row) * cellSize * 0.35)
    }
}

private struct ArrowLineShape: Shape {
    let points: [GridPoint]
    let cellSize: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first, let last = points.last, points.count >= 2 else { return path }

        path.move(to: center(first))
        let cornerRadius = cellSize * 0.3
        if points.count > 2 {
            for index in 1..<(points.count - 1) {
                let previousCenter = center(points[index - 1])
                let corner = center(points[index])
                let nextCenter = center(points[index + 1])
                let incoming = CGVector(dx: corner.x - previousCenter.x, dy: corner.y - previousCenter.y)
                let outgoing = CGVector(dx: nextCenter.x - corner.x, dy: nextCenter.y - corner.y)
                let beforeCorner = CGPoint(
                    x: corner.x - sign(incoming.dx) * cornerRadius,
                    y: corner.y - sign(incoming.dy) * cornerRadius
                )
                let afterCorner = CGPoint(
                    x: corner.x + sign(outgoing.dx) * cornerRadius,
                    y: corner.y + sign(outgoing.dy) * cornerRadius
                )
                path.addLine(to: beforeCorner)
                path.addQuadCurve(to: afterCorner, control: corner)
            }
        }
        path.addLine(to: center(last))

        let previous = points[points.count - 2]
        let direction = CGVector(
            dx: CGFloat(last.column - previous.column),
            dy: CGFloat(last.row - previous.row)
        )
        let perpendicular = CGVector(dx: -direction.dy, dy: direction.dx)
        let head = center(last)
        let wingLength = cellSize * 0.3
        let wingSpread = cellSize * 0.22

        path.move(to: CGPoint(
            x: head.x - direction.dx * wingLength + perpendicular.dx * wingSpread,
            y: head.y - direction.dy * wingLength + perpendicular.dy * wingSpread
        ))
        path.addLine(to: head)
        path.addLine(to: CGPoint(
            x: head.x - direction.dx * wingLength - perpendicular.dx * wingSpread,
            y: head.y - direction.dy * wingLength - perpendicular.dy * wingSpread
        ))
        return path
    }

    private func center(_ point: GridPoint) -> CGPoint {
        CGPoint(x: CGFloat(point.column) * cellSize + cellSize / 2, y: CGFloat(point.row) * cellSize + cellSize / 2)
    }

    private func sign(_ value: CGFloat) -> CGFloat {
        value == 0 ? 0 : (value > 0 ? 1 : -1)
    }
}

private struct ArrowHitShape: Shape {
    let points: [GridPoint]
    let cellSize: CGFloat

    func path(in rect: CGRect) -> Path {
        ArrowLineShape(points: points, cellSize: cellSize)
            .path(in: rect)
            .strokedPath(StrokeStyle(lineWidth: cellSize * 0.72, lineCap: .round, lineJoin: .round))
    }
}

private struct GameButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .background(color.opacity(configuration.isPressed ? 0.7 : 1), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

#Preview {
    ContentView()
}
