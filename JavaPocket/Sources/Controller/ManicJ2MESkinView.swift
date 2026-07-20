import CoreGraphics
import SwiftUI

struct ManicJ2MESkinView: View {
    let game: GameRecord
    let storage: GameStorage
    let continueGame: Bool
    let session: PlayerSession
    let onExit: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let fullSize = CGSize(
                width: proxy.size.width + proxy.safeAreaInsets.leading + proxy.safeAreaInsets.trailing,
                height: proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
            )
            let layout = ManicSkinLayout.layout(for: fullSize)
            let scaleX = fullSize.width / layout.designSize.width
            let scaleY = fullSize.height / layout.designSize.height

            ZStack(alignment: .topLeading) {
                Color.black
                ZStack(alignment: .topLeading) {
                    ManicPDFView(name: layout.background)
                        .frame(width: layout.designSize.width, height: layout.designSize.height)
                        .allowsHitTesting(false)

                    J2MEContainerView(
                        game: game,
                        storage: storage,
                        continueGame: continueGame,
                        session: session,
                        onExit: onExit
                    )
                    .frame(width: layout.screen.width, height: layout.screen.height)
                    .position(x: layout.screen.midX, y: layout.screen.midY)
                    .clipped()

                    ManicDPadView(frame: layout.dpad, onButton: session.press)
                    ManicPDFView(name: "thumbstick.pdf")
                        .frame(width: layout.dpad.width * 0.46, height: layout.dpad.height * 0.46)
                        .position(x: layout.dpad.midX, y: layout.dpad.midY)
                        .allowsHitTesting(false)

                    ForEach(layout.buttons) { item in
                        ManicSkinButton(item: item, onButton: session.press)
                    }
                }
                .frame(width: layout.designSize.width, height: layout.designSize.height)
                .scaleEffect(x: scaleX, y: scaleY, anchor: .topLeading)
                .frame(width: fullSize.width, height: fullSize.height, alignment: .topLeading)

                Button(action: onExit) {
                    Image(systemName: "xmark")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 54, height: 54)
                        .background(Color(red: 0.57, green: 0.04, blue: 0.04).opacity(0.92))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(.white.opacity(0.24), lineWidth: 2))
                }
                .padding(.top, max(proxy.safeAreaInsets.top + 8, 18))
                .padding(.trailing, 16)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(width: fullSize.width, height: fullSize.height)
            .offset(x: -proxy.safeAreaInsets.leading, y: -proxy.safeAreaInsets.top)
        }
        .ignoresSafeArea()
    }
}

private struct ManicSkinButton: View {
    let item: ManicSkinItem
    let onButton: (J2MEButton, Bool) -> Void
    @State private var isPressed = false

    var body: some View {
        let expandsHitArea = [.fire, .menu, .softkeyLeft, .softkeyRight].contains(item.button)
        let hitWidth = item.frame.width + (expandsHitArea ? 24 : 0)
        let hitHeight = item.frame.height + (expandsHitArea ? 24 : 0)
        ZStack {
            ManicPDFView(name: item.asset)
                .opacity(isPressed ? 0.72 : 1)
                .allowsHitTesting(false)
                .frame(width: item.frame.width, height: item.frame.height)
            ManicPressInputView(
                touchDown: {
                    guard !isPressed else { return }
                    isPressed = true
                    onButton(item.button, true)
                },
                touchUp: {
                    guard isPressed else { return }
                    isPressed = false
                    onButton(item.button, false)
                }
            )
            .frame(width: hitWidth, height: hitHeight)
        }
        .frame(width: hitWidth, height: hitHeight)
        .position(x: item.frame.midX, y: item.frame.midY)
    }
}

private struct ManicDPadView: View {
    let frame: CGRect
    let onButton: (J2MEButton, Bool) -> Void
    @State private var activeButton: J2MEButton?

    var body: some View {
        ZStack {
            ManicPDFView(name: "dpad.pdf")
                .allowsHitTesting(false)
            ManicDPadInputView { next in
                guard next != activeButton else { return }
                if let activeButton { onButton(activeButton, false) }
                activeButton = next
                if let next { onButton(next, true) }
            }
        }
        .frame(width: frame.width, height: frame.height)
        .position(x: frame.midX, y: frame.midY)
    }
}

