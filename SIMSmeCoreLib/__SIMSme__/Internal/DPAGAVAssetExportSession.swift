//
//  DPAGAVAssetExportSession.swift
//  SIMSme
//
//  Created by RBU on 05/04/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//
// Originally based on: rs/SDAVAssetExportSession (https://github.com/rs/SDAVAssetExportSession)
// Copyright (c) 2013 Olivier Poitrey <rs@dailymotion.com>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of
// this software and associated documentation files (the "Software"), to deal in
// the Software without restriction, including without limitation the rights to
// use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
// the Software, and to permit persons to whom the Software is furnished to do so,
// subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

import AVFoundation
import UIKit

public enum DPAGAssetExportSessionStatus: Int {
    case unknown,
        waiting,
        exporting,
        completed,
        failed,
        cancelled
}

public class DPAGAVAssetExportSession: NSObject {
    let asset: AVAsset

    public var videoComposition: AVVideoComposition?
    public var audioMix: AVAudioMix?

    public var outputFileType: AVFileType = .mp4
    public var outputURL: URL?

    public var videoInputSettings: [String: Any]?
    public var videoSettings: [String: Any] = [:]

    public var audioSettings: [String: Any] = [:]

    fileprivate var timeRange: CMTimeRange

    public var shouldOptimizeForNetworkUse = false

    public var metadata: [AVMetadataItem] = []

    fileprivate var status: AVAssetExportSession.Status = .unknown

    fileprivate var progress: CGFloat = 0

    fileprivate var reader: AVAssetReader?
    fileprivate var videoOutput: AVAssetReaderVideoCompositionOutput?
    fileprivate var audioOutput: AVAssetReaderAudioMixOutput?

    fileprivate var writer: AVAssetWriter?
    fileprivate var videoInput: AVAssetWriterInput?
    fileprivate var videoPixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    fileprivate var audioInput: AVAssetWriterInput?

    fileprivate var inputQueue: DispatchQueue?
    fileprivate var completionHandler: DPAGCompletion?

    fileprivate var error: NSError?
    fileprivate var duration: TimeInterval = 0
    fileprivate var lastSamplePresentationTime: CMTime = CMTime.zero

    public init(asset: AVAsset) {
        self.asset = asset
        self.timeRange = CMTimeRangeMake(start: CMTime.zero, duration: CMTime.positiveInfinity)

        super.init()
    }

