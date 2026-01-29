#!/bin/bash
#
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                                                                           ║
# ║   🦞 ClawdBot 一键部署脚本 v1.0.0                                          ║
# ║   智能 AI 助手部署工具 - 支持多平台多模型                                    ║
# ║                                                                           ║
# ║   GitHub: https://github.com/miaoxworld/ClawdBotInstaller                 ║
# ║   官方文档: https://clawd.bot/docs                                         ║
# ║                                                                           ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
#
# 使用方法:
#   curl -fsSL https://raw.githubusercontent.com/miaoxworld/ClawdBotInstaller/main/install.sh | bash
#   或本地执行: chmod +x install.sh && ./install.sh
#

set -e

# ================================ 颜色定义 ================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # 无颜色

# ================================ 配置变量 ================================
CLAWDBOT_VERSION="latest"
CONFIG_DIR="$HOME/.clawd"
LOG_DIR="$CONFIG_DIR/logs"
DATA_DIR="$CONFIG_DIR/data"
SKILLS_DIR="$CONFIG_DIR/skills"
MIN_NODE_VERSION=22
GITHUB_REPO="miaoxworld/ClawdBotInstaller"
GITHUB_RAW_URL="https://raw.githubusercontent.com/$GITHUB_REPO/main"

# ================================ 工具函数 ================================

print_banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
    
     ██████╗██╗      █████╗ ██╗    ██╗██████╗ ██████╗  ██████╗ ████████╗
    ██╔════╝██║     ██╔══██╗██║    ██║██╔══██╗██╔══██╗██╔═══██╗╚══██╔══╝
    ██║     ██║     ███████║██║ █╗ ██║██║  ██║██████╔╝██║   ██║   ██║   
    ██║     ██║     ██╔══██║██║███╗██║██║  ██║██╔══██╗██║   ██║   ██║   
    ╚██████╗███████╗██║  ██║╚███╔███╔╝██████╔╝██████╔╝╚██████╔╝   ██║   
     ╚═════╝╚══════╝╚═╝  ╚═╝ ╚══╝╚══╝ ╚═════╝ ╚═════╝  ╚═════╝    ╚═╝   
                                                                         
              🦞 智能 AI 助手一键部署工具 v1.0.0 🦞
    
EOF
    echo -e "${NC}"
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

confirm() {
    local message="$1"
    local default="${2:-y}"
    
    if [ "$default" = "y" ]; then
        local prompt="[Y/n]"
    else
        local prompt="[y/N]"
    fi
    
    read -p "$(echo -e "${YELLOW}$message $prompt: ${NC}")" response
    response=${response:-$default}
    
    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}

# ================================ 系统检测 ================================

detect_os() {
    log_step "检测操作系统..."
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            OS=$ID
            OS_VERSION=$VERSION_ID
        fi
        PACKAGE_MANAGER=""
        if command -v apt-get &> /dev/null; then
            PACKAGE_MANAGER="apt"
        elif command -v yum &> /dev/null; then
            PACKAGE_MANAGER="yum"
        elif command -v dnf &> /dev/null; then
            PACKAGE_MANAGER="dnf"
        elif command -v pacman &> /dev/null; then
            PACKAGE_MANAGER="pacman"
        fi
        log_info "检测到 Linux 系统: $OS $OS_VERSION (包管理器: $PACKAGE_MANAGER)"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        OS_VERSION=$(sw_vers -productVersion)
        PACKAGE_MANAGER="brew"
        log_info "检测到 macOS 系统: $OS_VERSION"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        OS="windows"
        log_info "检测到 Windows 系统 (Git Bash/Cygwin)"
    else
        log_error "不支持的操作系统: $OSTYPE"
        exit 1
    fi
}

check_root() {
    if [[ "$OS" != "macos" ]] && [[ $EUID -eq 0 ]]; then
        log_warn "检测到以 root 用户运行"
        if ! confirm "建议使用普通用户运行，是否继续？" "n"; then
            exit 1
        fi
    fi
}

# ================================ 依赖检查与安装 ================================

check_command() {
    command -v "$1" &> /dev/null
}

install_homebrew() {
    if ! check_command brew; then
        log_step "安装 Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # 添加到 PATH
        if [[ -f /opt/homebrew/bin/brew ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -f /usr/local/bin/brew ]]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    fi
}

