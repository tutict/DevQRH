# 应手 Mobile

独立运行的 Flutter 手册应用，桌面端可选搭配本地 Go RAG 边车。

## 当前形态

- 无需远程后端
- 桌面构建可使用 `rag_sidecar.exe` 进行本地检索与 RAG 答案
- 应用内置一份手册包
- 用户可在「设置」中导入本地手册包
- 导入的内容会替换当前本地手册缓存
- 用户可随时恢复内置手册

## 手册包格式

导入一个具有如下结构的 JSON 文件：

```json
{
  "manifest": {
    "schemaVersion": 2,
    "packageId": "devqrh.default.oncall",
    "name": "DevQRH Default On-Call Runbooks",
    "version": "20260415",
    "checklistCount": 4,
    "runbookCount": 4,
    "generatedAt": 1776124800000,
    "team": "platform",
    "defaultLocale": "en-US"
  },
  "matchingConfig": {
    "partialMinLength": 3,
    "synonymGroups": [["slow", "latency"]],
    "weights": {
      "exactQueryId": 1.0,
      "exactIdToken": 1.0,
      "exactTitleToken": 0.95,
      "exactKeywordToken": 0.9,
      "exactSymptomToken": 0.78,
      "exactContextToken": 0.6,
      "synonymKeyword": 0.72,
      "synonymPrimary": 0.62,
      "synonymAny": 0.5,
      "partialKeyword": 0.48,
      "partialPrimary": 0.4,
      "partialAny": 0.28,
      "tokenAverage": 0.88,
      "keywordCoverage": 0.12,
      "exactTitleBoost": 0.12,
      "partialTitleBoost": 0.07,
      "partialIdBoost": 0.07,
      "phraseBoost": 0.04
    }
  },
  "checklists": [
    {
      "id": "cpu_100",
      "title": "CPU 100%",
      "summary": "Use this runbook when a service or host is CPU saturated.",
      "severity": "p2",
      "systems": ["linux", "jvm", "backend-service"],
      "tags": ["cpu", "saturation"],
      "keywords": ["cpu"],
      "symptoms": ["high CPU"],
      "signals": ["CPU usage above 90%"],
      "owner": "backend platform",
      "escalation": "Escalate to the owning service team if errors rise.",
      "lastReviewedAt": "2026-04-15",
      "reviewIntervalDays": 180,
      "safeSteps": [{"step": 1, "action": "top", "risk": "safe"}],
      "cautionSteps": [],
      "dangerSteps": [],
      "commands": [
        {
          "id": "cpu-top",
          "title": "Top processes",
          "command": "top",
          "step": 1,
          "risk": "safe"
        }
      ],
      "immediateActions": [{"step": 1, "action": "top", "risk": "safe"}],
      "decisionTree": [{"condition": "high GC", "action": "analyze dump"}],
      "rootCause": ["bad code"],
      "longTermFix": ["optimize hot path"],
      "relatedRunbooks": []
    }
  ]
}
```

`schemaVersion: 2` 的包可包含 on-call 元数据，例如严重级别、系统、负责人/升级路径、
复核新鲜度、按风险分组的步骤，以及可复制的命令。仅含 `immediateActions` 的旧包仍可
导入；缺失的运维元数据只作为校验警告，而非致命错误。

内置参考包位于 `assets/content/default_bundle.json`。

## 构建

Windows 发布版：

```bash
flutter build windows
```

Windows 发布版（含本地 Go 边车）：

```powershell
..\scripts\build-windows-with-sidecar.ps1
```

产物：

```text
build/windows/x64/runner/Release/
```

发布时请整体打包 `Release/` 目录，而不仅是 `DevQRH.exe`。含边车的构建中，该目录还包含
`rag_sidecar.exe`。

当 `rag_sidecar.exe` 存在时，Agent 标签页会在推荐的 runbook 之前展示带来源引用的本地
RAG 答案。若边车缺失，应用会回退到内置的 Flutter 匹配器。

可选的 LLM 模式通过边车环境变量配置：

```powershell
$env:DEVQRH_LLM_API_KEY="..."
$env:DEVQRH_LLM_MODEL="..."
$env:DEVQRH_LLM_BASE_URL="https://api.openai.com/v1" # 可选
```

Android 发布版：

```bash
flutter build apk
```

当前机器尚未安装 Android SDK，无法构建 Android。

## 应用标识

- 应用名称：`应手`
- Android 包名：`com.devqrh.app`
- Windows 可执行文件：`DevQRH.exe`