    public func exportAsynchronouslyWithCompletionHandler(_ handler: @escaping DPAGCompletion) {
        self.cancelExport()

        self.completionHandler = handler

        guard let outputURL = self.outputURL else {
            self.error = NSError(domain: AVFoundationErrorDomain, code: AVError.Code.exportFailed.rawValue, userInfo: [NSLocalizedDescriptionKey: "Output URL not set"])
            handler()
            return
        }

        do {
            self.reader = try AVAssetReader(asset: self.asset)
        } catch let readerError as NSError {
            self.error = readerError
            handler()
            return
        }

        do {
            self.writer = try AVAssetWriter(outputURL: outputURL, fileType: self.outputFileType)
        } catch let writerError as NSError {
            self.error = writerError
            handler()
            return
        }

        self.reader?.timeRange = self.timeRange
        self.writer?.shouldOptimizeForNetworkUse = self.shouldOptimizeForNetworkUse
        self.writer?.metadata = self.metadata

        let videoTracks = self.asset.tracks(withMediaType: AVMediaType.video)

        if self.timeRange.duration.flags.contains(CMTimeFlags.valid), !self.timeRange.duration.flags.contains(CMTimeFlags.positiveInfinity) {
            self.duration = CMTimeGetSeconds(self.timeRange.duration)
        } else {
            self.duration = CMTimeGetSeconds(self.asset.duration)
        }

        //
        // Video output
        //
        if videoTracks.count > 0 {
            let videoOutput = AVAssetReaderVideoCompositionOutput(videoTracks: videoTracks, videoSettings: self.videoInputSettings)
            // IMDAT
            videoOutput.alwaysCopiesSampleData = false

            if self.videoComposition != nil {
                videoOutput.videoComposition = self.videoComposition
            } else {
                videoOutput.videoComposition = self.buildDefaultVideoComposition()
            }
            if self.reader?.canAdd(videoOutput) ?? false {
                self.reader?.add(videoOutput)
            }

            self.videoOutput = videoOutput

            //
            // Video input
            //
            let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: self.videoSettings)

            videoInput.expectsMediaDataInRealTime = false

            if self.writer?.canAdd(videoInput) ?? false {
                self.writer?.add(videoInput)
            }

            self.videoInput = videoInput

            if let videoComposition = videoOutput.videoComposition {
                let pixelBufferAttributes: [String: Any] = [
                    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8Planar),
                    kCVPixelBufferWidthKey as String: videoComposition.renderSize.width,
                    kCVPixelBufferHeightKey as String: videoComposition.renderSize.height,
                    "IOSurfaceOpenGLESTextureCompatibility": kCFBooleanTrue as Any,
                    "IOSurfaceOpenGLESFBOCompatibility": kCFBooleanTrue as Any
                ]
                self.videoPixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput, sourcePixelBufferAttributes: pixelBufferAttributes)
            }
        }

        //
        // Audio output
        //
        let audioTracks = self.asset.tracks(withMediaType: AVMediaType.audio)

        if audioTracks.count > 0 {
            let audioOutput = AVAssetReaderAudioMixOutput(audioTracks: audioTracks, audioSettings: nil)

            audioOutput.alwaysCopiesSampleData = false
            audioOutput.audioMix = self.audioMix

            if self.reader?.canAdd(audioOutput) ?? false {
                self.reader?.add(audioOutput)
            }
            self.audioOutput = audioOutput
        } else {
            // Just in case this gets reused
            self.audioOutput = nil
        }

        //
        // Audio input
        //
        if self.audioOutput != nil {
            let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: self.audioSettings)

            audioInput.expectsMediaDataInRealTime = false

            if self.writer?.canAdd(audioInput) ?? false {
                self.writer?.add(audioInput)
            }
            self.audioInput = audioInput
        }

        self.writer?.startWriting()
        self.reader?.startReading()
        self.writer?.startSession(atSourceTime: self.timeRange.start)

        var videoCompleted = false
        var audioCompleted = false

        self.inputQueue = DispatchQueue(label: "VideoEncoderInputQueue", attributes: [])

        if videoTracks.count > 0, let inputQueue = self.inputQueue {
            self.videoInput?.requestMediaDataWhenReady(on: inputQueue) { [weak self] in

                if let strongSelf = self, let videoOutput = strongSelf.videoOutput, let videoInput = strongSelf.videoInput {
                    if strongSelf.encodeReadySamplesFromOutput(videoOutput, toInput: videoInput) == false {
                        DPAGFunctionsGlobal.synchronized(strongSelf) {
                            videoCompleted = true

                            if audioCompleted {
                                strongSelf.finish()
                            }
                        }
                    }
                }
            }
        } else {
            videoCompleted = true
        }

        if self.audioOutput != nil, let inputQueue = self.inputQueue {
            self.audioInput?.requestMediaDataWhenReady(on: inputQueue) { [weak self] in

                if let strongSelf = self, let audioOutput = strongSelf.audioOutput, let audioInput = strongSelf.audioInput {
                    if strongSelf.encodeReadySamplesFromOutput(audioOutput, toInput: audioInput) == false {
                        DPAGFunctionsGlobal.synchronized(strongSelf) {
                            audioCompleted = true

                            if videoCompleted {
                                strongSelf.finish()
                            }
                        }
                    }
                }
            }
        } else {
            audioCompleted = true
        }
    }

    func encodeReadySamplesFromOutput(_ output: AVAssetReaderOutput, toInput input: AVAssetWriterInput) -> Bool {
        while input.isReadyForMoreMediaData {
            if let sampleBuffer = output.copyNextSampleBuffer() {
                var handled = false
                var error = false

                if (self.reader?.status ?? AVAssetReader.Status.unknown) != AVAssetReader.Status.reading || (self.writer?.status ?? AVAssetWriter.Status.unknown) != AVAssetWriter.Status.writing {
                    handled = true
                    error = true
                }

                if !handled, self.videoOutput == output {
                    // update the video progress
                    lastSamplePresentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                    lastSamplePresentationTime = CMTimeSubtract(lastSamplePresentationTime, self.timeRange.start)
                }
                if handled == false, input.append(sampleBuffer) == false {
                    error = true
                }

                if error {
                    return false
                }
            } else {
                input.markAsFinished()
                return false
            }
        }

        return true
    }

    func buildDefaultVideoComposition() -> AVMutableVideoComposition {
        let videoComposition = AVMutableVideoComposition()

        guard let videoTrack = self.asset.tracks(withMediaType: AVMediaType.video).first else {
            return videoComposition
        }

        DPAGLog("video info export: fps = \(videoTrack.nominalFrameRate), size = %@, bps = \(videoTrack.estimatedDataRate)", NSCoder.string(for: videoTrack.naturalSize))

        // get the frame rate from videoSettings, if not set then try to get it from the video track,
        // if not set (mainly when asset is AVComposition) then use the default frame rate of 30
        var trackFrameRate = videoTrack.nominalFrameRate

        if let videoCompressionProperties = self.videoSettings[AVVideoCompressionPropertiesKey] as? [String: Any], let maxKeyFrameInterval = videoCompressionProperties[AVVideoMaxKeyFrameIntervalKey] as? NSNumber {
            trackFrameRate = maxKeyFrameInterval.floatValue
        }

        if trackFrameRate == 0 {
            trackFrameRate = 30
        }

        videoComposition.frameDuration = CMTimeMake(value: 1, timescale: Int32(trackFrameRate))

        let videoWidth = self.videoSettings[AVVideoWidthKey] as? CGFloat ?? 0
        let videoHeight = self.videoSettings[AVVideoHeightKey] as? CGFloat ?? 0

        let targetSize = CGSize(width: videoWidth, height: videoHeight)

        var naturalSize = videoTrack.naturalSize

        if naturalSize.width > targetSize.width || naturalSize.height > targetSize.height {
            var transform = videoTrack.preferredTransform
            // Adding new: IMDAT
            // fix for: https://github.com/ginlonet/ginlo-client-ios/issues/67
            let rect = CGRect(x: 0, y: 0, width: naturalSize.width, height: naturalSize.height)
            let transformedRect = rect.applying(transform)
            // transformedRect should have origin at 0 if correct; otherwise add offset to correct it
            transform.tx -= transformedRect.origin.x
            transform.ty -= transformedRect.origin.y
            // END ADDING FIX

            let videoAngleInDegree = abs(round(Double(atan2(transform.b, transform.a) * 180) / .pi))

            if videoAngleInDegree == 90 {
                let width = naturalSize.width
                naturalSize.width = naturalSize.height
                naturalSize.height = width
            }

            videoComposition.renderSize = naturalSize

            // center inside

            let xratio = targetSize.width / naturalSize.width
            let yratio = targetSize.height / naturalSize.height
            let ratio = min(xratio, yratio)

            let postWidth = naturalSize.width * ratio
            let postHeight = naturalSize.height * ratio
            let transx = (targetSize.width - postWidth) / 2
            let transy = (targetSize.height - postHeight) / 2

            var matrix = CGAffineTransform(translationX: transx / xratio, y: transy / yratio)
          
            matrix = matrix.scaledBy(x: ratio / xratio, y: ratio / yratio)

            transform = transform.concatenating(matrix)

            // Make a "pass through video track" video composition.

            let passThroughInstruction = AVMutableVideoCompositionInstruction()

            passThroughInstruction.timeRange = CMTimeRangeMake(start: CMTime.zero, duration: self.asset.duration)

            let passThroughLayer = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)

            passThroughLayer.setTransform(transform, at: CMTime.zero)

            passThroughInstruction.layerInstructions = [passThroughLayer]
            videoComposition.instructions = [passThroughInstruction]
        } else {
            videoComposition.renderSize = naturalSize

            let passThroughInstruction = AVMutableVideoCompositionInstruction()

            passThroughInstruction.timeRange = CMTimeRangeMake(start: CMTime.zero, duration: self.asset.duration)

            let passThroughLayer = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)

            passThroughInstruction.layerInstructions = [passThroughLayer]
            videoComposition.instructions = [passThroughInstruction]
        }

        return videoComposition
    }

    func finish() {
        // Synchronized block to ensure we never cancel the writer before calling finishWritingWithCompletionHandler
        if (self.reader?.status ?? AVAssetReader.Status.unknown) == AVAssetReader.Status.cancelled || (self.writer?.status ?? AVAssetWriter.Status.unknown) == AVAssetWriter.Status.cancelled {
            return
        }

        if (self.writer?.status ?? AVAssetWriter.Status.unknown) == AVAssetWriter.Status.failed {
            self.complete()
        } else if (self.reader?.status ?? AVAssetReader.Status.unknown) == AVAssetReader.Status.failed {
            self.writer?.cancelWriting()
            self.complete()
        } else {
            self.writer?.finishWriting(
                completionHandler: { [weak self] in
                    self?.complete()
                }
            )
        }
    }

    func complete() {
        if let outputURL = self.outputURL {
            let writerStatus = self.writer?.status ?? .cancelled

            if writerStatus == .failed || writerStatus == .cancelled {
                do {
                    try FileManager.default.removeItem(at: outputURL)
                } catch {
                    DPAGLog(error)
                }
            }
        }

        self.completionHandler?()
    }

    public func sessionError() -> Error? {
        (self.error ?? self.writer?.error) ?? self.reader?.error
    }

    public func sessionStatus() -> DPAGAssetExportSessionStatus {
        if let status = self.writer?.status {
            switch status {
            case AVAssetWriter.Status.unknown:
                return .unknown
            case AVAssetWriter.Status.writing:
                return .exporting
            case AVAssetWriter.Status.failed:
                return .failed
            case AVAssetWriter.Status.completed:
                return .completed
            case AVAssetWriter.Status.cancelled:
                return .cancelled
            @unknown default:
                DPAGLog("Switch with unknown value: \(status.rawValue)", level: .warning)
            }
        }

        return .unknown
    }

    public func cancelExport() {
        if let inputQueue = self.inputQueue {
            inputQueue.async {
                self.writer?.cancelWriting()
                self.reader?.cancelReading()
                self.complete()
                self.reset()
            }
        }
    }

    func reset() {
        self.error = nil
        self.progress = 0
        self.reader = nil
        self.videoOutput = nil
        self.audioOutput = nil
        self.writer = nil
        self.videoInput = nil
        self.videoPixelBufferAdaptor = nil
        self.audioInput = nil
        self.inputQueue = nil
        self.completionHandler = nil
    }
}