install_nodejs() {
    log_step "检查 Node.js..."
    
    if check_command node; then
        local node_version=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
        if [ "$node_version" -ge "$MIN_NODE_VERSION" ]; then
            log_info "Node.js 版本满足要求: $(node -v)"
            return 0
        else
            log_warn "Node.js 版本过低: $(node -v)，需要 v$MIN_NODE_VERSION+"
        fi
    fi
    
    log_step "安装 Node.js $MIN_NODE_VERSION..."
    
    case "$OS" in
        macos)
            install_homebrew
            brew install node@22
            brew link --overwrite node@22
            ;;
        ubuntu|debian)
            curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
            sudo apt-get install -y nodejs
            ;;
        centos|rhel|fedora)
            curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo bash -
            sudo yum install -y nodejs
            ;;
        arch|manjaro)
            sudo pacman -S nodejs npm --noconfirm
            ;;
        *)
            log_error "无法自动安装 Node.js，请手动安装 v$MIN_NODE_VERSION+"
            exit 1
            ;;
    esac
    
    log_info "Node.js 安装完成: $(node -v)"
}

install_git() {
    if ! check_command git; then
        log_step "安装 Git..."
        case "$OS" in
            macos)
                install_homebrew
                brew install git
                ;;
            ubuntu|debian)
                sudo apt-get update && sudo apt-get install -y git
                ;;
            centos|rhel|fedora)
                sudo yum install -y git
                ;;
            arch|manjaro)
                sudo pacman -S git --noconfirm
                ;;
        esac
    fi
    log_info "Git 版本: $(git --version)"
}

install_dependencies() {
    log_step "检查并安装依赖..."
    
    # 安装基础依赖
    case "$OS" in
        ubuntu|debian)
            sudo apt-get update
            sudo apt-get install -y curl wget jq
            ;;
        centos|rhel|fedora)
            sudo yum install -y curl wget jq
            ;;
        macos)
            install_homebrew
            brew install curl wget jq
            ;;
    esac
    
    install_git
    install_nodejs
}

# ================================ ClawdBot 安装 ================================

create_directories() {
    log_step "创建配置目录..."
    
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$LOG_DIR"
    mkdir -p "$DATA_DIR"
    mkdir -p "$SKILLS_DIR"
    
    log_info "配置目录: $CONFIG_DIR"
}

install_clawdbot() {
    log_step "安装 ClawdBot..."
    
    # 检查是否已安装
    if check_command clawdbot; then
        local current_version=$(clawdbot --version 2>/dev/null || echo "unknown")
        log_warn "ClawdBot 已安装 (版本: $current_version)"
        if ! confirm "是否重新安装/更新？"; then
            return 0
        fi
    fi
    
    # 使用 npm 全局安装
    log_info "正在从 npm 安装 ClawdBot..."
    npm install -g clawdbot@$CLAWDBOT_VERSION
    
    # 验证安装
    if check_command clawdbot; then
        log_info "ClawdBot 安装成功: $(clawdbot --version 2>/dev/null || echo 'installed')"
    else
        log_error "ClawdBot 安装失败"
        exit 1
    fi
}

# ================================ 配置向导 ================================

create_default_config() {
    log_step "创建默认配置文件..."
    
    cat > "$CONFIG_DIR/config.yaml" << 'EOF'
# ClawdBot 配置文件
# 详细文档: https://clawd.bot/docs/config

# ====== 基础配置 ======
version: "1.0"
debug: false

# ====== AI 模型配置 ======
# 支持: anthropic, openai, ollama
llm:
  provider: anthropic
  # api_key: "your-api-key-here"  # 请填入你的 API Key
  model: claude-sonnet-4-20250514
  max_tokens: 4096
  temperature: 0.7

# ====== 身份配置 ======
identity:
  bot_name: "Clawd"
  user_name: "主人"
  timezone: "Asia/Shanghai"
  language: "zh-CN"
  personality: |
    你是一个聪明、幽默、有创造力的AI助手。
    你善于分析问题，提供有见地的建议。
    你的回复简洁有力，避免冗长。

# ====== 网关配置 ======
gateway:
  host: "127.0.0.1"
  port: 18789

# ====== 渠道配置 ======
channels:
  # Telegram 配置
  # telegram:
  #   enabled: false
  #   token: "your-bot-token"
  #   allowed_users:
  #     - "your-user-id"

  # Discord 配置
  # discord:
  #   enabled: false
  #   token: "your-bot-token"
  #   channels:
  #     - "channel-id"

  # WhatsApp 配置
  # whatsapp:
  #   enabled: false

# ====== 记忆系统 ======
memory:
  enabled: true
  storage_path: "~/.clawd/data/memory"
  max_context_length: 32000

# ====== Skills 技能 ======
skills:
  enabled: true
  path: "~/.clawd/skills"
  
# ====== 安全配置 ======
security:
  enable_shell_commands: false
  enable_file_access: false
  enable_web_browsing: true
  sandbox_mode: true

# ====== 日志配置 ======
logging:
  level: "info"
  path: "~/.clawd/logs"
  max_size: "10MB"
  max_files: 5
EOF

    log_info "配置文件已创建: $CONFIG_DIR/config.yaml"
}