private struct ManicPressInputView: UIViewRepresentable {
    let touchDown: () -> Void
    let touchUp: () -> Void

    func makeUIView(context: Context) -> ManicPressUIView {
        ManicPressUIView(touchDown: touchDown, touchUp: touchUp)
    }

    func updateUIView(_ uiView: ManicPressUIView, context: Context) {
        uiView.touchDown = touchDown
        uiView.touchUp = touchUp
    }
}

private final class ManicPressUIView: UIView {
    var touchDown: () -> Void
    var touchUp: () -> Void
    private var isPressed = false

    init(touchDown: @escaping () -> Void, touchUp: @escaping () -> Void) {
        self.touchDown = touchDown
        self.touchUp = touchUp
        super.init(frame: .zero)
        backgroundColor = .clear
        isMultipleTouchEnabled = true
    }

    required init?(coder: NSCoder) { nil }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isPressed else { return }
        isPressed = true
        touchDown()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { release() }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { release() }

    private func release() {
        guard isPressed else { return }
        isPressed = false
        touchUp()
    }
}

private struct ManicDPadInputView: UIViewRepresentable {
    let changed: (J2MEButton?) -> Void

    func makeUIView(context: Context) -> ManicDPadUIView {
        ManicDPadUIView(changed: changed)
    }

    func updateUIView(_ uiView: ManicDPadUIView, context: Context) {
        uiView.changed = changed
    }
}

private final class ManicDPadUIView: UIView {
    var changed: (J2MEButton?) -> Void

    init(changed: @escaping (J2MEButton?) -> Void) {
        self.changed = changed
        super.init(frame: .zero)
        backgroundColor = .clear
        isMultipleTouchEnabled = true
    }

    required init?(coder: NSCoder) { nil }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { update(touches) }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { update(touches) }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { changed(nil) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { changed(nil) }

    private func update(_ touches: Set<UITouch>) {
        guard let point = touches.first?.location(in: self) else { return }
        let dx = point.x - bounds.midX
        let dy = point.y - bounds.midY
        if hypot(dx, dy) <= min(bounds.width, bounds.height) * 0.18 {
            changed(.fire)
        } else if abs(dx) > abs(dy) {
            changed(dx < 0 ? .left : .right)
        } else {
            changed(dy < 0 ? .up : .down)
        }
    }
}

private struct ManicPDFView: UIViewRepresentable {
    let name: String

    func makeUIView(context: Context) -> PDFAssetUIView {
        PDFAssetUIView(assetName: name)
    }

    func updateUIView(_ uiView: PDFAssetUIView, context: Context) {}
}

private final class PDFAssetUIView: UIView {
    private let document: CGPDFDocument?

    init(assetName: String) {
        let base = (assetName as NSString).deletingPathExtension
        let ext = (assetName as NSString).pathExtension
        let url = Bundle.main.url(forResource: base, withExtension: ext, subdirectory: "ManicJ2MESkin")
            ?? Bundle.main.url(forResource: base, withExtension: ext)
        document = url.flatMap { CGPDFDocument($0 as CFURL) }
        super.init(frame: .zero)
        isOpaque = false
        backgroundColor = .clear
        contentMode = .redraw
        isUserInteractionEnabled = true
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ rect: CGRect) {
        guard let page = document?.page(at: 1), let context = UIGraphicsGetCurrentContext() else { return }
        context.saveGState()
        context.translateBy(x: 0, y: rect.height)
        context.scaleBy(x: 1, y: -1)
        context.concatenate(page.getDrawingTransform(.mediaBox, rect: rect, rotate: 0, preserveAspectRatio: true))
        context.drawPDFPage(page)
        context.restoreGState()
    }
}

private struct ManicSkinItem: Identifiable {
    let id: String
    let asset: String
    let frame: CGRect
    let button: J2MEButton
}

private struct ManicSkinLayout {
    let designSize: CGSize
    let background: String
    let screen: CGRect
    let dpad: CGRect
    let buttons: [ManicSkinItem]

    static func layout(for size: CGSize) -> ManicSkinLayout {
        let landscape = size.width > size.height
        let edgeToEdge = max(size.width, size.height) / max(min(size.width, size.height), 1) > 1.82
        if landscape { return edgeToEdge ? .edgeLandscape : .standardLandscape }
        return edgeToEdge ? .edgePortrait : .standardPortrait
    }

