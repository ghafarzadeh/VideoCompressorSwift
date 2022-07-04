import Foundation
import AVFoundation

public struct VideoCompressorSwift {
    
    public enum VideoCompressorError: Error, LocalizedError {
        case emptyTracks
        case fileAlreadyExist
        case failed
    }
    
    public enum VideoQuality: Equatable {
        case `default`
        case veryLow
        case low
        case medium
        case high
        case veryHigh
    }
    
    private let videoCompressQueue = DispatchQueue.init(label: "com.video.compress_queue")
    
    public init() {
    }
    
    private func getBitrate(bitrate: Float, quality: VideoQuality) -> Int {
        
        if quality == .veryLow {
            return Int(bitrate * 0.08)
        } else if quality == .low {
            return Int(bitrate * 0.1)
        } else if quality == .medium {
            return Int(bitrate * 0.2)
        } else if quality == .high {
            return Int(bitrate * 0.3)
        } else if quality == .veryHigh {
            return Int(bitrate * 0.5)
        } else {
            return Int(bitrate * 0.2)
        }
    }
    
    public func createVideoSettingsForPreset(_ preset: VideoQuality, _ bitrate: Float, size: CGSize) -> [String: Any] {
        let codecSettings = [AVVideoAverageBitRateKey: getBitrate(bitrate: bitrate, quality: preset) * 1000]
        return [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoScalingModeKey: AVVideoScalingModeResizeAspectFill,
            AVVideoCompressionPropertiesKey: codecSettings,
            AVVideoWidthKey: size.width,
            AVVideoHeightKey: size.height
        ]
    }
    
    public func videoCompress(inputUrl: URL,
                              outputFileType: AVFileType,
                              videoSettings: [String: Any],
                              audioSampleRate: Int,
                              audioBitrate: Int,
                              completion: @escaping (Result<URL, Error>) -> Void) {
        let asset = AVAsset(url: inputUrl)
        guard let videoTracks = asset.tracks(withMediaType: .video).first else {
            completion(.failure(VideoCompressorError.emptyTracks))
            return
        }
        
        let audioSettings: [String: Any] = createAudioSettingsWithAudioTrack(Float(audioBitrate), sampleRate: audioSampleRate)
        
        var audioTracks: AVAssetTrack?
        if let adTrack = asset.tracks(withMediaType: .audio).first {
            audioTracks = adTrack
        }
        
        compress(with: asset, outputFileType, videoTracks, videoSettings, audioTracks, audioSettings, completion: completion)
    }
    
    public func videoCompress(inputUrl: URL,
                              quality: VideoQuality = .medium,
                              completion: @escaping (Result<URL, Error>) -> Void) {
        let asset = AVAsset(url: inputUrl)

        guard let videoTracks = asset.tracks(withMediaType: .video).first else {
            completion(.failure(VideoCompressorError.emptyTracks))
            return
        }
        
        var audioTracks: AVAssetTrack?
        if let adTrack = asset.tracks(withMediaType: .audio).first {
            audioTracks = adTrack
        }
        
        let audioSettings = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: 2,
            AVSampleRateKey: 44100,
            AVEncoderBitRateKey: 128000
        ]
        
        let videoSettings = createVideoSettingsForPreset(quality, videoBitrateKbpsForPreset(quality), size: videoSize(asset: asset))
        