create_example_skill() {
    log_step "创建示例技能..."
    
    cat > "$SKILLS_DIR/daily-report.md" << 'EOF'
# 每日报告技能

## 描述
生成每日工作报告和待办事项总结。

## 触发条件
- 用户说 "生成日报" 或 "每日报告"
- 每天晚上 8 点自动触发

## 执行步骤
1. 收集今日完成的任务
2. 列出未完成的待办事项
3. 总结今日的重要信息
4. 生成明日工作计划建议

## 输出格式
```
📅 {日期} 每日报告

✅ 今日完成:
{完成的任务列表}

📋 待办事项:
{未完成的任务}

💡 明日建议:
{明日计划}
```
EOF

    log_info "示例技能已创建: $SKILLS_DIR/daily-report.md"
}

run_onboard_wizard() {
    log_step "运行配置向导..."
    
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}           🧙 ClawdBot 核心配置向导${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # 检查是否已有配置
    local has_existing_config=false
    local skip_ai_config=false
    local skip_identity_config=false
    
    if [ -f "$CONFIG_DIR/config.yaml" ]; then
        has_existing_config=true
        
        # 读取现有配置
        EXISTING_PROVIDER=$(grep "^  provider:" "$CONFIG_DIR/config.yaml" | head -1 | awk '{print $2}' | tr -d '"')
        EXISTING_MODEL=$(grep "^  model:" "$CONFIG_DIR/config.yaml" | head -1 | awk '{print $2}' | tr -d '"')
        EXISTING_BASE_URL=$(grep "^  base_url:" "$CONFIG_DIR/config.yaml" | head -1 | sed 's/.*base_url:[[:space:]]*//' | tr -d '"')
        EXISTING_API_KEY=$(grep "^  api_key:" "$CONFIG_DIR/config.yaml" | head -1 | sed 's/.*api_key:[[:space:]]*//' | tr -d '"')
        EXISTING_BOT_NAME=$(grep "^  bot_name:" "$CONFIG_DIR/config.yaml" | head -1 | sed 's/.*bot_name:[[:space:]]*//' | tr -d '"')
        EXISTING_USER_NAME=$(grep "^  user_name:" "$CONFIG_DIR/config.yaml" | head -1 | sed 's/.*user_name:[[:space:]]*//' | tr -d '"')
        EXISTING_TIMEZONE=$(grep "^  timezone:" "$CONFIG_DIR/config.yaml" | head -1 | sed 's/.*timezone:[[:space:]]*//' | tr -d '"')
        
        echo -e "${YELLOW}检测到已有配置文件！${NC}"
        echo ""
        echo -e "${CYAN}当前 AI 配置:${NC}"
        echo -e "  提供商: ${WHITE}${EXISTING_PROVIDER:-未配置}${NC}"
        echo -e "  模型: ${WHITE}${EXISTING_MODEL:-未配置}${NC}"
        [ -n "$EXISTING_BASE_URL" ] && echo -e "  API 地址: ${WHITE}$EXISTING_BASE_URL${NC}"
        if [ -n "$EXISTING_API_KEY" ] && [ "$EXISTING_API_KEY" != "your-api-key-here" ]; then
            echo -e "  API Key: ${WHITE}${EXISTING_API_KEY:0:10}...${NC}"
        fi
        echo ""
        echo -e "${CYAN}当前身份配置:${NC}"
        echo -e "  助手名称: ${WHITE}${EXISTING_BOT_NAME:-未配置}${NC}"
        echo -e "  你的称呼: ${WHITE}${EXISTING_USER_NAME:-未配置}${NC}"
        echo -e "  时区: ${WHITE}${EXISTING_TIMEZONE:-未配置}${NC}"
        echo ""
        
        # 询问是否重新配置 AI
        if [ -n "$EXISTING_PROVIDER" ] && [ -n "$EXISTING_API_KEY" ] && [ "$EXISTING_API_KEY" != "your-api-key-here" ]; then
            if ! confirm "是否重新配置 AI 模型提供商？" "n"; then
                skip_ai_config=true
                # 使用现有配置
                AI_PROVIDER="$EXISTING_PROVIDER"
                AI_MODEL="$EXISTING_MODEL"
                BASE_URL="$EXISTING_BASE_URL"
                AI_KEY="$EXISTING_API_KEY"
                log_info "使用现有 AI 配置"
            fi
        fi
        
        # 询问是否重新配置身份
        if [ -n "$EXISTING_BOT_NAME" ]; then
            if ! confirm "是否重新配置身份信息？" "n"; then
                skip_identity_config=true
                # 使用现有配置
                BOT_NAME="$EXISTING_BOT_NAME"
                USER_NAME="$EXISTING_USER_NAME"
                TIMEZONE="$EXISTING_TIMEZONE"
                log_info "使用现有身份配置"
            fi
        fi
        
        echo ""
    else
        echo -e "${CYAN}接下来将引导你完成核心配置，包括:${NC}"
        echo "  1. 选择 AI 模型提供商"
        echo "  2. 配置 API 连接"
        echo "  3. 测试 API 连接"
        echo "  4. 设置基本身份信息"
        echo ""
    fi
    
    # AI 配置
    if [ "$skip_ai_config" = false ]; then
        setup_ai_provider
        test_api_connection
    else
        # 即使跳过配置，也可选择测试连接
        if confirm "是否测试现有 API 连接？" "y"; then
            test_api_connection
        fi
    fi
    
    # 身份配置
    if [ "$skip_identity_config" = false ]; then
        setup_identity
    else
        # 初始化渠道配置变量
        TELEGRAM_ENABLED="false"
        DISCORD_ENABLED="false"
        SHELL_ENABLED="false"
        FILE_ACCESS="false"
    fi
    
    # 生成配置文件
    generate_config_file
    
    # 创建示例技能（如果不存在）
    if [ ! -f "$SKILLS_DIR/daily-report.md" ]; then
        create_example_skill
    fi
    
    log_info "核心配置完成！"
}

