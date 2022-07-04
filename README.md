# VideoCompressorSwift

A high-performance, flexible and easy to use Video compressor library written by Swift.

[![Version](https://img.shields.io/badge/language-swift%205-f48041.svg?style=flat)](https://developer.apple.com/swift) [![License](https://img.shields.io/badge/license-MIT-lightgrey.svg?style=flat)](https://github.com/T2Je/FYVideoCompressor) ![Platform](https://img.shields.io/cocoapods/p/FYVideoCompressor)

## Usage

### Compress with quality param

Set `VideoQuality` to get different quality of video, beside:

```swift
 VideoCompressorSwift().videoCompress(inputUrl: yourVideoPath, quality: .medium) { result in
            switch result {
            case .failure(let error):
            case .success(let url):
            }
        }
```

### Compress with more customized

```swift
VideoCompressorSwift().videoCompress(inputUrl: url,
                                     outputFileType: .mov,
                                     videoSettings: VideoCompressorSwift().createVideoSettingsForPreset(.medium, 1000_000, size: CGSize(width: 640, height: 480)),
                                     audioSampleRate: 44100,
                                     audioBitrate: 128_000) { res in
            switch result {
            case .failure(let error):
            case .success(let url):
            }
        }
```

## Installation

### Swift Package Manager

The [Swift Package Manager](https://swift.org/package-manager/) is a tool for automating the distribution of Swift code and is integrated into the `swift` compiler. 

Once you have your Swift package set up, adding VideoCompressorSwift as a dependency is as easy as adding it to the `dependencies` value of your `Package.swift`.

```swift
dependencies: [
    .package(url: "https://github.com/ghafarzadeh/VideoCompressorSwift.git", .upToNextMajor(from: "0.0.1"))
]
```
<!-- LICENSE -->
## License

Distributed under the MIT License. See <a href="https://github.com/ghafarzadeh/SpaceX/blob/main/LICENSE">LICENSE.txt</a> for more information.


<!-- CONTACT -->
## Contact

Habib Ghaffarzadeh - [LinkedIn](https://www.linkedin.com/in/habib-ghafarzadeh-b4303939/) - [Twitter](https://twitter.com/h_ghafarzadeh) - habib.ghafarzadeh@gmail.com
