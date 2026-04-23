# Changelog

## 4.3 Build 246 Hotfix (2026-04-23)

修复 4.2 Build 225 至 4.3 Build 246 期间引入的三处注入/移除注入崩溃。三处均为 Swift 运行时陷阱（`brk #1`），`try?` 无法捕获。

### 修复

- **zstd 流式解压崩溃（注入路径）**：`InjectorV3+Preprocess.swift` 中 `ZStd.decompress` 以 `Data()` 起始，再 `append(contentsOf: ArraySlice<UInt8>)`，首次 COW 时在 `_NSZeroData` 背书状态下触发 ARC `brk #1`。改为 `UnsafeMutableRawPointer` 裸缓冲配合 `Data.append(_:count:)`，绕开 Sequence/COW 路径；循环条件收紧为 `streamResult == 0` 退出，无进展时直接抛错，避免截断输入下潜在死循环。
- **MachOKit 非 Mach-O 文件崩溃（移除注入路径）**：commit `8a832b4` 引入的 Unity 回退扫描对 `Frameworks/*.framework/` 中所有 level-2 文件（`Info.plist`、`.car`、`.nib`、`.bin` 等）调用 `isMachO`，`MachOKit.loadFromFile` 在 `NSFileHandle.read<A>(offset:swapHandler:)` 内部 `brk #1`。`isMachO` 收紧为仅校验前 4 字节 Mach-O / fat magic（8 种变体），非 Mach-O 文件不再进入 MachOKit。
- **MachOKit DyldCache 路径崩溃（移除注入路径）**：commit `5ea814a` 引入的 `injectedAssetNames` 反查循环对每个带 `.troll-fools.bak` 备份的 Mach-O 调用 `loadedDylibsOfMachO`，MachOKit 的 load commands 迭代进入 `DyldCache.programsTrieEntries` → `Sequence.programOffsets` 触发 `brk #1`。移除注入本不需要该反查。新增独立实现 `collectModifiedMachOs`，仅扫描文件系统中有 `.troll-fools.bak` 兄弟文件的 Mach-O，完全避开 MachOKit load commands 路径。

完整根因与修复见 `hotfix-4.3-246` annotated tag。

------

## 4.3 Build 246 Hotfix (2026-04-23) [EN]

Fixed three injection/ejection crashes introduced between builds 225 and 246. All three are Swift runtime traps (`brk #1`) that `try?` cannot catch.

### Fixed

- **zstd streaming decompression crash (inject)**: `ZStd.decompress` in `InjectorV3+Preprocess.swift` started from an empty `Data()` backed by `_NSZeroData` and grew via `append(contentsOf: ArraySlice<UInt8>)`; the first COW transition triggered an ARC `brk #1`. Rewritten to use a raw `UnsafeMutableRawPointer` buffer with `Data.append(_:count:)` — bypasses the Sequence/COW path. Loop tightened: break on `streamResult == 0` and fail fast on stalled progress instead of potentially spinning on truncated input.
- **MachOKit crash on non-Mach-O files (eject)**: The Unity fallback scan added in `8a832b4` called `isMachO` on every level-2 file inside `Frameworks/*.framework/` (including `Info.plist`, `.car`, `.nib`, `.bin`). `MachOKit.loadFromFile` `brk #1`s inside `NSFileHandle.read<A>(offset:swapHandler:)` on such inputs. `isMachO` is now a 4-byte magic check only (8 Mach-O / fat magic variants) — non-Mach-O files never reach MachOKit.
- **MachOKit DyldCache trap (eject)**: The `injectedAssetNames` diff loop added in `5ea814a` called `loadedDylibsOfMachO` on every Mach-O with a `.troll-fools.bak` sibling; MachOKit's load-command iteration reaches `DyldCache.programsTrieEntries` → `Sequence.programOffsets` and traps. Eject does not need that filter. A dedicated `collectModifiedMachOs` now does a plain filesystem scan for `.bak` siblings, avoiding every MachOKit load-command path.

Full root-cause notes live in the annotated `hotfix-4.3-246` tag.