# ================================ AI Provider 配置 ================================

setup_ai_provider() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}  第 1 步: 选择 AI 模型提供商${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "  1) 🟣 Anthropic Claude (官方)"
    echo "  2) 🟢 OpenAI GPT (官方)"
    echo "  3) 🔄 OpenAI Compatible (通用兼容接口) ⭐ 推荐"
    echo "  4) 🟠 Ollama (本地模型)"
    echo "  5) 🔵 OpenRouter (多模型网关)"
    echo "  6) 🔴 Google Gemini"
    echo "  7) ⚡ Groq (超快推理)"
    echo "  8) 🌬️ Mistral AI"
    echo ""
    read -p "$(echo -e "${YELLOW}请选择 AI 提供商 [1-8] (默认: 3): ${NC}")" ai_choice
    ai_choice=${ai_choice:-3}
    
    case $ai_choice in
        1)
            AI_PROVIDER="anthropic"
            BASE_URL=""
            echo ""
            echo -e "${CYAN}配置 Anthropic Claude${NC}"
            echo -e "${GRAY}获取 API Key: https://console.anthropic.com/${NC}"
            echo ""
            read -p "$(echo -e "${YELLOW}输入 Claude API Key: ${NC}")" AI_KEY
            echo ""
            echo "选择模型:"
            echo "  1) claude-sonnet-4-20250514 (推荐，平衡性能)"
            echo "  2) claude-opus-4-20250514 (最强性能)"
            echo "  3) claude-3-5-haiku-20241022 (快速经济)"
            read -p "$(echo -e "${YELLOW}选择模型 [1-3] (默认: 1): ${NC}")" model_choice
            case $model_choice in
                2) AI_MODEL="claude-opus-4-20250514" ;;
                3) AI_MODEL="claude-3-5-haiku-20241022" ;;
                *) AI_MODEL="claude-sonnet-4-20250514" ;;
            esac
            ;;
        2)
            AI_PROVIDER="openai"
            BASE_URL=""
            echo ""
            echo -e "${CYAN}配置 OpenAI GPT${NC}"
            echo -e "${GRAY}获取 API Key: https://platform.openai.com/${NC}"
            echo ""
            read -p "$(echo -e "${YELLOW}输入 OpenAI API Key: ${NC}")" AI_KEY
            echo ""
            echo "选择模型:"
            echo "  1) gpt-4o (推荐)"
            echo "  2) gpt-4o-mini (经济)"
            echo "  3) gpt-4-turbo"
            read -p "$(echo -e "${YELLOW}选择模型 [1-3] (默认: 1): ${NC}")" model_choice
            case $model_choice in
                2) AI_MODEL="gpt-4o-mini" ;;
                3) AI_MODEL="gpt-4-turbo" ;;
                *) AI_MODEL="gpt-4o" ;;
            esac
            ;;
        3)
            AI_PROVIDER="openai-compatible"
            echo ""
            echo -e "${CYAN}配置 OpenAI Compatible (通用兼容接口)${NC}"
            echo -e "${GRAY}适用于 OneAPI, New API, 各种代理服务等${NC}"
            echo ""
            read -p "$(echo -e "${YELLOW}输入 API 地址 (如 https://api.example.com/v1): ${NC}")" BASE_URL
            while [ -z "$BASE_URL" ]; do
                echo -e "${RED}API 地址不能为空！${NC}"
                read -p "$(echo -e "${YELLOW}输入 API 地址: ${NC}")" BASE_URL
            done
            echo ""
            read -p "$(echo -e "${YELLOW}输入 API Key: ${NC}")" AI_KEY
            while [ -z "$AI_KEY" ]; do
                echo -e "${RED}API Key 不能为空！${NC}"
                read -p "$(echo -e "${YELLOW}输入 API Key: ${NC}")" AI_KEY
            done
            echo ""
            echo "选择或输入模型:"
            echo "  1) claude-sonnet-4.5"
            echo "  2) claude-sonnet-4"
            echo "  3) gpt-4o"
            echo "  4) gpt-4o-mini"
            echo "  5) 自定义模型名称"
            read -p "$(echo -e "${YELLOW}选择模型 [1-5] (默认: 1): ${NC}")" model_choice
            case $model_choice in
                2) AI_MODEL="claude-sonnet-4" ;;
                3) AI_MODEL="gpt-4o" ;;
                4) AI_MODEL="gpt-4o-mini" ;;
                5) 
                    read -p "$(echo -e "${YELLOW}输入模型名称: ${NC}")" AI_MODEL
                    ;;
                *) AI_MODEL="claude-sonnet-4.5" ;;
            esac
            ;;
        4)
            AI_PROVIDER="ollama"
            AI_KEY=""
            echo ""
            echo -e "${CYAN}配置 Ollama 本地模型${NC}"
            echo ""
            read -p "$(echo -e "${YELLOW}Ollama 地址 (默认: http://localhost:11434): ${NC}")" BASE_URL
            BASE_URL=${BASE_URL:-"http://localhost:11434"}
            echo ""
            echo "选择模型:"
            echo "  1) llama3"
            echo "  2) llama3:70b"
            echo "  3) mistral"
            echo "  4) 自定义"
            read -p "$(echo -e "${YELLOW}选择模型 [1-4] (默认: 1): ${NC}")" model_choice
            case $model_choice in
                2) AI_MODEL="llama3:70b" ;;
                3) AI_MODEL="mistral" ;;
                4) read -p "$(echo -e "${YELLOW}输入模型名称: ${NC}")" AI_MODEL ;;
                *) AI_MODEL="llama3" ;;
            esac
            ;;
        5)
            AI_PROVIDER="openrouter"
            BASE_URL="https://openrouter.ai/api/v1"
            echo ""
            echo -e "${CYAN}配置 OpenRouter${NC}"
            echo -e "${GRAY}获取 API Key: https://openrouter.ai/${NC}"
            echo ""
            read -p "$(echo -e "${YELLOW}输入 OpenRouter API Key: ${NC}")" AI_KEY
            AI_MODEL="anthropic/claude-sonnet-4"
            ;;
        6)
            AI_PROVIDER="google"
            BASE_URL=""
            echo ""
            echo -e "${CYAN}配置 Google Gemini${NC}"
            echo -e "${GRAY}获取 API Key: https://makersuite.google.com/app/apikey${NC}"
            echo ""
            read -p "$(echo -e "${YELLOW}输入 Google API Key: ${NC}")" AI_KEY
            AI_MODEL="gemini-2.0-flash"
            ;;
        7)
            AI_PROVIDER="groq"
            BASE_URL="https://api.groq.com/openai/v1"
            echo ""
            echo -e "${CYAN}配置 Groq${NC}"
            echo -e "${GRAY}获取 API Key: https://console.groq.com/${NC}"
            echo ""
            read -p "$(echo -e "${YELLOW}输入 Groq API Key: ${NC}")" AI_KEY
            AI_MODEL="llama-3.3-70b-versatile"
            ;;
        8)
            AI_PROVIDER="mistral"
            BASE_URL="https://api.mistral.ai/v1"
            echo ""
            echo -e "${CYAN}配置 Mistral AI${NC}"
            echo -e "${GRAY}获取 API Key: https://console.mistral.ai/${NC}"
            echo ""
            read -p "$(echo -e "${YELLOW}输入 Mistral API Key: ${NC}")" AI_KEY
            AI_MODEL="mistral-large-latest"
            ;;
        *)
            # 默认使用 OpenAI Compatible
            AI_PROVIDER="openai-compatible"
            echo ""
            echo -e "${CYAN}配置 OpenAI Compatible${NC}"
            read -p "$(echo -e "${YELLOW}输入 API 地址: ${NC}")" BASE_URL
            read -p "$(echo -e "${YELLOW}输入 API Key: ${NC}")" AI_KEY
            AI_MODEL="claude-sonnet-4.5"
            ;;
    esac
    
    echo ""
    log_info "AI Provider 配置完成"
    echo -e "  提供商: ${WHITE}$AI_PROVIDER${NC}"
    echo -e "  模型: ${WHITE}$AI_MODEL${NC}"
    [ -n "$BASE_URL" ] && echo -e "  API 地址: ${WHITE}$BASE_URL${NC}"
}

