# TrollFools

[now-on-havoc]: https://havoc.app/package/trollfools

[<img width="150" src="https://docs.havoc.app/img/badges/get_square.svg" />][now-on-havoc]

In-place tweak injection with insert_dylib and ChOma.  
Proudly written in SwiftUI.  

Expected to work on all iOS versions supported by opa334’s TrollStore (i.e. iOS 14.0 - 17.0).

## Limitations

- [x] Removable system applications
- [x] Decrypted App Store applications (TrollStore applications)
- [x] Encrypted App Store applications with bare dynamic library

## Build

See GitHub Actions for the latest build status.  
PRs are always welcome.

## Milestones

- [x] `optool` is buggy so we need to compile a statically linked `install_name_tool` or `llvm-install-name-tool` on iOS to achieve a smaller package size.
- [x] Support for `.deb` or `.zip`.

## Hotfix Notes (2026-04-23)

A hotfix on top of 4.3 Build 246 resolves three injection/ejection crashes introduced between builds 225 and 246. All three surfaced as Swift runtime traps (`brk #1`) that `try?` could not catch:

- Inject path — zstd streaming decompression tripped ARC during the first COW transition from an empty `Data` (`_NSZeroData`-backed).
- Eject path — the fallback scan called `isMachO` on non-Mach-O files (`Info.plist`, `.car`, `.nib`), reaching a trap inside MachOKit's `NSFileHandle.read`.
- Eject path — the `injectedAssetNames` backup-diff loop reached MachOKit's `DyldCache.programsTrieEntries` parser and trapped there.

See [CHANGELOG.md](CHANGELOG.md) and the annotated `hotfix-4.3-246` tag for per-bug root cause and fix details.

## Credits

This project is inspired by [Patched-TS-App](https://github.com/34306/Patched-TS-App) by **[Huy Nguyen](https://x.com/Little_34306) and [Nathan](https://x.com/dedbeddedbed)**.

- [ChOma](https://github.com/opa334/ChOma) by [@opa334](https://github.com/opa334) and [@alfiecg24](https://github.com/alfiecg24)
- [MachOKit](https://github.com/p-x9/MachOKit) by [@p-x9](https://github.com/p-x9)
- [insert_dylib](https://github.com/tyilo/insert_dylib) by [@tyilo](https://github.com/tyilo)

## License

See [LICENSE](LICENSE).