------

## 4.3 Build 246 (2026-04-16)

修复二次注入时可能误选已注入动态库作为目标 Mach-O 的问题。

### 修复

- 注入目标选取：修复追加注入时，上次注入的动态库可能被误选为注入目标的问题。  
  新增三层防御：从注入前备份读取原始 Load Commands 以还原真实依赖链；枚举阶段跳过 `.troll-fools.bak` 备份文件；通过备份差分精确识别并排除已注入的动态库。

------

## 4.3 Build 246 (2026-04-16) [EN]

Fixed an issue where re-injection could incorrectly select a previously-injected dylib as the target Mach-O.

### Fixed

- Target selection: Fixed re-injection potentially picking a previously-injected dylib as the injection target.  
  Added three-layer defense: read original load commands from pre-injection backup to restore the true dependency chain; skip `.troll-fools.bak` backup files during enumeration; use backup-diff to precisely identify and exclude previously-injected dylibs.

------

## 4.3 (2026-04-13)

本次版本聚焦于“动态加载框架兼容性”和“页面说明可理解性”，并包含插件管理流程调整与资源清理。

### 修复

- 注入兼容性：修复部分 Unity/运行时 `dlopen` 场景下无法命中可注入目标的问题。  
  当主程序静态链接交集为空时，改为回退扫描 `Frameworks/` 中可用 Mach-O（含一级目录下 `.dylib`）。
- 插件管理：调整“移除插件”流程，区分已启用与已禁用插件：  
  已启用插件执行卸载；已禁用插件执行标记清理，降低批量处理风险。

### 新增

- 高级选项：新增“启用兼容模式回退”开关（默认开启），可控制是否在无静态链接命中时启用回退候选。
- 结果页提示：当本次注入通过兼容模式完成时，在“已完成”下方显示额外提示。

### 优化

- 候选筛选：回退候选新增过滤，排除 `libswift*` 与已忽略注入相关动态库/框架，并统一大小写处理。
- 诊断日志：增强 Mach-O 扫描日志，输出候选数量、文件大小、加密/不可读统计与最终选择结果，便于定位“无可用目标”问题。
- 设置说明：优化高级选项页面结构与说明文案，减少非技术用户理解成本。
- 广告与资源：移除内置广告位 `Letterpress` 及相关本地化词条/图标资源；更新营销图素材。

### 本地化

- 更新 `en/zh-Hans/it/vi` 词条，补充兼容模式与设置说明相关文案，并清理移除条目对应文案。

------

## 4.3 (2026-04-13) [EN]

This release focuses on dynamic-framework injection compatibility and clearer user guidance, plus plugin-management flow adjustments and resource cleanup.

### Fixed

- Injection compatibility: Fixed cases (notably Unity/runtime `dlopen` flows) where no injectable target could be selected.  
  When the static-link intersection is empty, TrollFools now falls back to scanning eligible Mach-O files under `Frameworks/` (including top-level `.dylib`).
- Plugin management: Updated plugin removal flow to handle enabled vs disabled plugins separately:  
  enabled plugins are ejected, while disabled plugins are cleaned via desist/marker path handling.

### Added

- Advanced Settings: Added **Enable Compatibility Fallback** (default ON) to control fallback candidate behavior when no static-link match is found.
- Result-page notice: Added a subtitle under **Completed** when injection succeeds through compatibility fallback.

### Improved

- Candidate filtering: Fallback candidates now exclude `libswift*` and ignored injection-related dylib/framework names, with consistent case-insensitive handling.
- Diagnostics: Expanded Mach-O scan logs with candidate counts, file sizes, encrypted/unreadable stats, and final target selection.
- Settings clarity: Refined Advanced Settings layout and explanatory copy for better non-technical readability.
- Ads/assets: Removed built-in `Letterpress` ad entry and related localization/icon assets; refreshed marketing artwork.

### Localization

- Updated `en/zh-Hans/it/vi` strings for compatibility-fallback and settings guidance, and removed strings for deleted entries.