# ================================ API 连接测试 ================================

test_api_connection() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}  第 2 步: 测试 API 连接${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    local test_url=""
    local test_passed=false
    local max_retries=3
    local retry_count=0
    
    while [ "$test_passed" = false ] && [ $retry_count -lt $max_retries ]; do
        echo -e "${YELLOW}正在测试 API 连接...${NC}"
        echo ""
        
        # 确定测试 URL
        case "$AI_PROVIDER" in
            anthropic)
                test_url="https://api.anthropic.com/v1/messages"
                # Anthropic 使用不同的 API 格式
                RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$test_url" \
                    -H "Content-Type: application/json" \
                    -H "x-api-key: $AI_KEY" \
                    -H "anthropic-version: 2023-06-01" \
                    -d "{
                        \"model\": \"$AI_MODEL\",
                        \"max_tokens\": 50,
                        \"messages\": [{\"role\": \"user\", \"content\": \"Say OK\"}]
                    }" 2>/dev/null)
                ;;
            google)
                test_url="https://generativelanguage.googleapis.com/v1beta/models/$AI_MODEL:generateContent?key=$AI_KEY"
                RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$test_url" \
                    -H "Content-Type: application/json" \
                    -d "{
                        \"contents\": [{\"parts\":[{\"text\": \"Say OK\"}]}]
                    }" 2>/dev/null)
                ;;
            *)
                # OpenAI 兼容格式 (openai, openai-compatible, ollama, openrouter, groq, mistral)
                if [ -n "$BASE_URL" ]; then
                    test_url="${BASE_URL}/chat/completions"
                else
                    test_url="https://api.openai.com/v1/chat/completions"
                fi
                
                RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$test_url" \
                    -H "Content-Type: application/json" \
                    -H "Authorization: Bearer $AI_KEY" \
                    -d "{
                        \"model\": \"$AI_MODEL\",
                        \"messages\": [{\"role\": \"user\", \"content\": \"请只回复: 连接测试成功\"}],
                        \"max_tokens\": 50
                    }" 2>/dev/null)
                ;;
        esac
        
        # 提取 HTTP 状态码和响应体
        HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
        RESPONSE_BODY=$(echo "$RESPONSE" | sed '$d')
        
        # 检查响应
        if [ "$HTTP_CODE" = "200" ]; then
            test_passed=true
            echo -e "${GREEN}✓ API 连接测试成功！${NC}"
            echo ""
            
            # 尝试解析并显示响应
            if command -v python3 &> /dev/null; then
                AI_RESPONSE=$(echo "$RESPONSE_BODY" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    if 'choices' in d:
        print(d['choices'][0].get('message', {}).get('content', ''))
    elif 'content' in d:
        print(d['content'][0].get('text', ''))
    elif 'candidates' in d:
        print(d['candidates'][0]['content']['parts'][0]['text'])
except:
    print('')
" 2>/dev/null)
                if [ -n "$AI_RESPONSE" ]; then
                    echo -e "  AI 响应: ${CYAN}$AI_RESPONSE${NC}"
                fi
            fi
            echo ""
        else
            retry_count=$((retry_count + 1))
            echo -e "${RED}✗ API 连接测试失败 (HTTP $HTTP_CODE)${NC}"
            echo ""
            
            # 显示错误信息
            if command -v python3 &> /dev/null; then
                ERROR_MSG=$(echo "$RESPONSE_BODY" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    if 'error' in d:
        err = d['error']
        if isinstance(err, dict):
            print(err.get('message', str(err)))
        else:
            print(str(err))
except:
    print('无法解析错误信息')
" 2>/dev/null)
                echo -e "  错误信息: ${RED}$ERROR_MSG${NC}"
            fi
            echo ""
            
            if [ $retry_count -lt $max_retries ]; then
                echo -e "${YELLOW}请检查配置并重试 (剩余 $((max_retries - retry_count)) 次机会)${NC}"
                echo ""
                echo "常见问题:"
                echo "  1. API Key 是否正确"
                echo "  2. API 地址是否正确"
                echo "  3. 模型名称是否支持"
                echo "  4. 网络是否可访问"
                echo ""
                
                if confirm "是否重新配置 AI Provider？" "y"; then
                    setup_ai_provider
                else
                    echo -e "${YELLOW}继续使用当前配置...${NC}"
                    test_passed=true  # 允许跳过
                fi
            fi
        fi
    done
    
    if [ "$test_passed" = false ]; then
        echo -e "${RED}API 连接测试失败次数过多${NC}"
        if confirm "是否仍然继续安装？(稍后可手动修改配置)" "y"; then
            log_warn "跳过连接测试，继续安装..."
        else
            echo "安装已取消"
            exit 1
        fi
    fi
}

# ================================ 身份配置 ================================

setup_identity() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}  第 3 步: 设置身份信息${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    read -p "$(echo -e "${YELLOW}给你的 AI 助手起个名字 (默认: Clawd): ${NC}")" BOT_NAME
    BOT_NAME=${BOT_NAME:-"Clawd"}
    
    read -p "$(echo -e "${YELLOW}AI 如何称呼你 (默认: 主人): ${NC}")" USER_NAME
    USER_NAME=${USER_NAME:-"主人"}
    
    read -p "$(echo -e "${YELLOW}你的时区 (默认: Asia/Shanghai): ${NC}")" TIMEZONE
    TIMEZONE=${TIMEZONE:-"Asia/Shanghai"}
    
    echo ""
    log_info "身份配置完成"
    echo -e "  助手名称: ${WHITE}$BOT_NAME${NC}"
    echo -e "  你的称呼: ${WHITE}$USER_NAME${NC}"
    echo -e "  时区: ${WHITE}$TIMEZONE${NC}"
    
    # 初始化渠道配置变量
    TELEGRAM_ENABLED="false"
    DISCORD_ENABLED="false"
    SHELL_ENABLED="false"
    FILE_ACCESS="false"
}

