
# Changelog

## 4.0 (2025-09-10)

本月重点围绕“插件管理、版本更新检查、无障碍与界面完善、稳定性与性能提升”等方向展开。以下为按模块归纳的实际变更：

### 新增

- 插件管理能力增强：
  - 支持单个插件启用/停用切换（Eject/Inject 流程与 UI 交互完善）。
  - 新增“全部停用（Desist All）/全部重新启用（Re-enable All）”批量操作。
  - 启用状态持久化，应用启动时自动加载上次的插件状态。
- 版本更新检查：
  - 增加应用内检查更新的逻辑与提示，配套多语言文案与配置项。
- 广告资源更新：
  - 新增/替换广告位及相关资源，完善展示逻辑。

### 变更

- 术语与界面：将“Eject”更名为“Manage/管理”，与当前交互与语义一致。
- 无障碍（Accessibility）：重构若干视图与单元格的可达性标签与提示，提升读屏体验。
- 文案与合规：更新应用免责声明内容。

### 修复

- 布局：修复横屏下若干视图（应用列表、选项视图、插件单元格）的排版问题。
- 交互组件：修复索引滚动（Indexable Scroller）在列表中的定位与交互问题。
- 性能与时序：
  - 避免对 Filza 的重复查询，减少不必要的 I/O 和等待。
  - 调整子进程 spawn 的等待逻辑，避免潜在卡顿或时序竞态。
- 本地化：统一中文名称/表述，清理与更新多语言词条。

### Command Line Interface (CLI)

- 注入/卸载与管理能力扩展：
  - 新增与“全部停用/重新启用”一致的批量管理能力。
  - 与应用内逻辑保持一致，便于脚本化/批处理使用。

### 本地化

- 更新并补充 en、it、vi、zh-Hans 等多语言字符串，覆盖“更新检查、提示信息、管理操作”等新增功能。

### 构建与工程

- 版本与构建：版本提升至 4.0（Build 212），更新调试构建号与相关脚本。
- 工程配置：更新 Xcode 方案与依赖（含 Package.resolved、xcscheme 等），接入更新检查相关模块；维护 devkit 与 control 配置。

### 注意事项 / 可能的兼容性变更

- “Eject” 重命名为 “Manage/管理”：界面与文案发生变化，命令行与文档请以“管理/Manage”语义为准。

------

## 4.0 (2025-09-10) [EN]

This month focused on plugin management, update checking, accessibility and UI polish, plus stability and performance improvements. Below is a feature-oriented summary grouped by module:

### Added

- Plugin management enhancements:
  - Toggle enable/disable for individual plugins (polished Eject/Inject flows and UI interactions).
  - New bulk actions: Desist All / Re-enable All.
  - Persist plugin enablement state and auto-load on app launch.
- Update checking:
  - In-app update check logic and prompts, with localization strings and configuration.
- Ad assets:
  - New/replaced placements and assets with improved display logic.

### Changed

- Terminology & UI: Rename “Eject” to “Manage” to better match current interactions and semantics.
- Accessibility: Refactor accessibility labels and hints across multiple views/cells to improve screen reader experience.
- Copy & compliance: Update the in-app disclaimer content.

### Fixed

- Layout: Fix landscape issues in App List, Options View, and Plugin Cell.
- Interactive component: Fix Indexable Scroller positioning and interactions in lists.
- Performance & timing:
  - Avoid repeated Filza queries to reduce unnecessary I/O and waiting.
  - Adjust child-process spawn waiting to prevent potential stalls or race conditions.
- Localization: Unify Chinese naming/phrasing and refresh language entries.

### CLI

- Extend inject/uninstall/manage capabilities:
  - Bulk management aligned with “Desist All / Re-enable All”.
  - Behavior consistent with in-app logic for scripting/batch usage.

### Localization

- Update and supplement en, it, vi, zh-Hans strings, covering update checking, prompts, and management operations.

### Build & Engineering

- Version & build: Bump to 4.0 (Build 212); update debug build number and related scripts.
- Project configuration: Update Xcode schemes and dependencies (including Package.resolved, xcscheme); integrate update-check modules; maintain devkit and control configuration.

### Notes / Potential Compatibility Changes

- “Eject” renamed to “Manage”: UI and copy have changed; CLI and documentation should adopt “Manage” semantics.
