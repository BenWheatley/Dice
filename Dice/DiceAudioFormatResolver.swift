import AVFoundation

enum DiceAudioFormatResolver {
	static func playbackFormat(playerOutput: AVAudioFormat?, mixerOutput: AVAudioFormat) -> AVAudioFormat? {
		let sourceFormat: AVAudioFormat
		if let playerOutput, playerOutput.channelCount > 0, playerOutput.sampleRate > 0 {
			sourceFormat = playerOutput
		} else {
			sourceFormat = mixerOutput
		}

		let sampleRate = sourceFormat.sampleRate > 0 ? sourceFormat.sampleRate : 44_100
		let channels = max(AVAudioChannelCount(1), sourceFormat.channelCount)
		return AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels)
	}
}