generate_config_file() {
    cat > "$CONFIG_DIR/config.yaml" << EOF
# ClawdBot 配置文件
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')

version: "1.0"
debug: false

# AI 模型配置
llm:
  provider: $AI_PROVIDER
  api_key: "$AI_KEY"
  model: $AI_MODEL
  max_tokens: 4096
  temperature: 0.7
EOF

    # 添加 base_url（用于 OpenAI Compatible、Ollama、Groq、Mistral 等）
    if [ -n "$BASE_URL" ]; then
        echo "  base_url: \"$BASE_URL\"" >> "$CONFIG_DIR/config.yaml"
    fi

    cat >> "$CONFIG_DIR/config.yaml" << EOF

# 身份配置
identity:
  bot_name: "$BOT_NAME"
  user_name: "$USER_NAME"
  timezone: "$TIMEZONE"
  language: "zh-CN"
  personality: |
    你是一个聪明、幽默、有创造力的AI助手。
    你善于分析问题，提供有见地的建议。
    你的回复简洁有力，避免冗长。

# 网关配置
gateway:
  host: "127.0.0.1"
  port: 18789

# 渠道配置
channels:
EOF

    if [ "$TELEGRAM_ENABLED" = "true" ]; then
        cat >> "$CONFIG_DIR/config.yaml" << EOF
  telegram:
    enabled: true
    token: "$TELEGRAM_TOKEN"
    allowed_users:
      - "$TELEGRAM_USER_ID"
EOF
    fi

    if [ "$DISCORD_ENABLED" = "true" ]; then
        cat >> "$CONFIG_DIR/config.yaml" << EOF
  discord:
    enabled: true
    token: "$DISCORD_TOKEN"
    channels:
      - "$DISCORD_CHANNEL_ID"
EOF
    fi

    cat >> "$CONFIG_DIR/config.yaml" << EOF

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
  enable_shell_commands: $SHELL_ENABLED
  enable_file_access: $FILE_ACCESS
  enable_web_browsing: true
  sandbox_mode: true

# 日志配置
logging:
  level: "info"
  path: "~/.clawd/logs"
  max_size: "10MB"
  max_files: 5
EOF

    log_info "配置文件已生成: $CONFIG_DIR/config.yaml"
}

