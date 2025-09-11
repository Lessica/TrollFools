# Changelog

## 4.2 (2025-09-12)

本次版本为一次“兼容性与结构优化”小步更新，核心聚焦：旧系统适配（iOS 14 列表兼容）、徽标逻辑精细化、通用结构/代码整理与本地化补充。

### 修复

- 兼容性：修复在 iOS 14 上包含“动态数量 Section”的列表（List）组件渲染/刷新异常问题，确保分段增减时 UI 与交互稳定。

### 优化 / 重构

- 徽标：优化禁用插件 App 的徽标判断与展示逻辑，减少重复计算并提升视觉一致性。
- 通用结构：对应用列表、插件管理、注入/卸载流程、设置视图等多个模块进行内部重构（不改变外部行为）以提升可维护性。

### 本地化

- 补充/更新越南语（vi）词条，保持与最新交互及文案一致。

### 工程

- 代码清理与结构对齐（未引入破坏性改动），为后续特性迭代准备。

------

## 4.2 (2025-09-12) [EN]

This is a focused compatibility & structural refinement update: iOS 14 dynamic list stability, refined badge logic, internal refactors, and a localization supplement.

### Fixed

- Compatibility: Resolve rendering/refresh issues on iOS 14 when a List contains a dynamic number of Sections, ensuring stable UI and interaction when sections are added or removed.

### Optimization / Refactor

- Badging: Refine logic for marking apps with disabled plugins to reduce redundant evaluation and keep visuals consistent.
- Internal structure: Non‑behavioral refactors across app list, plugin management, inject/eject flows, settings view, and related persistence modules to improve maintainability.

### Localization

- Update / supplement Vietnamese (vi) strings to align with current UI and interactions.

### Engineering

- Code cleanup and structural alignment (no breaking changes) preparing groundwork for upcoming features.