        compress(with: asset, .mp4, videoTracks, videoSettings, audioTracks, audioSettings, completion: completion)
    }
    
    
    private func videoBitrateKbpsForPreset(_ preset: VideoQuality) -> Float {
        switch preset {
        case .veryLow:
            return 400
        case .low:
            return 700
        case .medium:
            return 1100
        case .high:
            return 2500
        case .veryHigh:
            return 4000
        default:
            return 700
        }
    }
    
    private func videoSize(asset: AVAsset) -> CGSize {
        let videoTrack = asset.tracks(withMediaType: AVMediaType.video).first!
        return CGSize(width: Int(videoTrack.naturalSize.width), height: Int(videoTrack.naturalSize.height))
    }
    
    private func compress(with asset: AVAsset,
                          _ outputFileType: AVFileType,
                          _ videoTrack: AVAssetTrack,
                          _ videoSettings: [String: Any],
                          _ audioTrack: AVAssetTrack?,
                          _ audioSettings: [String: Any],
                          _ videoComposition: AVVideoComposition? = nil,
                          _ audioMix: AVAudioMix? = nil,
                          completion: @escaping (Result<URL, Error>) -> Void) {
        
        do {
            var outputURL = try FileManager.tempDirectory(with: "CompressedVideo")
            let videoName = UUID().uuidString + ".\(outputFileType.fileExtension)"
            outputURL.appendPathComponent("\(videoName)")
            
            
            let timeRange = CMTimeRangeMake(start: CMTime.zero, duration: CMTime.positiveInfinity)
            let reader: AVAssetReader
            do {
                reader = try AVAssetReader(asset: asset)
            } catch let error {
                completion(.failure(error))
                return
            }
            
            let writer: AVAssetWriter
            writer = try AVAssetWriter(outputURL: outputURL, fileType: outputFileType)
            
            reader.timeRange = timeRange
            writer.shouldOptimizeForNetworkUse = true
            
            let videoOutput = AVAssetReaderTrackOutput.init(track: videoTrack,
                                                            outputSettings: [kCVPixelBufferPixelFormatTypeKey as String:
                                                                                kCVPixelFormatType_32BGRA])
            
            if reader.canAdd(videoOutput) {
                reader.add(videoOutput)
                videoOutput.alwaysCopiesSampleData = false
            }
            
            let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            videoInput.expectsMediaDataInRealTime = false
            videoInput.transform = videoTrack.preferredTransform // fix output video orientation
            
            if writer.canAdd(videoInput) {
                writer.add(videoInput)
            }
            
            
            var audioOutput: AVAssetReaderTrackOutput? = nil
            var audioInput: AVAssetWriterInput? = nil
            
            if let audioTrack = audioTrack {
                audioOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM,
                                                                                   AVNumberOfChannelsKey: 2])
                audioOutput?.alwaysCopiesSampleData = false
                
                if reader.canAdd(audioOutput!) {
                    reader.add(audioOutput!)
                }
                
                audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
                audioInput?.expectsMediaDataInRealTime = false
                
                if writer.canAdd(audioInput!) {
                    writer.add(audioInput!)
                }
            }
            
            writer.startWriting()
            reader.startReading()
            writer.startSession(atSourceTime: timeRange.start)
            
            let group = DispatchGroup()
            
            group.enter()
            videoInput.requestMediaDataWhenReady(on: videoCompressQueue) {
                if !encodeReadySamplesFromOutput(videoOutput, input: videoInput, reader: reader, writer: writer)
                {
                    group.leave()
                }
            }
            
            if let audioOutput = audioOutput, let audioInput = audioInput {
                group.enter()
                audioInput.requestMediaDataWhenReady(on: videoCompressQueue, using: {
                    if !encodeReadySamplesFromOutput(audioOutput, input: audioInput, reader: reader, writer: writer) {
                        group.leave()
                    }
                })
            }
            
            group.notify(queue: .main) {
                guard writer.status != .cancelled else {
                    try? FileManager.default.removeItem(at: outputURL)
                    return
                }
                
                if writer.status == .failed {
                    writer.cancelWriting()
                    try? FileManager.default.removeItem(at: outputURL)
                    completion(.failure(VideoCompressorError.failed))
                } else {
                    writer.finishWriting {
                        print("compressed video size: \(outputURL.sizePerMB())M")
                        DispatchQueue.main.sync {
                            completion(.success(outputURL))
                        }
                    }
                }
            }
        } catch let error {
            completion(.failure(error))
            return
        }
    }
    
    private func outputVideoData(_ videoInput: AVAssetWriterInput,
                                 videoOutput: AVAssetReaderTrackOutput,
                                 reader: AVAssetReader,
                                 writer: AVAssetWriter) async {
        
    }
    
    private func encodeReadySamplesFromOutput(
        _ output: AVAssetReaderOutput,
        input: AVAssetWriterInput,
        reader: AVAssetReader,
        writer: AVAssetWriter
    ) -> Bool {
        while input.isReadyForMoreMediaData {
            if let sampleBuffer = output.copyNextSampleBuffer() {
                if reader.status != .reading || writer.status != .writing {
                    return false
                }
                
                if !input.append(sampleBuffer) {
                    return false
                }
                
            } else {
                input.markAsFinished()
                return false
            }
        }
        return true
    }
    
    private func createAudioSettingsWithAudioTrack(_ bitrate: Float, sampleRate: Int) -> [String: Any] {
        var audioChannelLayout = AudioChannelLayout()
        memset(&audioChannelLayout, 0, MemoryLayout<AudioChannelLayout>.size)
        audioChannelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo
        
        return [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVEncoderBitRateKey: bitrate,
            AVNumberOfChannelsKey: 2,
            AVChannelLayoutKey: Data(bytes: &audioChannelLayout, count: MemoryLayout<AudioChannelLayout>.size)
        ]
    }
    
}