# ================================ 服务管理 ================================

setup_daemon() {
    if confirm "是否设置开机自启动？" "y"; then
        log_step "配置系统服务..."
        
        case "$OS" in
            macos)
                setup_launchd
                ;;
            *)
                setup_systemd
                ;;
        esac
    fi
}

setup_systemd() {
    cat > /tmp/clawdbot.service << EOF
[Unit]
Description=ClawdBot AI Assistant
After=network.target

[Service]
Type=simple
User=$USER
ExecStart=$(which clawdbot) start --daemon
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    sudo mv /tmp/clawdbot.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable clawdbot
    
    log_info "Systemd 服务已配置"
}

setup_launchd() {
    mkdir -p "$HOME/Library/LaunchAgents"
    
    cat > "$HOME/Library/LaunchAgents/com.clawdbot.agent.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.clawdbot.agent</string>
    <key>ProgramArguments</key>
    <array>
        <string>$(which clawdbot)</string>
        <string>start</string>
        <string>--daemon</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$LOG_DIR/stdout.log</string>
    <key>StandardErrorPath</key>
    <string>$LOG_DIR/stderr.log</string>
</dict>
</plist>
EOF

    launchctl load "$HOME/Library/LaunchAgents/com.clawdbot.agent.plist" 2>/dev/null || true
    
    log_info "LaunchAgent 已配置"
}

