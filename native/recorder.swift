import Foundation
import AVFoundation
import AppKit

// Private game-frame protocol: jpeg bytes, PCM float stereo bytes, video seconds,
// audio sample offset, then payloads. No desktop or microphone access is used.
struct RecordingError: Error, CustomStringConvertible {
    let description: String
    init(_ message: String) { description = message }
}
func readExactly(_ count: Int) throws -> Data {
    var data = Data()
    while data.count < count {
        let part = FileHandle.standardInput.readData(ofLength: count - data.count)
        if part.isEmpty { throw RecordingError("Game stream closed before recording finished") }
        data.append(part)
    }
    return data
}
func reply(_ message: String) {
    FileHandle.standardOutput.write(Data((message + "\n").utf8))
}
func ready(_ input: AVAssetWriterInput, _ writer: AVAssetWriter) throws {
    let deadline = Date().addingTimeInterval(8)
    while !input.isReadyForMoreMediaData {
        if writer.status == .failed || Date() > deadline {
            throw RecordingError(writer.error?.localizedDescription ?? "Encoder timed out")
        }
        Thread.sleep(forTimeInterval: 0.002)
    }
}
func record() throws {
    let args = CommandLine.arguments
    guard args.count == 5, let width = Int(args[2]), let height = Int(args[3]),
          let rate = Double(args[4]), width > 0, width <= 1920,
          height > 0, height <= 1080, rate >= 8000, rate <= 192000 else {
        throw RecordingError("Invalid recorder dimensions or sample rate")
    }
    let destination = URL(fileURLWithPath: args[1])
    let partial = URL(fileURLWithPath: args[1] + ".partial.mp4")
    let writer = try AVAssetWriter(outputURL: partial, fileType: .mp4)
    let video = AVAssetWriterInput(mediaType: .video, outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: width, AVVideoHeightKey: height,
        AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 6_000_000,
            AVVideoExpectedSourceFrameRateKey: 30, AVVideoMaxKeyFrameIntervalKey: 60]
    ])
    video.expectsMediaDataInRealTime = true
    let pixels = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: video,
        sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true])
    let audio = AVAssetWriterInput(mediaType: .audio, outputSettings: [
        AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: rate,
        AVNumberOfChannelsKey: 2, AVEncoderBitRateKey: 128000])
    audio.expectsMediaDataInRealTime = true
    guard writer.canAdd(video), writer.canAdd(audio) else { throw RecordingError("Unsupported media settings") }
    writer.add(video)
    writer.add(audio)
    var asbd = AudioStreamBasicDescription(mSampleRate: rate, mFormatID: kAudioFormatLinearPCM,
        mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
        mBytesPerPacket: 8, mFramesPerPacket: 1, mBytesPerFrame: 8,
        mChannelsPerFrame: 2, mBitsPerChannel: 32, mReserved: 0)
    var audioFormat: CMAudioFormatDescription?
    guard CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault, asbd: &asbd,
        layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil,
        extensions: nil, formatDescriptionOut: &audioFormat) == noErr else {
        throw RecordingError("Could not create audio format")
    }
    guard writer.startWriting() else { throw RecordingError(writer.error?.localizedDescription ?? "Cannot create video") }
    writer.startSession(atSourceTime: .zero)
    reply("READY")
    var frames = 0
    while true {
        let header = try readExactly(24)
        let jpegCount = Int(header.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 0, as: UInt32.self).littleEndian })
        let audioCount = Int(header.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 4, as: UInt32.self).littleEndian })
        let seconds = header.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 8, as: Double.self) }
        let audioOffset = header.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 16, as: Int64.self).littleEndian }
        if jpegCount == 0 && audioCount == 0 { break }
        guard jpegCount > 0, jpegCount <= 8_000_000, audioCount <= 8_000_000,
              audioCount % 8 == 0, seconds.isFinite, seconds >= 0, audioOffset >= 0 else {
            throw RecordingError("Invalid game frame")
        }
        let jpeg = try readExactly(jpegCount)
        let sound = try readExactly(audioCount)
        try autoreleasepool {
            guard let image = NSBitmapImageRep(data: jpeg)?.cgImage, let pool = pixels.pixelBufferPool else {
                throw RecordingError("Invalid image frame")
            }
            var buffer: CVPixelBuffer?
            guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess,
                  let buffer = buffer else { throw RecordingError("Cannot allocate video buffer") }
            CVPixelBufferLockBaseAddress(buffer, [])
            defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
            guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: width,
                height: height, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else {
                throw RecordingError("Cannot create video drawing context")
            }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            try ready(video, writer)
            guard pixels.append(buffer, withPresentationTime: CMTime(seconds: seconds, preferredTimescale: 60000)) else {
                throw RecordingError(writer.error?.localizedDescription ?? "Cannot append video frame")
            }
            frames += 1
            if audioCount > 0 {
                var block: CMBlockBuffer?
                guard CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault,
                    memoryBlock: nil, blockLength: audioCount, blockAllocator: kCFAllocatorDefault,
                    customBlockSource: nil, offsetToData: 0, dataLength: audioCount, flags: 0,
                    blockBufferOut: &block) == noErr, let block = block else {
                    throw RecordingError("Cannot allocate audio buffer")
                }
                let copied = sound.withUnsafeBytes { bytes in
                    CMBlockBufferReplaceDataBytes(with: bytes.baseAddress!, blockBuffer: block,
                        offsetIntoDestination: 0, dataLength: audioCount)
                }
                guard copied == noErr else { throw RecordingError("Cannot copy audio samples") }
                var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: Int32(rate)),
                    presentationTimeStamp: CMTime(value: audioOffset, timescale: Int32(rate)), decodeTimeStamp: .invalid)
                var sample: CMSampleBuffer?
                var sampleSize = 8
                guard CMSampleBufferCreateReady(allocator: kCFAllocatorDefault, dataBuffer: block,
                    formatDescription: audioFormat, sampleCount: audioCount / 8,
                    sampleTimingEntryCount: 1, sampleTimingArray: &timing,
                    sampleSizeEntryCount: 1, sampleSizeArray: &sampleSize,
                    sampleBufferOut: &sample) == noErr, let sample = sample else {
                    throw RecordingError("Cannot create audio sample")
                }
                try ready(audio, writer)
                guard audio.append(sample) else { throw RecordingError(writer.error?.localizedDescription ?? "Cannot append audio") }
            }
        }
    }
    guard frames > 0 else { throw RecordingError("No game frames received") }
    video.markAsFinished()
    audio.markAsFinished()
    let completion = DispatchSemaphore(value: 0)
    writer.finishWriting { completion.signal() }
    guard completion.wait(timeout: .now() + 15) == .success, writer.status == .completed else {
        throw RecordingError(writer.error?.localizedDescription ?? "Could not finalize video")
    }
    try FileManager.default.moveItem(at: partial, to: destination)
    reply("SAVED")
}
do { try record() }
catch { reply("ERROR: \(error)"); exit(1) }
