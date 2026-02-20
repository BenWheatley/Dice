import Foundation
import AVFoundation

final class DiceSoundEngine {
	private let engine = AVAudioEngine()
	private let player = AVAudioPlayerNode()
	private let audioQueue = DispatchQueue(label: "com.kitsunesoftware.dice.soundengine")
	private var currentPack: DiceSoundPack = .off
	private var isEnabled = true
	private var didStartEngine = false

	init() {
		engine.attach(player)
		engine.connect(player, to: engine.mainMixerNode, format: initialPlaybackFormat())
	}

	func configure(pack: DiceSoundPack, enabled: Bool) {
		audioQueue.async { [weak self] in
			self?.currentPack = pack
			self?.isEnabled = enabled
		}
	}

	func playRollImpact() {
		audioQueue.async { [weak self] in
			guard let self else { return }
			guard self.isEnabled else { return }
			guard self.currentPack != .off else { return }
			self.ensureEngineStarted()
			guard let baseBuffer = self.impactBuffer(for: self.currentPack),
				  let buffer = self.copyBuffer(baseBuffer) else { return }
			self.player.volume = 1.0
			self.player.scheduleBuffer(buffer, at: nil, options: []) { }
			if !self.player.isPlaying {
				self.player.play()
			}
		}
	}

	func playSettleTick() {
		audioQueue.async { [weak self] in
			guard let self else { return }
			guard self.isEnabled else { return }
			guard self.currentPack != .off else { return }
			self.ensureEngineStarted()
			guard let baseBuffer = self.tickBuffer(for: self.currentPack),
				  let buffer = self.copyBuffer(baseBuffer) else { return }
			self.player.volume = 0.9
			self.player.scheduleBuffer(buffer, at: nil, options: []) { }
			if !self.player.isPlaying {
				self.player.play()
			}
		}
	}

	private func ensureEngineStarted() {
		guard !didStartEngine else { return }
		do {
			try engine.start()
			didStartEngine = true
		} catch {
			didStartEngine = false
		}
	}

	private func impactBuffer(for pack: DiceSoundPack) -> AVAudioPCMBuffer? {
		guard let format = playbackFormat() else {
			return nil
		}
		let frameCount: AVAudioFrameCount = 7_000
		guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
			return nil
		}
		buffer.frameLength = frameCount
		guard let channels = buffer.floatChannelData else {
			return nil
		}
		for channelIndex in 0..<Int(format.channelCount) {
			fill(
				channel: channels[channelIndex],
				count: Int(frameCount),
				sampleRate: Float(format.sampleRate),
				pack: pack
			)
		}
		return buffer
	}

	private func tickBuffer(for pack: DiceSoundPack) -> AVAudioPCMBuffer? {
		guard let format = playbackFormat() else {
			return nil
		}
		let frameCount: AVAudioFrameCount = 1_800
		guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
			return nil
		}
		buffer.frameLength = frameCount
		guard let channels = buffer.floatChannelData else {
			return nil
		}
		for channelIndex in 0..<Int(format.channelCount) {
			fillTick(
				channel: channels[channelIndex],
				count: Int(frameCount),
				sampleRate: Float(format.sampleRate),
				pack: pack
			)
		}
		return buffer
	}

	private func playbackFormat() -> AVAudioFormat? {
		let playerFormat = player.outputFormat(forBus: 0)
		let mixerFormat = engine.mainMixerNode.outputFormat(forBus: 0)
		return DiceAudioFormatResolver.playbackFormat(playerOutput: playerFormat, mixerOutput: mixerFormat)
	}

	private func initialPlaybackFormat() -> AVAudioFormat {
		let mixerFormat = engine.mainMixerNode.outputFormat(forBus: 0)
		return DiceAudioFormatResolver.playbackFormat(playerOutput: nil, mixerOutput: mixerFormat)
			?? AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
	}

	private func fill(channel: UnsafeMutablePointer<Float>, count: Int, sampleRate: Float, pack: DiceSoundPack) {
		let twoPi = Float.pi * 2
		var lpState: Float = 0
		for index in 0..<count {
			let t = Float(index) / sampleRate
			let envelope = exp(-12 * t)
			let noise = Float.random(in: -1...1)
			let x: Float
			switch pack {
			case .off:
				x = 0
			case .softWood:
				let tone = sin(twoPi * 230 * t)
				let mixed = (0.6 * noise) + (0.4 * tone)
				lpState += 0.08 * (mixed - lpState)
				x = lpState * envelope * 0.65
			case .hardTable:
				let tone = sin(twoPi * 1_350 * t)
				let mixed = (0.82 * noise) + (0.18 * tone)
				lpState += 0.03 * (mixed - lpState)
				let hp = mixed - lpState
				x = hp * envelope * 0.9
			}
			channel[index] = max(-1, min(1, x))
		}
	}

	private func fillTick(channel: UnsafeMutablePointer<Float>, count: Int, sampleRate: Float, pack: DiceSoundPack) {
		let twoPi = Float.pi * 2
		for index in 0..<count {
			let t = Float(index) / sampleRate
			let envelope = exp(-34 * t)
			let noise = Float.random(in: -1...1)
			let toneFrequency: Float = pack == .softWood ? 1_280 : 1_880
			let tone = sin(twoPi * toneFrequency * t)
			let mix: Float = pack == .softWood ? ((0.6 * noise) + (0.4 * tone)) : ((0.82 * noise) + (0.18 * tone))
			channel[index] = max(-1, min(1, mix * envelope * 0.75))
		}
	}

	private func copyBuffer(_ source: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
		guard let copy = AVAudioPCMBuffer(pcmFormat: source.format, frameCapacity: source.frameLength) else {
			return nil
		}
		copy.frameLength = source.frameLength
		guard let fromChannels = source.floatChannelData, let toChannels = copy.floatChannelData else {
			return nil
		}
		let channels = Int(source.format.channelCount)
		let frames = Int(source.frameLength)
		for channel in 0..<channels {
			toChannels[channel].assign(from: fromChannels[channel], count: frames)
		}
		return copy
	}
}