# ================================ 完成安装 ================================

print_success() {
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}                    🎉 安装完成！🎉${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${WHITE}配置文件位置:${NC} $CONFIG_DIR/config.yaml"
    echo -e "${WHITE}日志文件位置:${NC} $LOG_DIR/"
    echo -e "${WHITE}技能目录位置:${NC} $SKILLS_DIR/"
    echo ""
    echo -e "${CYAN}常用命令:${NC}"
    echo "  clawdbot start       # 启动服务"
    echo "  clawdbot stop        # 停止服务"
    echo "  clawdbot status      # 查看状态"
    echo "  clawdbot logs        # 查看日志"
    echo "  clawdbot config      # 编辑配置"
    echo "  clawdbot doctor      # 诊断问题"
    echo ""
    echo -e "${PURPLE}📚 官方文档: https://clawd.bot/docs${NC}"
    echo -e "${PURPLE}💬 社区支持: https://github.com/$GITHUB_REPO/discussions${NC}"
    echo ""
}

# 下载并运行配置菜单
run_config_menu() {
    local config_menu_path="$CONFIG_DIR/config-menu.sh"
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local local_config_menu="$script_dir/config-menu.sh"
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}           🔧 启动配置菜单${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # 优先使用本地的 config-menu.sh
    if [ -f "$local_config_menu" ]; then
        log_info "使用本地配置菜单: $local_config_menu"
        chmod +x "$local_config_menu"
        bash "$local_config_menu"
        return $?
    fi
    
    # 检查配置目录中是否已有
    if [ -f "$config_menu_path" ]; then
        log_info "使用已下载的配置菜单"
        chmod +x "$config_menu_path"
        bash "$config_menu_path"
        return $?
    fi
    
    # 从 GitHub 下载
    log_step "从 GitHub 下载配置菜单..."
    if curl -fsSL "$GITHUB_RAW_URL/config-menu.sh" -o "$config_menu_path"; then
        chmod +x "$config_menu_path"
        log_info "配置菜单下载成功"
        bash "$config_menu_path"
        return $?
    else
        log_error "配置菜单下载失败"
        echo -e "${YELLOW}你可以稍后手动下载运行:${NC}"
        echo "  curl -fsSL $GITHUB_RAW_URL/config-menu.sh | bash"
        return 1
    fi
}

# ================================ 主函数 ================================

main() {
    print_banner
    
    echo -e "${YELLOW}⚠️  警告: ClawdBot 需要完全的计算机权限${NC}"
    echo -e "${YELLOW}    不建议在主要工作电脑上安装，建议使用专用服务器或虚拟机${NC}"
    echo ""
    
    if ! confirm "是否继续安装？"; then
        echo "安装已取消"
        exit 0
    fi
    
    echo ""
    detect_os
    check_root
    install_dependencies
    create_directories
    install_clawdbot
    run_onboard_wizard
    setup_daemon
    print_success
    
    # 安装完成后自动运行配置菜单
    if confirm "是否打开配置菜单进行详细配置？" "y"; then
        run_config_menu
    else
        echo ""
        echo -e "${CYAN}稍后可以通过以下命令打开配置菜单:${NC}"
        echo "  bash $CONFIG_DIR/config-menu.sh"
        echo "  # 或从 GitHub 下载运行:"
        echo "  curl -fsSL $GITHUB_RAW_URL/config-menu.sh | bash"
        echo ""
    fi
}

# 执行主函数
main "$@"
