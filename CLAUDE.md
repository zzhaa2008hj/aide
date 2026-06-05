# AIDE Project Instructions

## DeepCode CLI & CodeWhale Support (MANDATORY)

本项目支持 **deepcode-cli**（首要）和 **CodeWhale** 作为代码分析后端。后续所有功能开发必须以支持 deepcode-cli 为首要目标，同时保持 CodeWhale 兼容：

- **新功能优先适配 deepcode-cli**：任何新增的代码分析、review、扫描等功能，必须首先确保与 deepcode-cli 兼容。其次适配 CodeWhale。
- **以 deepcode-cli 源码为准，禁止猜测**：做 deepcode-cli 兼容时，必须以 [deepcode-cli 源码](https://github.com/lessweb/deepcode-cli.git) 为依据。不要猜测或伪造不存在的方法、CLI 命令、API 接口。不确定时先 clone 源码查阅确认，再动手实现。
- **以 CodeWhale 源码为准，禁止猜测**：做 CodeWhale 兼容时，必须以 [CodeWhale 源码](https://github.com/Hmbown/CodeWhale.git) 为依据。不要猜测或伪造不存在的方法、CLI 命令、API 接口。不确定时先 clone 源码查阅确认，再动手实现。
- **不破坏现有集成**：修改 `aide_deepcode/` 目录下的脚本或 `skills/aide-deepcode/`、`skills/aide-codewhale/` 下的技能时，需保持向后兼容。
- **文档同步**：与 CodeWhale 和 deepcode-cli 相关的配置、安装、使用说明需在 README 中保持更新。

## README Discipline (MANDATORY)

When adding, modifying, or removing any feature in this project, **README.md must be checked and updated before the change is considered complete.**

Specifically:
- **Feature Status table**: serves as both progress tracker and TODO list. Add rows for planned features, mark completed ones, update status labels. Read `## Feature Status` before claiming any feature is done.
- **Project Structure diagram**: reflect new or removed files/directories under `aide-core/`, `skills/`, `hooks/`, `aide_deepcode/`
- **Version**: ensure README references match `plugin.json` version
- **Dependencies / Requirements**: update if new tools or packages are needed

This is the single source of truth for the project. An outdated README causes confusion about what exists, what's done, and what's planned.

## Memory

Project memory is at `.claude/projects/-home-hui-ai-AIDE/memory/`. Check MEMORY.md for deferred items and known limitations before starting work.
