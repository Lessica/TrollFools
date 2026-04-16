# Changelog

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
