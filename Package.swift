// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "mParticle-Button",
    platforms: [ .iOS(.v9) ],
    products: [
        .library(
            name: "mParticle-Button",
            targets: ["mParticle-Button"]),
    ],
    dependencies: [
      .package(name: "mParticle-Apple-SDK",
               url: "https://github.com/mParticle/mparticle-apple-sdk",
               .upToNextMajor(from: "8.2.0")),
      .package(name: "ButtonMerchant",
               url: "https://github.com/button/button-merchant-ios.git",
               .upToNextMajor(from: "1.0")),
    ],
    targets: [
        .target(
            name: "mParticle-Button",
            dependencies: ["mParticle-Apple-SDK","ButtonMerchant"],
            path: "mParticle-Button",
            publicHeadersPath: "."),
    ]
)
