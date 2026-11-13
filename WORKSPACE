workspace(name = "WhiteGram")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

# Rules Apple
http_archive(
    name = "build_bazel_rules_apple",
    sha256 = "6ca24e6ff6c1bc33b28b74a16ca315c27f3aa415f3debe88481ff23b3eb7ef43",
    url = "https://github.com/bazelbuild/rules_apple/releases/download/3.5.1/rules_apple.3.5.1.tar.gz",
)

load(
    "@build_bazel_rules_apple//apple:repositories.bzl",
    "apple_rules_dependencies",
)

apple_rules_dependencies()

load(
    "@build_bazel_rules_apple//apple:apple.bzl",
    "apple_rules_dependencies",
)

# Rules Swift
http_archive(
    name = "build_bazel_rules_swift",
    sha256 = "65a0baf90d794e772f9b884c7185012e1ec7378772dd962b146eef24ebc1ce85",
    url = "https://github.com/bazelbuild/rules_swift/releases/download/1.18.0/rules_swift.1.18.0.tar.gz",
)

load(
    "@build_bazel_rules_swift//swift:repositories.bzl",
    "swift_rules_dependencies",
)

swift_rules_dependencies()

load(
    "@build_bazel_rules_swift//swift:setup.bzl",
    "swift_rules_setup",
)

swift_rules_setup()
