import PackageDescription

let package = Package(
    name: "HTTPParser",
    targets: [
        Target(name: "bench", dependencies: [.Target(name: "HTTPParser")]),
        Target(name: "HTTPParser")
    ]
)
