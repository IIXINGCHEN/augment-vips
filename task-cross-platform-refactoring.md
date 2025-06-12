# Context
Filename: task-cross-platform-refactoring.md
Created on: 2025-01-27
Created by: User
Yolo mode: False

# Task Description
项目代码重构，模块化，项目最后必须要实现 Windows，linux，macOS，对应功能，完全模块化管理。参考目标架构：https://deepwiki.com/azrilaiman2003/augment-vip

# Project Overview
当前项目是一个VS Code Augment清理工具，目前只有Windows版本的PowerShell脚本实现。需要重构为跨平台模块化架构，支持Windows、Linux、macOS三个平台。

核心功能：
1. 清理VS Code数据库中的Augment相关条目（state.vscdb文件）
2. 修改VS Code的遥测ID（storage.json文件中的machineId、deviceId、sqmId）

⚠️ Warning: Do Not Modify This Section ⚠️
RIPER-5协议核心规则：
- 必须按照RESEARCH -> INNOVATE -> PLAN -> EXECUTE -> REVIEW的模式执行
- 在EXECUTE模式中必须100%忠实于计划
- 在REVIEW模式中必须标记任何偏差
- 代码必须满足生产环境标准：完整实现、全面安全、稳定性、可执行性、非冗余性
- 必须使用包管理器进行依赖管理，不能手动编辑包配置文件
⚠️ Warning: Do Not Modify This Section ⚠️

# Analysis
当前项目分析：

## 现有结构
- install.ps1: Windows主安装脚本
- clean_code_db.ps1: Windows数据库清理脚本  
- id_modifier.ps1: Windows遥测ID修改脚本
- README.md: 项目文档（仅Windows）

## 缺失组件
1. Linux平台支持（Bash脚本）
2. macOS平台支持（Bash脚本）
3. 跨平台模块化架构
4. 统一的配置管理
5. 平台检测和自动适配
6. 跨平台依赖管理

## 技术要求
- 支持平台：Windows (PowerShell)、Linux (Bash)、macOS (Bash)
- 依赖工具：sqlite3、curl、jq
- 包管理器：Windows (Chocolatey)、Linux (apt/dnf)、macOS (Homebrew)
- 目标文件：state.vscdb、storage.json

# Proposed Solution

## 选定架构：企业级跨平台模块化架构

### 核心设计原则
1. **完整性**：覆盖所有平台和功能需求，无遗漏
2. **安全性**：输入验证、权限检查、备份机制、审计日志
3. **零冗余**：DRY原则，共享核心逻辑，消除重复代码
4. **生产就绪**：错误处理、监控、性能优化、可维护性

### 企业级目录结构
```
augment-vip/
├── install                    # 统一入口脚本（无扩展名，跨平台）
├── core/                      # 核心模块（零冗余共享逻辑）
│   ├── common.sh             # 通用函数库
│   ├── platform.sh           # 平台检测与适配
│   ├── dependencies.sh       # 依赖管理与验证
│   ├── paths.sh              # 路径解析与验证
│   ├── database.sh           # 数据库操作（SQLite）
│   ├── telemetry.sh          # 遥测ID处理
│   ├── backup.sh             # 备份恢复机制
│   ├── security.sh           # 安全验证与审计
│   ├── logging.sh            # 企业级日志系统
│   └── validation.sh         # 输入验证与清理
├── platforms/                # 平台特定实现（最小化差异）
│   ├── windows.ps1           # Windows PowerShell实现
│   ├── linux.sh              # Linux Bash实现
│   └── macos.sh              # macOS Bash实现
├── config/                   # 配置管理
│   ├── settings.json         # 统一配置文件
│   └── security.json         # 安全策略配置
├── tests/                    # 完整测试套件
│   ├── unit/                 # 单元测试
│   ├── integration/          # 集成测试
│   ├── security/             # 安全测试
│   └── performance/          # 性能测试
├── logs/                     # 日志目录
└── docs/                     # 企业级文档
    ├── README.md             # 主文档
    ├── SECURITY.md           # 安全文档
    ├── DEPLOYMENT.md         # 部署指南
    └── TROUBLESHOOTING.md    # 故障排除
```

### 企业级技术实现方案

#### 1. 安全性设计（生产环境标准）
- **输入验证**：所有用户输入严格验证和清理
- **权限检查**：最小权限原则，运行时权限验证
- **审计日志**：完整的操作审计跟踪
- **备份策略**：自动备份，完整性验证，恢复测试
- **加密存储**：敏感数据加密处理

#### 2. 零冗余模块化设计
- **核心逻辑共享**：所有平台共享相同的业务逻辑
- **平台适配层**：最小化平台差异，仅处理系统调用差异
- **配置驱动**：通过配置文件控制行为，避免硬编码
- **接口标准化**：统一的函数签名和返回值格式

#### 3. 生产环境可靠性
- **错误处理**：完整的异常捕获和恢复机制
- **监控集成**：性能指标收集和健康检查
- **资源管理**：内存和文件句柄的正确释放
- **并发安全**：多实例运行的安全保护

#### 4. 企业级部署支持
- **自动化测试**：CI/CD集成，自动化测试套件
- **版本管理**：语义化版本控制，向后兼容
- **文档完整性**：API文档、部署指南、故障排除
- **合规性**：安全扫描、代码审计、许可证管理

# Current Execution Step: "3. Planning Phase"

# Task Progress
[2025-01-27] 开始项目重构分析，识别当前Windows-only架构需要扩展为跨平台模块化架构
[2025-01-27] 开始执行企业级跨平台模块化重构
- Modified: 所有核心模块、平台实现、统一入口脚本、配置文件、遗留文件清理
- Change: 完成企业级跨平台模块化架构重构：
  * 核心模块：common.sh, platform.sh, security.sh, logging.sh, validation.sh, dependencies.sh, paths.sh, database.sh, telemetry.sh, backup.sh
  * 平台实现：windows.ps1, linux.sh, macos.sh
  * 统一入口：install（跨平台自动检测）
  * 配置管理：settings.json, security.json
  * 遗留文件清理：删除clean_code_db.ps1, id_modifier.ps1（功能已集成到新架构）
  * 仓库地址更新：更新为https://github.com/IIXINGCHEN/augment-vips
- Reason: 建立零冗余的企业级架构，消除代码重复，满足生产环境完整性、安全性、可靠性要求
- Blockers: 无
- Status: 重构完成，架构清理完毕

# Final Review
[待REVIEW模式填充]