    private static func item(_ asset: String, _ x: CGFloat, _ y: CGFloat,
                             _ width: CGFloat, _ height: CGFloat, _ button: J2MEButton) -> ManicSkinItem {
        .init(id: button.rawValue, asset: asset,
              frame: CGRect(x: x, y: y, width: width, height: height), button: button)
    }

    private static func keypad(x: [CGFloat], y: [CGFloat], width: CGFloat, height: CGFloat) -> [ManicSkinItem] {
        let keys: [(String, J2MEButton)] = [
            ("num1_button.pdf", .num1), ("num2_button.pdf", .num2), ("num3_button.pdf", .num3),
            ("num4_button.pdf", .num4), ("num5_button.pdf", .num5), ("num6_button.pdf", .num6),
            ("num7_button.pdf", .num7), ("num8_button.pdf", .num8), ("num9_button.pdf", .num9),
            ("star_button.pdf", .star), ("num0_button.pdf", .num0), ("pound_button.pdf", .pound)
        ]
        return keys.enumerated().map { index, key in
            item(key.0, x[index % 3], y[index / 3], width, height, key.1)
        }
    }

    private static let edgePortrait = ManicSkinLayout(
        designSize: CGSize(width: 375, height: 812),
        background: "iphone_edgetoedge_portrait.pdf",
        screen: CGRect(x: 68, y: 80, width: 240, height: 320),
        dpad: CGRect(x: 122, y: 434, width: 130, height: 130),
        buttons: [
            item("fire_button.pdf", 273, 517, 56, 22, .fire),
            item("menu_button.pdf", 46, 517, 56, 22, .menu),
            item("softkeyLeft_button.pdf", 46, 453, 56, 22, .softkeyLeft),
            item("softkeyRight_button.pdf", 273, 453, 56, 22, .softkeyRight)
        ] + keypad(x: [41, 140, 239], y: [604, 651, 698, 745], width: 96, height: 44)
    )

    private static let edgeLandscape = ManicSkinLayout(
        designSize: CGSize(width: 812, height: 375),
        background: "iphone_edgetoedge_landscape.pdf",
        screen: CGRect(x: 246, y: 67, width: 320, height: 240),
        dpad: CGRect(x: 65, y: 170, width: 130, height: 130),
        buttons: [
            item("fire_button.pdf", 654, 90, 56, 22, .fire),
            item("menu_button.pdf", 102, 90, 56, 22, .menu),
            item("softkeyLeft_button.pdf", 177, 326, 56, 22, .softkeyLeft),
            item("softkeyRight_button.pdf", 579, 326, 56, 22, .softkeyRight)
        ] + keypad(x: [573, 639, 705], y: [172, 204, 236, 268], width: 64, height: 30)
    )

    private static let standardPortrait = ManicSkinLayout(
        designSize: CGSize(width: 375, height: 667),
        background: "iphone_standard_portrait.pdf",
        screen: CGRect(x: 68, y: 42, width: 240, height: 320),
        dpad: CGRect(x: 134.5, y: 403.5, width: 105, height: 105),
        buttons: [
            item("fire_button.pdf", 273, 474, 56, 22, .fire),
            item("menu_button.pdf", 46, 474, 56, 22, .menu),
            item("softkeyLeft_button.pdf", 46, 410, 56, 22, .softkeyLeft),
            item("softkeyRight_button.pdf", 273, 410, 56, 22, .softkeyRight)
        ] + keypad(x: [89, 155, 221], y: [526, 558, 590, 622], width: 64, height: 30)
    )

    private static let standardLandscape = ManicSkinLayout(
        designSize: CGSize(width: 667, height: 375),
        background: "iphone_standard_landscape.pdf",
        screen: CGRect(x: 173, y: 67, width: 320, height: 240),
        dpad: CGRect(x: 27.5, y: 192.5, width: 105, height: 105),
        buttons: [
            item("fire_button.pdf", 555, 90, 56, 22, .fire),
            item("menu_button.pdf", 56, 90, 56, 22, .menu),
            item("softkeyLeft_button.pdf", 104, 326, 56, 22, .softkeyLeft),
            item("softkeyRight_button.pdf", 506, 326, 56, 22, .softkeyRight)
        ] + keypad(x: [498, 551, 604], y: [196, 221, 246, 271], width: 52, height: 24)
    )
}
