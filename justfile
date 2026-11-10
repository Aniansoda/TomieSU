alias bk := build_tsud
alias bm := build_manager

build_tsud:
    cross build --target aarch64-linux-android --release

build_manager: build_tsud
    cp target/aarch64-linux-android/release/tsud manager/app/src/main/jniLibs/arm64-v8a/libtsud.so
    cd manager && ./gradlew aDebug

clippy:
    cargo fmt
    cross clippy --target aarch64-linux-android --release
