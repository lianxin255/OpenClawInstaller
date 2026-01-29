# 🦞 ClawdBot 一键部署工具

<p align="center">
  <img src="https://img.shields.io/badge/Version-1.0.0-blue.svg" alt="Version">
  <img src="https://img.shields.io/badge/Platform-macOS%20%7C%20Linux-green.svg" alt="Platform">
  <img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License">
</p>

> 🚀 一键部署你的私人 AI 助手 ClawdBot，支持多平台多模型配置

## 📖 目录

- [功能特性](#-功能特性)
- [系统要求](#-系统要求)
- [快速开始](#-快速开始)
- [详细配置](#-详细配置)
- [常用命令](#-常用命令)
- [配置说明](#-配置说明)
- [安全建议](#-安全建议)
- [常见问题](#-常见问题)
- [更新日志](#-更新日志)

## ✨ 功能特性

### 🤖 多模型支持
- **Anthropic Claude** - Claude Opus 4 / Sonnet 4 / Haiku
- **OpenAI GPT** - GPT-4o / GPT-4 Turbo / o1
- **OpenAI Compatible** - 支持任何兼容 OpenAI API 的服务 (OneAPI/NewAPI/代理等)
- **Google Gemini** - Gemini 2.0 Flash / 1.5 Pro
- **Ollama** - 本地部署，无需 API Key
- **OpenRouter** - 多模型网关，一个 Key 用遍所有模型
- **Groq** - 超快推理，Llama 3.3 / Mixtral
- **Mistral AI** - Mistral Large / Codestral
- **Azure OpenAI** - 企业级 Azure 部署

### 📱 多渠道接入
- Telegram Bot
- Discord Bot
- WhatsApp
- Slack
- 微信 (WeChat)
- iMessage (仅 macOS)

### 🧠 核心能力
- **持久记忆** - 跨对话、跨平台的长期记忆
- **主动推送** - 定时提醒、晨报、告警通知
- **技能系统** - 通过 Markdown 文件定义自定义能力
- **远程控制** - 可执行系统命令、读写文件、浏览网络

## 💻 系统要求

| 项目 | 要求 |
|------|------|
| 操作系统 | macOS 12+ / Ubuntu 20.04+ / Debian 11+ / CentOS 8+ |
| Node.js | v22 或更高版本 |
| 内存 | 最低 2GB，推荐 4GB+ |
| 磁盘空间 | 最低 1GB |

## 🚀 快速开始

### 方式一：一键安装（推荐）

```bash
# 下载并运行安装脚本
curl -fsSL https://raw.githubusercontent.com/miaoxworld/ClawdBotInstaller/main/install.sh | bash
```

安装脚本会自动：
1. 检测系统环境并安装依赖
2. 安装 ClawdBot
3. 引导完成核心配置（AI模型、身份信息）
4. 测试 API 连接
5. 自动打开配置菜单进行详细配置

### 方式二：手动安装

```bash
# 1. 克隆仓库
git clone https://github.com/miaoxworld/ClawdBotInstaller.git
cd ClawdBotInstaller

# 2. 添加执行权限
chmod +x install.sh config-menu.sh

# 3. 运行安装脚本
./install.sh
```

### 安装完成后

安装完成后会自动打开配置菜单，也可以手动运行：

```bash
# 运行配置菜单进行详细配置
bash ~/.clawd/config-menu.sh

# 或从 GitHub 下载运行
curl -fsSL https://raw.githubusercontent.com/miaoxworld/ClawdBotInstaller/main/config-menu.sh | bash

# 启动服务
clawdbot start
```

## ⚙️ 详细配置

### 配置 AI 模型

运行配置菜单后选择 `[2] AI 模型配置`：

```
🤖 AI 模型配置
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
选择 AI 提供商:

  [1] 🟣 Anthropic Claude (推荐)
  [2] 🟢 OpenAI GPT
  [3] 🟠 Ollama 本地模型
  [4] 🔵 OpenRouter (多模型网关)
```

#### Anthropic Claude 配置

1. 访问 [Anthropic Console](https://console.anthropic.com/)
2. 创建账号并获取 API Key
3. 在配置菜单中选择 Anthropic Claude
4. 输入 API Key
5. 选择模型（推荐 Sonnet 4）

#### OpenAI GPT 配置

1. 访问 [OpenAI Platform](https://platform.openai.com/)
2. 获取 API Key
3. 在配置菜单中选择 OpenAI GPT
4. 输入 API Key

#### Ollama 本地模型

```bash
# 1. 安装 Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# 2. 下载模型
ollama pull llama3

# 3. 在配置菜单中选择 Ollama
# 输入服务地址：http://localhost:11434
```

#### OpenAI Compatible (通用兼容接口)

适用于 OneAPI、New API、各种代理服务等任何兼容 OpenAI API 格式的服务。

1. 在配置菜单中选择 `OpenAI Compatible`
2. 输入 API 地址（如 `https://your-api.com/v1`）
3. 输入 API Key
4. 选择或输入模型名称

**配置示例：**

```yaml
llm:
  provider: openai-compatible
  base_url: "https://oneapi.example.com/v1"
  api_key: "sk-your-api-key"
  model: claude-sonnet-4.5
```

#### Groq (超快推理)

1. 访问 [Groq Console](https://console.groq.com/) 获取 API Key
2. 在配置菜单中选择 Groq
3. 输入 API Key
4. 选择模型（推荐 llama-3.3-70b-versatile）

#### Google Gemini

1. 访问 [Google AI Studio](https://makersuite.google.com/app/apikey) 获取 API Key
2. 在配置菜单中选择 Google Gemini
3. 输入 API Key
4. 选择模型（推荐 gemini-2.0-flash）

### 配置 Telegram 机器人

1. 在 Telegram 中搜索 `@BotFather`
2. 发送 `/newbot` 创建新机器人
3. 设置机器人名称和用户名
4. 复制获得的 **Bot Token**
5. 搜索 `@userinfobot` 获取你的 **User ID**
6. 在配置菜单中选择 Telegram，输入以上信息

### 配置 Discord 机器人

1. 访问 [Discord Developer Portal](https://discord.com/developers/applications)
2. 点击 "New Application" 创建应用
3. 进入 "Bot" 页面，点击 "Add Bot"
4. 复制 **Bot Token**
5. 在 "OAuth2" → "URL Generator" 中生成邀请链接
6. 邀请机器人到你的服务器
7. 获取目标频道的 **Channel ID**（右键频道 → 复制 ID）
8. 在配置菜单中输入以上信息

## 📝 常用命令

### 服务管理

```bash
# 启动服务
clawdbot start

# 停止服务
clawdbot stop

# 重启服务
clawdbot restart

# 查看状态
clawdbot status

# 查看日志
clawdbot logs

# 实时日志
clawdbot logs -f
```

### 配置管理

```bash
# 打开配置文件
clawdbot config

# 运行配置向导
clawdbot onboard

# 诊断配置问题
clawdbot doctor

# 健康检查
clawdbot health
```

### 数据管理

```bash
# 导出对话历史
clawdbot export --format json

# 清理记忆
clawdbot memory clear

# 备份数据
clawdbot backup
```

## 📋 配置说明

配置文件位置：`~/.clawd/config.yaml`

### 完整配置示例

```yaml
# ClawdBot 配置文件
version: "1.0"
debug: false

# AI 模型配置
llm:
  provider: anthropic           # 提供商: anthropic/openai/ollama
  api_key: "sk-ant-xxx"         # API Key
  model: claude-sonnet-4-20250514  # 模型名称
  max_tokens: 4096              # 最大输出 token
  temperature: 0.7              # 温度参数 (0-1)

# 身份配置
identity:
  bot_name: "Clawd"             # 助手名称
  user_name: "主人"              # 你的称呼
  timezone: "Asia/Shanghai"     # 时区
  language: "zh-CN"             # 语言
  personality: |                # 个性描述
    你是一个聪明、幽默、有创造力的AI助手。
    你善于分析问题，提供有见地的建议。

# 网关配置
gateway:
  host: "127.0.0.1"
  port: 18789

# 渠道配置
channels:
  telegram:
    enabled: true
    token: "your-bot-token"
    allowed_users:
      - "your-user-id"
  
  discord:
    enabled: false
    token: "your-bot-token"
    channels:
      - "channel-id"

# 记忆系统
memory:
  enabled: true
  storage_path: "~/.clawd/data/memory"
  max_context_length: 32000

# Skills 技能
skills:
  enabled: true
  path: "~/.clawd/skills"

# 安全配置
security:
  enable_shell_commands: false  # 允许执行系统命令
  enable_file_access: false     # 允许文件访问
  enable_web_browsing: true     # 允许网络浏览
  sandbox_mode: true            # 沙箱模式

# 日志配置
logging:
  level: "info"                 # 日志级别: debug/info/warn/error
  path: "~/.clawd/logs"
  max_size: "10MB"
  max_files: 5
```

### 目录结构

```
~/.clawd/
├── config.yaml          # 主配置文件
├── data/
│   ├── memory/          # 记忆存储
│   └── conversations/   # 对话历史
├── skills/              # 自定义技能
│   └── daily-report.md  # 示例技能
├── logs/                # 日志文件
│   ├── clawd.log
│   ├── stdout.log
│   └── stderr.log
└── backups/             # 配置备份
```

## 🛡️ 安全建议

> ⚠️ **重要警告**：ClawdBot 需要完全的计算机权限，请务必注意安全！

### 部署建议

1. **不要在主工作电脑上部署** - 建议使用专用服务器或虚拟机
2. **使用 AWS/GCP/Azure 免费实例** - 隔离环境更安全
3. **Docker 部署** - 提供额外的隔离层

### 权限控制

1. **禁用危险功能**（默认已禁用）
   ```yaml
   security:
     enable_shell_commands: false
     enable_file_access: false
   ```

2. **启用沙箱模式**
   ```yaml
   security:
     sandbox_mode: true
   ```

3. **限制允许的用户**
   ```yaml
   channels:
     telegram:
       allowed_users:
         - "only-your-user-id"
   ```

### API Key 安全

- 定期轮换 API Key
- 不要在公开仓库中提交配置文件
- 使用环境变量存储敏感信息

```bash
# 使用环境变量
export ANTHROPIC_API_KEY="sk-ant-xxx"
export TELEGRAM_BOT_TOKEN="xxx"
```

## ❓ 常见问题

### Q: 安装时提示 Node.js 版本过低？

```bash
# macOS
brew install node@22
brew link --overwrite node@22

# Ubuntu/Debian
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs
```

### Q: 启动后无法连接？

1. 检查配置文件是否正确
2. 运行诊断命令：`clawdbot doctor`
3. 查看日志：`clawdbot logs`

### Q: Telegram 机器人没有响应？

1. 确认 Bot Token 正确
2. 确认 User ID 在 allowed_users 列表中
3. 检查网络连接（可能需要代理）

### Q: 如何更新到最新版本？

```bash
# 使用 npm 更新
npm update -g clawdbot

# 或使用配置菜单
./config-menu.sh
# 选择 [7] 高级设置 → [7] 更新 ClawdBot
```

### Q: 如何备份数据？

```bash
# 手动备份
cp -r ~/.clawd ~/clawd_backup_$(date +%Y%m%d)

# 使用命令备份
clawdbot backup
```

### Q: 如何完全卸载？

```bash
# 停止服务
clawdbot stop

# 卸载程序
npm uninstall -g clawdbot

# 删除配置（可选）
rm -rf ~/.clawd
```

## 📜 更新日志

### v1.0.0 (2026-01-29)
- 🎉 首次发布
- ✨ 支持一键安装部署
- ✨ 交互式配置菜单
- ✨ 多模型支持 (Claude/GPT/Ollama)
- ✨ 多渠道支持 (Telegram/Discord/WhatsApp)
- ✨ 技能系统
- ✨ 安全配置

## 📄 许可证

本项目基于 MIT 许可证开源。

## 🔗 相关链接

- [ClawdBot 官网](https://clawd.bot)
- [官方文档](https://clawd.bot/docs)
- [安装工具仓库](https://github.com/miaoxworld/ClawdBotInstaller)
- [ClawdBot 主仓库](https://github.com/clawdbot/clawdbot)
- [社区讨论](https://github.com/miaoxworld/ClawdBotInstaller/discussions)

---

<p align="center">
  Made with ❤️ by <a href="https://github.com/miaoxworld">miaoxworld</a>
</p>
