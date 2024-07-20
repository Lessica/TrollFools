# TrollFools

In-place tweak injection with insert_dylib and ChOma.  
Proudly written in SwiftUI.  

Expected to work on all iOS versions supported by opa334’s TrollStore.

## Build

PRs are always welcome.  
You have to get precompiled binaries from released packages or build them yourself.

## Milestones

- [ ] `optool` is buggy so we need to compile a statically linked `install_name_tool` or `llvm-install-name-tool` on iOS to achieve a smaller package size.
- [ ] Support for `.deb` and `.zip`

## Credits

- [Patched-TS-App](https://github.com/34306/Patched-TS-App) by [Huy Nguyen](https://x.com/Little_34306)
- [ChOma](https://github.com/opa334/ChOma) by [@opa334](https://github.com/opa334) and [@alfiecg24](https://github.com/alfiecg24)
- [MachOKit](https://github.com/p-x9/MachOKit) by [@p-x9](https://github.com/p-x9)
- [insert_dylib](https://github.com/tyilo/insert_dylib) by [@tyilo](https://github.com/tyilo)

## License

See [LICENSE](LICENSE).
