# Changelog

## 4.1 (2025-09-11)

本次版本聚焦“可见性与交互优化、稳定性提升与本地化完善”。以下为按模块归纳的实际变更：

### 新增

- 可见性：
  - 选项视图（Options）显示已安装插件数量，信息更直观。
  - 应用列表为存在“已禁用插件”的 App 增加徽标标记（Badge），便于快速识别。

### 变更

- 交互与安全性：
  - 全部推出（Eject All）新增“二次确认”流程，降低误操作风险。

### 修复

- 稳定性与性能：
  - 调整子进程执行优先级/调度策略（spawn priority），改善响应性并降低卡顿概率。

### 本地化

- 更新本地化词条，覆盖“插件计数展示、禁用徽标、全部推出确认”等新增与交互变更。

### 文档与合规

- 更新 `LICENSE` 文本。

### 工程

- 本地化配置维护（`.bartycrouch.toml`），与字符串更新保持一致。

------

## 4.1 (2025-09-11) [EN]

This release focuses on visibility and interaction polish, stability improvements, and localization updates. The changes are summarized by module below:

### Added

- Visibility:
  - Show the number of installed plugins in the Options view for clearer status at a glance.
  - Badge apps that have disabled plugins in the app list to make them easy to identify.

### Changed

- Interaction & Safety:
  - Add a confirmation step to “Eject All” to reduce accidental bulk actions.

### Fixed

- Stability & Performance:
  - Adjust child-process execution priority/scheduling (spawn priority) to improve responsiveness and reduce stutter.

### Localization

- Update strings covering plugin count, disabled-plugin badge, and the confirmation for “Eject All”.

### Docs & Compliance

- Update the `LICENSE` text.

### Engineering

- Maintain localization configuration (`.bartycrouch.toml`) in sync with string updates.
