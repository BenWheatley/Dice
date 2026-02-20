import UIKit
import MetalKit

final class DiceShaderBackgroundView: UIView {
	private let metalView: MTKView?
	private let fallbackView = UIImageView()
	private let renderer: DiceMetalTextureRenderer?
	private var currentTexture: DiceTableTexture

	init(texture: DiceTableTexture) {
		self.currentTexture = texture

		if let device = MTLCreateSystemDefaultDevice(),
		   let renderer = DiceMetalTextureRenderer(device: device, texture: texture) {
			let metalView = MTKView(frame: .zero, device: device)
			metalView.translatesAutoresizingMaskIntoConstraints = false
			metalView.isPaused = true
			metalView.enableSetNeedsDisplay = true
			metalView.framebufferOnly = true
			metalView.colorPixelFormat = .bgra8Unorm
			metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
			metalView.delegate = renderer
			self.metalView = metalView
			self.renderer = renderer
		} else {
			self.metalView = nil
			self.renderer = nil
		}

		super.init(frame: .zero)
		clipsToBounds = true

		if let metalView {
			addSubview(metalView)
			NSLayoutConstraint.activate([
				metalView.topAnchor.constraint(equalTo: topAnchor),
				metalView.leadingAnchor.constraint(equalTo: leadingAnchor),
				metalView.trailingAnchor.constraint(equalTo: trailingAnchor),
				metalView.bottomAnchor.constraint(equalTo: bottomAnchor),
			])
		} else {
			fallbackView.translatesAutoresizingMaskIntoConstraints = false
			fallbackView.contentMode = .scaleToFill
			fallbackView.clipsToBounds = true
			addSubview(fallbackView)
			NSLayoutConstraint.activate([
				fallbackView.topAnchor.constraint(equalTo: topAnchor),
				fallbackView.leadingAnchor.constraint(equalTo: leadingAnchor),
				fallbackView.trailingAnchor.constraint(equalTo: trailingAnchor),
				fallbackView.bottomAnchor.constraint(equalTo: bottomAnchor),
			])
		}
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func setTexture(_ texture: DiceTableTexture) {
		currentTexture = texture
		renderer?.setTexture(texture)
	}

	func refreshBackground(size: CGSize) {
		guard size.width > 1, size.height > 1 else { return }
		if let metalView {
			metalView.drawableSize = size
			metalView.setNeedsDisplay()
		} else {
			fallbackView.image = DiceTextureProvider.shared.backgroundImage(for: currentTexture, size: size)
		}
	}
}
