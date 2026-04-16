# DevQRH

一个面向开发运维场景的快速检索式知识工具，用于将常见故障处置步骤、检查清单和关键词匹配能力收敛到统一入口。项目同时提供 CLI、HTTP 服务和 Flutter 客户端，适合本地排障、团队共享和移动端快速查阅。

## 项目概览

- 项目类型：轻量级故障排查与知识检索工具
- 业务方向：开发运维场景下的应急手册与检查清单查询
- 主要能力：关键词匹配、结构化 YAML 知识管理、CLI 查询、HTTP API、移动端同步
- 适合阅读对象：HR 初筛、后端开发、运维平台、工具平台方向面试官

## 核心功能

- 基于故障现象进行快速检索
- 将排障步骤、决策树和长期修复建议结构化存储
- 同时支持命令行、服务端接口和移动端访问
- 支持匹配规则热更新与数据自动重载
- 支持移动端离线缓存、启动同步与本地检索回退
- 提供健康检查、清单详情和管理重载接口

## 承担内容

- 完成排障知识的数据结构设计与 YAML 规范定义
- 完成 Spring Boot 后端、Picocli CLI 和 Flutter 客户端的统一实现
- 完成关键词匹配配置、同义词权重和排序规则设计
- 完成服务端自动重载、移动端同步与离线回退逻辑
- 完成基础测试与跨平台运行支持

## 关键技术实现

- 使用 `Spring Boot` 构建统一服务端与 API 能力
- 使用 `Picocli` 提供命令行查询入口
- 使用 `Jackson YAML` 管理可维护的结构化知识数据
- 通过 `matching-config.yaml` 管理同义词、权重与排序策略
- 通过 `WatchService` 实现本地数据与匹配配置自动重载
- Flutter 客户端优先加载本地缓存，再进行远端同步
- 搜索能力在离线场景下可回退到本地清单数据

## 技术栈

| 分层 | 技术方案 |
| --- | --- |
| 后端 | Spring Boot 3.3、Spring Web |
| CLI | Picocli |
| 数据格式 | YAML、Jackson Dataformat YAML |
| 客户端 | Flutter |
| 配置与匹配 | 本地 YAML 配置、关键词权重、同义词分组 |
| 测试 | Spring Boot Test |

## 仓库结构

```text
DevQRH
├─ src/              # Java 后端、CLI、API 与测试
├─ data/             # 排障清单 YAML 数据
├─ mobile/           # Flutter 跨平台客户端
├─ devqrh            # Unix/Linux 启动脚本
├─ devqrh.cmd        # Windows 启动脚本
└─ pom.xml           # Maven 构建配置
```

## 主要模块说明

### 1. 服务端与 CLI

主线模块，负责知识加载、匹配检索、接口输出和命令行调用。

- 路径：`src/`
- 技术关键词：`Spring Boot`、`Picocli`
- 主要能力：
  - 故障现象检索
  - 清单详情查询
  - 健康检查
  - 管理重载

### 2. 结构化知识数据

采用 YAML 管理排障内容，便于持续补充和维护。

- 路径：`data/`
- 内容结构：
  - `id`
  - `title`
  - `keywords`
  - `symptoms`
  - `immediate_actions`
  - `decision_tree`
  - `root_cause`
  - `long_term_fix`

### 3. 匹配配置

用于控制检索的可维护性和可调优能力。

- 路径：`src/main/resources/matcher/matching-config.yaml`
- 主要能力：
  - 同义词分组配置
  - 关键词权重调整
  - 排序策略调优
  - 无需修改 Java 代码即可迭代匹配效果

### 4. Flutter 客户端

用于跨平台快速访问和离线浏览。

- 路径：`mobile/`
- 技术关键词：`Flutter`
- 主要能力：
  - 启动读取本地缓存
  - 拉取清单清单与配置清单
  - 按版本同步数据
  - 离线回退到本地知识集

## 运行说明

### 环境准备

- JDK 17+
- Maven 3.9+
- Flutter 3+

### 构建

```bash
mvn test
mvn package
```

### CLI 使用

```bash
java -jar target/devqrh.jar ask "CPU 100%"
java -jar target/devqrh.jar ask "service is slow"
java -jar target/devqrh.jar agent "service is slow"
```

Windows 快捷方式：

```powershell
.\devqrh.cmd ask "CPU 100%"
```

### 服务端启动

```bash
java -jar target/devqrh.jar serve
```

### Flutter 客户端启动

```bash
cd mobile
flutter pub get
flutter run --dart-define=DEVQRH_API_BASE_URL=http://localhost:8080
```

## 接口说明

- `GET /api/lookup?q=CPU%20100`
- `GET /api/agent/navigate?q=service%20is%20slow`
- `GET /api/checklists/{id}`
- `GET /api/health`
- `GET /api/mobile/manifest`
- `GET /api/mobile/bootstrap`
- `POST /api/admin/reload`

## 配置说明

- 排障数据默认从 `data/*.yaml` 加载
- 匹配配置默认使用 `src/main/resources/matcher/matching-config.yaml`
- `serve` 模式下启用本地文件优先策略
- 支持以下自动重载配置：
  - `devqrh.auto-reload.enabled`
  - `devqrh.auto-reload.debounce-ms`

