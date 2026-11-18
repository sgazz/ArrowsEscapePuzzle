import MetalKit
import SwiftUI

struct MonumentView: View {
    let onClose: () -> Void
    @State private var game = MonumentGame(level: .stressTest10000)

    @State private var zoom: CGFloat = 1
    @State private var settledZoom: CGFloat = 1
    @State private var pan: CGSize = .zero
    @State private var settledPan: CGSize = .zero

    var body: some View {
        ZStack(alignment: .top) {
            MonumentMetalView(
                level: game.level,
                activeIDs: game.activeIDs,
                zoom: zoom,
                pan: pan,
                onTap: { point, tolerance in game.tap(worldPoint: point, tolerance: tolerance) }
            )
                .ignoresSafeArea()
                .gesture(dragGesture.simultaneously(with: magnifyGesture))
                .sensoryFeedback(.error, trigger: game.blockedArrowID)
                .sensoryFeedback(.impact(weight: .light), trigger: game.remainingCount)

            HStack(spacing: 12) {
                Button(action: onClose) {
                    Image(systemName: "chevron.left")
                        .font(.headline.bold())
                        .frame(width: 42, height: 42)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Nazad")

                VStack(alignment: .leading, spacing: 1) {
                    Text(game.level.title)
                        .font(.headline.bold())
                    Text("Preostalo: \(game.remainingCount) / \(game.level.arrows.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ProgressView(value: game.progress)
                        .tint(.purple)
                        .frame(maxWidth: 160)
                        .accessibilityLabel("Napredak")
                        .accessibilityValue("\(Int(game.progress * 100)) procenata")
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        zoom = 1
                        settledZoom = 1
                        pan = .zero
                        settledPan = .zero
                    }
                } label: {
                    Image(systemName: "arrow.up.left.and.down.right.magnifyingglass")
                        .frame(width: 42, height: 42)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Prikaži celu tablu")

                Button { game.restart() } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .frame(width: 42, height: 42)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Ponovi nivo")
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            if game.didWin {
                winOverlay
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: game.didWin)
        .background(Color(red: 0.975, green: 0.98, blue: 0.965))
    }

    private var winOverlay: some View {
        VStack(spacing: 18) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 58, weight: .bold))
                .foregroundStyle(.yellow)

            VStack(spacing: 6) {
                Text("Monument završen!")
                    .font(.largeTitle.bold())
                Text("Uklonio si svih 10.000 strelica.")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                Button("Početni ekran", action: onClose)
                    .buttonStyle(.bordered)
                Button("Igraj ponovo") { game.restart() }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
            }
        }
        .padding(28)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 28))
        .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.18))
        .accessibilityElement(children: .contain)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                pan = CGSize(
                    width: settledPan.width + value.translation.width,
                    height: settledPan.height + value.translation.height
                )
            }
            .onEnded { _ in settledPan = pan }
    }

    private var magnifyGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in zoom = min(max(settledZoom * value, 0.8), 12) }
            .onEnded { _ in settledZoom = zoom }
    }
}

private struct MonumentMetalView: UIViewRepresentable {
    let level: MonumentLevel
    let activeIDs: Set<UInt32>
    let zoom: CGFloat
    let pan: CGSize
    let onTap: (SIMD2<Float>, Float) -> Void

    final class Coordinator: NSObject {
        var renderer: MonumentRenderer?
        var onTap: ((SIMD2<Float>, Float) -> Void)?

        @objc func tapped(_ recognizer: UITapGestureRecognizer) {
            guard let view = recognizer.view as? MTKView,
                  let result = renderer?.worldPoint(for: recognizer.location(in: view), in: view) else { return }
            onTap?(result.point, result.tolerance)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        context.coordinator.renderer = MonumentRenderer(view: view, level: level)
        context.coordinator.onTap = onTap
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:)))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        return view
    }

    func updateUIView(_ view: MTKView, context: Context) {
        context.coordinator.renderer?.zoom = Float(zoom)
        context.coordinator.renderer?.pan = SIMD2(Float(pan.width * view.contentScaleFactor), Float(pan.height * view.contentScaleFactor))
        context.coordinator.renderer?.update(activeIDs: activeIDs)
        context.coordinator.onTap = onTap
    }
}
