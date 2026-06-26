# 应手

应手是一款离线优先的故障处置手册应用，基于 Flutter 构建，桌面端可搭配本地 Go
RAG 边车（sidecar）。应用本身完全离线可用；当 `rag_sidecar.exe` 与 Windows 应用
程序放在同一目录时，Flutter 会自动拉起它，并通过本地回环 HTTP 在 Agent 标签页提供
检索与带引用的 RAG 答案。

## 项目结构

```text
应手（DevQRH 仓库）
├─ mobile/           # Flutter 跨平台应用
├─ sidecar/rag/      # Go 本地 RAG 边车
└─ scripts/          # 构建与启动脚本
```

## 一键启动（开发）

一步完成：构建 Go 边车、拉取 Flutter 依赖、启动桌面应用。

```bat
scripts\run-dev.bat
```

```powershell
.\scripts\run-dev.ps1
```

可传入设备 id 指定其他平台，例如 `scripts\run-dev.bat chrome`。边车会构建到
`mobile\build\sidecar\rag_sidecar.exe`，Flutter 会在该位置自动发现它（无需设置环境
变量）。

## 运行 Flutter

```bash
cd mobile
flutter pub get
flutter run
```

## 开发期单独运行边车

```bash
cd sidecar/rag
go run . --port=0
```

如需让 Flutter 指向手动构建的边车，设置：

```powershell
$env:DEVQRH_RAG_SIDECAR="C:\path\to\rag_sidecar.exe"
```

## 测试

```bash
cd mobile
flutter test

cd ../sidecar/rag
go test ./...
```

## Windows 打包（含边车）

```powershell
.\scripts\build-windows-with-sidecar.ps1
```

最终应用目录：

```text
mobile\build\windows\x64\runner\Release\
```

发布时请整体打包 `Release\` 目录或封装为安装包。该目录包含 Flutter 应用文件以及
`rag_sidecar.exe`。

当前 RAG 流程完全本地化：Flutter 先将当前手册包发送给边车一次，边车校验后在内存中
建立索引；之后的请求只发送查询语句和返回的内容版本号。边车检索出最匹配的 runbook，
并给出带引用的答案。该本地答案模式无需任何云端 LLM 密钥。

如需启用兼容 OpenAI 接口的 LLM 提供方，启动应用前配置以下环境变量：

```powershell
$env:DEVQRH_LLM_API_KEY="..."
$env:DEVQRH_LLM_MODEL="..."
$env:DEVQRH_LLM_BASE_URL="https://api.openai.com/v1" # 可选
```

若未配置提供方或其不可用，边车会回退到确定性的本地答案。

内置手册包位于 `mobile/assets/content/default_bundle.json`。

## k6 边车压测

先在固定端口启动边车，再运行可复用的 k6 脚本：

```powershell
cd sidecar/rag
go run . --port=18080

cd ../..
k6 run -e TARGET=http://127.0.0.1:18080 -e BUNDLE_MULTIPLIER=100 loadtest/devqrh-sidecar.k6.js
```

使用 `QUERY_MODE=legacy` 可对比每次查询都发送完整手册包的旧请求形态。
