#!/bin/bash
#
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                                                                           ║
# ║   🦞 ClawdBot 交互式配置菜单 v1.0.0                                        ║
# ║   便捷的可视化配置工具                                                      ║
# ║                                                                           ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
#

# ================================ 颜色定义 ================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'

# 背景色
BG_BLUE='\033[44m'
BG_GREEN='\033[42m'
BG_RED='\033[41m'

# ================================ 配置变量 ================================
CONFIG_DIR="$HOME/.clawd"
CONFIG_FILE="$CONFIG_DIR/config.yaml"
LOG_DIR="$CONFIG_DIR/logs"
DATA_DIR="$CONFIG_DIR/data"
SKILLS_DIR="$CONFIG_DIR/skills"
BACKUP_DIR="$CONFIG_DIR/backups"

# ================================ 工具函数 ================================

clear_screen() {
    clear
}

print_header() {
    echo -e "${CYAN}"
    cat << 'EOF'
    ╔═══════════════════════════════════════════════════════════════╗
    ║                                                               ║
    ║   🦞 ClawdBot 配置中心                                         ║
    ║                                                               ║
    ╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

print_divider() {
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_menu_item() {
    local num=$1
    local text=$2
    local icon=$3
    echo -e "  ${CYAN}[$num]${NC} $icon $text"
}

log_info() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

press_enter() {
    echo ""
    read -p "$(echo -e "${GRAY}按 Enter 键继续...${NC}")"
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

# 检查依赖
check_dependencies() {
    if ! command -v yq &> /dev/null; then
        # 使用简单的 sed/grep 处理 yaml
        USE_YQ=false
    else
        USE_YQ=true
    fi
}

# 备份配置
backup_config() {
    mkdir -p "$BACKUP_DIR"
    local backup_file="$BACKUP_DIR/config_$(date +%Y%m%d_%H%M%S).yaml"
    if [ -f "$CONFIG_FILE" ]; then
        cp "$CONFIG_FILE" "$backup_file"
        echo "$backup_file"
    fi
}

# 读取配置值
get_config_value() {
    local key=$1
    if [ -f "$CONFIG_FILE" ]; then
        grep -E "^[[:space:]]*$key:" "$CONFIG_FILE" | head -1 | sed 's/.*:[[:space:]]*//' | tr -d '"' | tr -d "'"
    fi
}

# 更新配置值
update_config_value() {
    local key=$1
    local value=$2
    local file=$CONFIG_FILE
    
    if grep -q "^[[:space:]]*$key:" "$file"; then
        # macOS 和 Linux 兼容的 sed
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|^\([[:space:]]*$key:\).*|\1 \"$value\"|" "$file"
        else
            sed -i "s|^\([[:space:]]*$key:\).*|\1 \"$value\"|" "$file"
        fi
    fi
}

# ================================ 测试功能 ================================

# 检查 ClawdBot 是否已安装
check_clawdbot_installed() {
    command -v clawdbot &> /dev/null
}

# 检查 ClawdBot Gateway 是否运行
check_gateway_running() {
    if check_clawdbot_installed; then
        clawdbot health &>/dev/null
        return $?
    fi
    return 1
}

# 测试 AI API 连接
test_ai_connection() {
    local provider=$1
    local api_key=$2
    local model=$3
    local base_url=$4
    
    echo ""
    echo -e "${CYAN}━━━ 测试 AI API 连接 ━━━${NC}"
    echo ""
    
    echo -e "${YELLOW}正在测试 API 连接...${NC}"
    echo ""
    
    local test_url=""
    local response=""
    
    case "$provider" in
        anthropic)
            test_url="https://api.anthropic.com/v1/messages"
            response=$(curl -s -w "\n%{http_code}" -X POST "$test_url" \
                -H "Content-Type: application/json" \
                -H "x-api-key: $api_key" \
                -H "anthropic-version: 2023-06-01" \
                -d "{
                    \"model\": \"$model\",
                    \"max_tokens\": 50,
                    \"messages\": [{\"role\": \"user\", \"content\": \"请回复: 连接成功\"}]
                }" 2>/dev/null)
            ;;
        google)
            test_url="https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$api_key"
            response=$(curl -s -w "\n%{http_code}" -X POST "$test_url" \
                -H "Content-Type: application/json" \
                -d "{
                    \"contents\": [{\"parts\":[{\"text\": \"请回复: 连接成功\"}]}]
                }" 2>/dev/null)
            ;;
        ollama)
            test_ollama_connection "$base_url" "$model"
            return $?
            ;;
        *)
            # OpenAI 兼容格式
            if [ -n "$base_url" ]; then
                test_url="${base_url}/chat/completions"
            else
                test_url="https://api.openai.com/v1/chat/completions"
            fi
            
            response=$(curl -s -w "\n%{http_code}" -X POST "$test_url" \
                -H "Content-Type: application/json" \
                -H "Authorization: Bearer $api_key" \
                -d "{
                    \"model\": \"$model\",
                    \"messages\": [{\"role\": \"user\", \"content\": \"请回复: 连接成功\"}],
                    \"max_tokens\": 50
                }" 2>/dev/null)
            ;;
    esac
    
    local http_code=$(echo "$response" | tail -n1)
    local response_body=$(echo "$response" | sed '$d')
    
    echo ""
    if [ "$http_code" = "200" ]; then
        log_info "API 连接测试成功！(HTTP $http_code)"
        
        # 尝试解析响应
        if command -v python3 &> /dev/null; then
            local ai_response=$(echo "$response_body" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    if 'choices' in d:
        print(d['choices'][0].get('message', {}).get('content', '')[:100])
    elif 'content' in d:
        print(d['content'][0].get('text', '')[:100])
    elif 'candidates' in d:
        print(d['candidates'][0]['content']['parts'][0]['text'][:100])
except:
    print('')
" 2>/dev/null)
            if [ -n "$ai_response" ]; then
                echo -e "  AI 响应: ${GREEN}$ai_response${NC}"
            fi
        fi
        return 0
    else
        log_error "API 连接测试失败 (HTTP $http_code)"
        
        # 显示错误信息
        if command -v python3 &> /dev/null; then
            local error_msg=$(echo "$response_body" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    if 'error' in d:
        err = d['error']
        if isinstance(err, dict):
            print(err.get('message', str(err))[:200])
        else:
            print(str(err)[:200])
except:
    print('无法解析错误')
" 2>/dev/null)
            echo -e "  错误: ${RED}$error_msg${NC}"
        fi
        return 1
    fi
}

# 测试 Telegram 机器人
test_telegram_bot() {
    local token=$1
    local user_id=$2
    
    echo ""
    echo -e "${CYAN}━━━ 测试 Telegram 机器人 ━━━${NC}"
    echo ""
    
    # 1. 验证 Token
    echo -e "${YELLOW}1. 验证 Bot Token...${NC}"
    local bot_info=$(curl -s "https://api.telegram.org/bot${token}/getMe" 2>/dev/null)
    
    if echo "$bot_info" | grep -q '"ok":true'; then
        local bot_name=$(echo "$bot_info" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['first_name'])" 2>/dev/null)
        local bot_username=$(echo "$bot_info" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['username'])" 2>/dev/null)
        log_info "Bot 验证成功: $bot_name (@$bot_username)"
    else
        log_error "Bot Token 无效"
        return 1
    fi
    
    # 2. 发送测试消息
    echo ""
    echo -e "${YELLOW}2. 发送测试消息...${NC}"
    
    local message="🦞 ClawdBot 测试消息

这是一条来自配置工具的测试消息。
如果你收到这条消息，说明 Telegram 机器人配置成功！

时间: $(date '+%Y-%m-%d %H:%M:%S')"
    
    local send_result=$(curl -s -X POST "https://api.telegram.org/bot${token}/sendMessage" \
        -H "Content-Type: application/json" \
        -d "{
            \"chat_id\": \"$user_id\",
            \"text\": \"$message\",
            \"parse_mode\": \"HTML\"
        }" 2>/dev/null)
    
    if echo "$send_result" | grep -q '"ok":true'; then
        log_info "测试消息发送成功！请检查你的 Telegram"
        return 0
    else
        local error=$(echo "$send_result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('description', '未知错误'))" 2>/dev/null)
        log_error "消息发送失败: $error"
        echo ""
        echo -e "${YELLOW}提示: 请确保你已经先向机器人发送过消息${NC}"
        return 1
    fi
}

# 测试 Discord 机器人
test_discord_bot() {
    local token=$1
    local channel_id=$2
    
    echo ""
    echo -e "${CYAN}━━━ 测试 Discord 机器人 ━━━${NC}"
    echo ""
    
    # 1. 验证 Token
    echo -e "${YELLOW}1. 验证 Bot Token...${NC}"
    local bot_info=$(curl -s "https://discord.com/api/v10/users/@me" \
        -H "Authorization: Bot $token" 2>/dev/null)
    
    if echo "$bot_info" | grep -q '"id"'; then
        local bot_name=$(echo "$bot_info" | python3 -c "import sys,json; print(json.load(sys.stdin).get('username', 'Unknown'))" 2>/dev/null)
        log_info "Bot 验证成功: $bot_name"
    else
        log_error "Bot Token 无效"
        return 1
    fi
    
    # 2. 发送测试消息
    echo ""
    echo -e "${YELLOW}2. 发送测试消息到频道...${NC}"
    
    local message="🦞 **ClawdBot 测试消息**

这是一条来自配置工具的测试消息。
如果你看到这条消息，说明 Discord 机器人配置成功！

时间: $(date '+%Y-%m-%d %H:%M:%S')"
    
    local send_result=$(curl -s -X POST "https://discord.com/api/v10/channels/${channel_id}/messages" \
        -H "Authorization: Bot $token" \
        -H "Content-Type: application/json" \
        -d "{\"content\": \"$message\"}" 2>/dev/null)
    
    if echo "$send_result" | grep -q '"id"'; then
        log_info "测试消息发送成功！请检查 Discord 频道"
        return 0
    else
        local error=$(echo "$send_result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('message', '未知错误'))" 2>/dev/null)
        log_error "消息发送失败: $error"
        return 1
    fi
}

# 测试 Slack 机器人
test_slack_bot() {
    local bot_token=$1
    
    echo ""
    echo -e "${CYAN}━━━ 测试 Slack 机器人 ━━━${NC}"
    echo ""
    
    # 验证 Token
    echo -e "${YELLOW}验证 Bot Token...${NC}"
    local auth_result=$(curl -s "https://slack.com/api/auth.test" \
        -H "Authorization: Bearer $bot_token" 2>/dev/null)
    
    if echo "$auth_result" | grep -q '"ok":true'; then
        local team=$(echo "$auth_result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('team', 'Unknown'))" 2>/dev/null)
        local user=$(echo "$auth_result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('user', 'Unknown'))" 2>/dev/null)
        log_info "Slack 验证成功: $user @ $team"
        return 0
    else
        local error=$(echo "$auth_result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('error', '未知错误'))" 2>/dev/null)
        log_error "验证失败: $error"
        return 1
    fi
}

# 测试 Ollama 连接
test_ollama_connection() {
    local base_url=$1
    local model=$2
    
    echo ""
    echo -e "${CYAN}━━━ 测试 Ollama 连接 ━━━${NC}"
    echo ""
    
    # 1. 检查服务是否运行
    echo -e "${YELLOW}1. 检查 Ollama 服务...${NC}"
    local health=$(curl -s "${base_url}/api/tags" 2>/dev/null)
    
    if [ -z "$health" ]; then
        log_error "无法连接到 Ollama 服务: $base_url"
        echo -e "${YELLOW}请确保 Ollama 正在运行: ollama serve${NC}"
        return 1
    fi
    log_info "Ollama 服务运行正常"
    
    # 2. 检查模型是否存在
    echo ""
    echo -e "${YELLOW}2. 检查模型 $model...${NC}"
    if echo "$health" | grep -q "\"name\":\"$model\""; then
        log_info "模型 $model 已安装"
    else
        log_warn "模型 $model 可能未安装"
        echo -e "${YELLOW}运行以下命令安装: ollama pull $model${NC}"
    fi
    
    # 3. 测试生成
    echo ""
    echo -e "${YELLOW}3. 测试模型响应...${NC}"
    local response=$(curl -s "${base_url}/api/generate" \
        -d "{\"model\": \"$model\", \"prompt\": \"Say hello\", \"stream\": false}" 2>/dev/null)
    
    if echo "$response" | grep -q '"response"'; then
        log_info "模型响应测试成功"
        return 0
    else
        log_error "模型响应测试失败"
        return 1
    fi
}

# 测试 WhatsApp (通过 clawdbot status)
test_whatsapp() {
    echo ""
    echo -e "${CYAN}━━━ 测试 WhatsApp 连接 ━━━${NC}"
    echo ""
    
    if check_clawdbot_installed; then
        echo -e "${YELLOW}检查 WhatsApp 渠道状态...${NC}"
        echo ""
        clawdbot status 2>/dev/null | grep -i whatsapp || echo "WhatsApp 渠道未配置"
        echo ""
        echo -e "${CYAN}提示: 使用 'clawdbot channels login' 配置 WhatsApp${NC}"
        return 0
    else
        log_warn "WhatsApp 测试需要 ClawdBot 已安装"
        echo -e "${YELLOW}请先完成 ClawdBot 安装${NC}"
        return 1
    fi
}

# 测试 iMessage (通过 clawdbot status)
test_imessage() {
    echo ""
    echo -e "${CYAN}━━━ 测试 iMessage 连接 ━━━${NC}"
    echo ""
    
    if check_clawdbot_installed; then
        echo -e "${YELLOW}检查 iMessage 渠道状态...${NC}"
        echo ""
        clawdbot status 2>/dev/null | grep -i imessage || echo "iMessage 渠道未配置"
        return 0
    else
        log_warn "iMessage 测试需要 ClawdBot 已安装"
        echo -e "${YELLOW}请先完成 ClawdBot 安装${NC}"
        return 1
    fi
}

# 测试微信 (通过 clawdbot status)
test_wechat() {
    echo ""
    echo -e "${CYAN}━━━ 测试微信连接 ━━━${NC}"
    echo ""
    
    if check_clawdbot_installed; then
        echo -e "${YELLOW}检查微信渠道状态...${NC}"
        echo ""
        clawdbot status 2>/dev/null | grep -i wechat || echo "微信渠道未配置"
        return 0
    else
        log_warn "微信测试需要 ClawdBot 已安装"
        echo -e "${YELLOW}请先完成 ClawdBot 安装${NC}"
        return 1
    fi
}

# 运行 ClawdBot 诊断 (使用 clawdbot doctor)
run_clawdbot_doctor() {
    echo ""
    echo -e "${CYAN}━━━ ClawdBot 诊断 ━━━${NC}"
    echo ""
    
    if check_clawdbot_installed; then
        clawdbot doctor
        return $?
    else
        log_error "ClawdBot 未安装"
        echo -e "${YELLOW}请先运行 install.sh 安装 ClawdBot${NC}"
        return 1
    fi
}

# 运行 ClawdBot 状态检查 (使用 clawdbot status)
run_clawdbot_status() {
    echo ""
    echo -e "${CYAN}━━━ ClawdBot 状态 ━━━${NC}"
    echo ""
    
    if check_clawdbot_installed; then
        clawdbot status
        return $?
    else
        log_error "ClawdBot 未安装"
        return 1
    fi
}

# 运行 ClawdBot 健康检查 (使用 clawdbot health)
run_clawdbot_health() {
    echo ""
    echo -e "${CYAN}━━━ Gateway 健康检查 ━━━${NC}"
    echo ""
    
    if check_clawdbot_installed; then
        clawdbot health
        return $?
    else
        log_error "ClawdBot 未安装"
        return 1
    fi
}

# ================================ 状态显示 ================================

show_status() {
    clear_screen
    print_header
    
    echo -e "${WHITE}📊 系统状态${NC}"
    print_divider
    echo ""
    
    # ClawdBot 服务状态
    if command -v clawdbot &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} ClawdBot 已安装: $(clawdbot --version 2>/dev/null || echo 'unknown')"
        
        # 检查服务运行状态
        if pgrep -f "clawdbot" > /dev/null 2>&1; then
            echo -e "  ${GREEN}●${NC} 服务状态: ${GREEN}运行中${NC}"
        else
            echo -e "  ${RED}●${NC} 服务状态: ${RED}已停止${NC}"
        fi
    else
        echo -e "  ${RED}✗${NC} ClawdBot 未安装"
    fi
    
    echo ""
    
    # 配置文件状态
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "  ${GREEN}✓${NC} 配置文件: $CONFIG_FILE"
        
        # 显示当前配置概要
        local provider=$(get_config_value "provider")
        local model=$(get_config_value "model")
        local bot_name=$(get_config_value "bot_name")
        
        echo ""
        echo -e "  ${CYAN}当前配置:${NC}"
        echo -e "    • AI 提供商: ${WHITE}${provider:-未配置}${NC}"
        echo -e "    • 模型: ${WHITE}${model:-未配置}${NC}"
        echo -e "    • 助手名称: ${WHITE}${bot_name:-未配置}${NC}"
    else
        echo -e "  ${YELLOW}⚠${NC} 配置文件不存在"
    fi
    
    echo ""
    
    # 目录状态
    echo -e "  ${CYAN}目录结构:${NC}"
    [ -d "$CONFIG_DIR" ] && echo -e "    ${GREEN}✓${NC} 配置目录" || echo -e "    ${RED}✗${NC} 配置目录"
    [ -d "$LOG_DIR" ] && echo -e "    ${GREEN}✓${NC} 日志目录" || echo -e "    ${RED}✗${NC} 日志目录"
    [ -d "$SKILLS_DIR" ] && echo -e "    ${GREEN}✓${NC} 技能目录" || echo -e "    ${RED}✗${NC} 技能目录"
    [ -d "$DATA_DIR" ] && echo -e "    ${GREEN}✓${NC} 数据目录" || echo -e "    ${RED}✗${NC} 数据目录"
    
    echo ""
    print_divider
    press_enter
}

# ================================ AI 模型配置 ================================

config_ai_model() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🤖 AI 模型配置${NC}"
    print_divider
    echo ""
    
    echo -e "${CYAN}选择 AI 提供商:${NC}"
    echo ""
    print_menu_item "1" "Anthropic Claude (推荐)" "🟣"
    print_menu_item "2" "OpenAI GPT" "🟢"
    print_menu_item "3" "OpenAI Compatible (通用兼容接口)" "🔄"
    print_menu_item "4" "Ollama 本地模型" "🟠"
    print_menu_item "5" "OpenRouter (多模型网关)" "🔵"
    print_menu_item "6" "Google Gemini" "🔴"
    print_menu_item "7" "Azure OpenAI" "☁️"
    print_menu_item "8" "Groq (超快推理)" "⚡"
    print_menu_item "9" "Mistral AI" "🌬️"
    print_menu_item "0" "返回主菜单" "↩️"
    echo ""
    
    read -p "$(echo -e "${YELLOW}请选择 [0-9]: ${NC}")" choice
    
    case $choice in
        1) config_anthropic ;;
        2) config_openai ;;
        3) config_openai_compatible ;;
        4) config_ollama ;;
        5) config_openrouter ;;
        6) config_google_gemini ;;
        7) config_azure_openai ;;
        8) config_groq ;;
        9) config_mistral ;;
        0) return ;;
        *) log_error "无效选择"; press_enter; config_ai_model ;;
    esac
}

config_anthropic() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🟣 配置 Anthropic Claude${NC}"
    print_divider
    echo ""
    
    # 获取当前 API Key
    local current_key=$(get_config_value "api_key")
    if [ -n "$current_key" ] && [ "$current_key" != "your-api-key-here" ]; then
        local masked_key="${current_key:0:8}...${current_key: -4}"
        echo -e "当前 API Key: ${GRAY}$masked_key${NC}"
    fi
    echo ""
    
    read -p "$(echo -e "${YELLOW}输入 Claude API Key (留空保持不变): ${NC}")" api_key
    
    if [ -n "$api_key" ]; then
        backup_config
        update_config_value "provider" "anthropic"
        update_config_value "api_key" "$api_key"
    fi
    
    echo ""
    echo -e "${CYAN}选择模型:${NC}"
    echo ""
    print_menu_item "1" "Claude Sonnet 4 (平衡性能，推荐)" "⭐"
    print_menu_item "2" "Claude Opus 4 (最强性能)" "👑"
    print_menu_item "3" "Claude 3.5 Haiku (快速经济)" "⚡"
    print_menu_item "4" "Claude 3.5 Sonnet (上一代)" "📦"
    echo ""
    
    read -p "$(echo -e "${YELLOW}请选择 [1-4] (默认: 1): ${NC}")" model_choice
    model_choice=${model_choice:-1}
    
    case $model_choice in
        1) model="claude-sonnet-4-20250514" ;;
        2) model="claude-opus-4-20250514" ;;
        3) model="claude-3-5-haiku-20241022" ;;
        4) model="claude-3-5-sonnet-20241022" ;;
        *) model="claude-sonnet-4-20250514" ;;
    esac
    
    update_config_value "model" "$model"
    
    echo ""
    log_info "Anthropic Claude 配置完成！"
    log_info "提供商: anthropic"
    log_info "模型: $model"
    
    # 询问是否测试
    echo ""
    if confirm "是否测试 API 连接？" "y"; then
        test_ai_connection "anthropic" "$api_key" "$model" ""
    fi
    
    press_enter
}

config_openai() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🟢 配置 OpenAI GPT${NC}"
    print_divider
    echo ""
    
    read -p "$(echo -e "${YELLOW}输入 OpenAI API Key: ${NC}")" api_key
    
    if [ -n "$api_key" ]; then
        backup_config
        update_config_value "provider" "openai"
        update_config_value "api_key" "$api_key"
    fi
    
    echo ""
    echo -e "${CYAN}选择模型:${NC}"
    echo ""
    print_menu_item "1" "GPT-4o (推荐)" "⭐"
    print_menu_item "2" "GPT-4o-mini (经济)" "⚡"
    print_menu_item "3" "GPT-4 Turbo" "🚀"
    print_menu_item "4" "o1-preview (推理)" "🧠"
    echo ""
    
    read -p "$(echo -e "${YELLOW}请选择 [1-4] (默认: 1): ${NC}")" model_choice
    model_choice=${model_choice:-1}
    
    case $model_choice in
        1) model="gpt-4o" ;;
        2) model="gpt-4o-mini" ;;
        3) model="gpt-4-turbo" ;;
        4) model="o1-preview" ;;
        *) model="gpt-4o" ;;
    esac
    
    update_config_value "model" "$model"
    
    echo ""
    log_info "OpenAI GPT 配置完成！"
    log_info "模型: $model"
    
    # 询问是否测试
    echo ""
    if confirm "是否测试 API 连接？" "y"; then
        test_ai_connection "openai" "$api_key" "$model" ""
    fi
    
    press_enter
}

config_ollama() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🟠 配置 Ollama 本地模型${NC}"
    print_divider
    echo ""
    
    echo -e "${CYAN}Ollama 允许你在本地运行 AI 模型，无需 API Key${NC}"
    echo ""
    
    read -p "$(echo -e "${YELLOW}Ollama 服务地址 (默认: http://localhost:11434): ${NC}")" ollama_url
    ollama_url=${ollama_url:-"http://localhost:11434"}
    
    echo ""
    echo -e "${CYAN}选择模型:${NC}"
    echo ""
    print_menu_item "1" "Llama 3 (8B)" "🦙"
    print_menu_item "2" "Llama 3 (70B)" "🦙"
    print_menu_item "3" "Mistral" "🌬️"
    print_menu_item "4" "CodeLlama" "💻"
    print_menu_item "5" "自定义模型名称" "✏️"
    echo ""
    
    read -p "$(echo -e "${YELLOW}请选择 [1-5] (默认: 1): ${NC}")" model_choice
    model_choice=${model_choice:-1}
    
    case $model_choice in
        1) model="llama3" ;;
        2) model="llama3:70b" ;;
        3) model="mistral" ;;
        4) model="codellama" ;;
        5) 
            read -p "$(echo -e "${YELLOW}输入模型名称: ${NC}")" model
            ;;
        *) model="llama3" ;;
    esac
    
    backup_config
    update_config_value "provider" "ollama"
    update_config_value "base_url" "$ollama_url"
    update_config_value "model" "$model"
    update_config_value "api_key" ""
    
    echo ""
    log_info "Ollama 配置完成！"
    log_info "服务地址: $ollama_url"
    log_info "模型: $model"
    
    # 询问是否测试
    echo ""
    if confirm "是否测试 Ollama 连接？" "y"; then
        test_ollama_connection "$ollama_url" "$model"
    fi
    
    press_enter
}

config_openrouter() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🔵 配置 OpenRouter${NC}"
    print_divider
    echo ""
    
    echo -e "${CYAN}OpenRouter 是一个多模型网关，支持多种 AI 模型${NC}"
    echo ""
    
    read -p "$(echo -e "${YELLOW}输入 OpenRouter API Key: ${NC}")" api_key
    
    if [ -n "$api_key" ]; then
        backup_config
        update_config_value "provider" "openrouter"
        update_config_value "api_key" "$api_key"
        update_config_value "base_url" "https://openrouter.ai/api/v1"
    fi
    
    echo ""
    echo -e "${CYAN}选择模型:${NC}"
    echo ""
    print_menu_item "1" "anthropic/claude-sonnet-4" "🟣"
    print_menu_item "2" "openai/gpt-4o" "🟢"
    print_menu_item "3" "google/gemini-pro-1.5" "🔴"
    print_menu_item "4" "meta-llama/llama-3-70b" "🦙"
    print_menu_item "5" "自定义模型" "✏️"
    echo ""
    
    read -p "$(echo -e "${YELLOW}请选择 [1-5] (默认: 1): ${NC}")" model_choice
    model_choice=${model_choice:-1}
    
    case $model_choice in
        1) model="anthropic/claude-sonnet-4" ;;
        2) model="openai/gpt-4o" ;;
        3) model="google/gemini-pro-1.5" ;;
        4) model="meta-llama/llama-3-70b-instruct" ;;
        5) 
            read -p "$(echo -e "${YELLOW}输入模型名称: ${NC}")" model
            ;;
        *) model="anthropic/claude-sonnet-4" ;;
    esac
    
    update_config_value "model" "$model"
    
    echo ""
    log_info "OpenRouter 配置完成！"
    log_info "模型: $model"
    
    # 询问是否测试
    echo ""
    if confirm "是否测试 API 连接？" "y"; then
        test_ai_connection "openrouter" "$api_key" "$model" "https://openrouter.ai/api/v1"
    fi
    
    press_enter
}

config_openai_compatible() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🔄 配置 OpenAI Compatible (通用兼容接口)${NC}"
    print_divider
    echo ""
    
    echo -e "${CYAN}OpenAI Compatible 支持任何兼容 OpenAI API 格式的服务${NC}"
    echo -e "${CYAN}包括: OneAPI, New API, 各种代理服务等${NC}"
    echo ""
    
    read -p "$(echo -e "${YELLOW}输入 API 地址 (如 https://api.example.com/v1): ${NC}")" base_url
    
    if [ -z "$base_url" ]; then
        log_error "API 地址不能为空"
        press_enter
        return
    fi
    
    read -p "$(echo -e "${YELLOW}输入 API Key: ${NC}")" api_key
    
    if [ -z "$api_key" ]; then
        log_error "API Key 不能为空"
        press_enter
        return
    fi
    
    echo ""
    echo -e "${CYAN}选择或输入模型:${NC}"
    echo ""
    print_menu_item "1" "claude-sonnet-4.5" "🟣"
    print_menu_item "2" "claude-sonnet-4" "🟣"
    print_menu_item "3" "claude-opus-4" "🟣"
    print_menu_item "4" "gpt-4o" "🟢"
    print_menu_item "5" "gpt-4o-mini" "🟢"
    print_menu_item "6" "gpt-4-turbo" "🟢"
    print_menu_item "7" "gemini-pro" "🔴"
    print_menu_item "8" "自定义模型名称" "✏️"
    echo ""
    
    read -p "$(echo -e "${YELLOW}请选择 [1-8] (默认: 1): ${NC}")" model_choice
    model_choice=${model_choice:-1}
    
    case $model_choice in
        1) model="claude-sonnet-4.5" ;;
        2) model="claude-sonnet-4" ;;
        3) model="claude-opus-4" ;;
        4) model="gpt-4o" ;;
        5) model="gpt-4o-mini" ;;
        6) model="gpt-4-turbo" ;;
        7) model="gemini-pro" ;;
        8) 
            read -p "$(echo -e "${YELLOW}输入模型名称: ${NC}")" model
            ;;
        *) model="claude-sonnet-4.5" ;;
    esac
    
    backup_config
    update_config_value "provider" "openai-compatible"
    update_config_value "base_url" "$base_url"
    update_config_value "api_key" "$api_key"
    update_config_value "model" "$model"
    
    echo ""
    log_info "OpenAI Compatible 配置完成！"
    log_info "API 地址: $base_url"
    log_info "模型: $model"
    
    # 询问是否测试
    echo ""
    if confirm "是否测试 API 连接？" "y"; then
        test_ai_connection "openai-compatible" "$api_key" "$model" "$base_url"
    fi
    
    press_enter
}

config_google_gemini() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🔴 配置 Google Gemini${NC}"
    print_divider
    echo ""
    
    echo -e "${CYAN}获取 API Key: https://makersuite.google.com/app/apikey${NC}"
    echo ""
    
    read -p "$(echo -e "${YELLOW}输入 Google API Key: ${NC}")" api_key
    
    if [ -n "$api_key" ]; then
        backup_config
        update_config_value "provider" "google"
        update_config_value "api_key" "$api_key"
    fi
    
    echo ""
    echo -e "${CYAN}选择模型:${NC}"
    echo ""
    print_menu_item "1" "gemini-2.0-flash (推荐)" "⭐"
    print_menu_item "2" "gemini-1.5-pro" "🚀"
    print_menu_item "3" "gemini-1.5-flash" "⚡"
    print_menu_item "4" "gemini-1.0-pro" "📦"
    echo ""
    
    read -p "$(echo -e "${YELLOW}请选择 [1-4] (默认: 1): ${NC}")" model_choice
    model_choice=${model_choice:-1}
    
    case $model_choice in
        1) model="gemini-2.0-flash" ;;
        2) model="gemini-1.5-pro" ;;
        3) model="gemini-1.5-flash" ;;
        4) model="gemini-1.0-pro" ;;
        *) model="gemini-2.0-flash" ;;
    esac
    
    update_config_value "model" "$model"
    
    echo ""
    log_info "Google Gemini 配置完成！"
    log_info "模型: $model"
    
    # 询问是否测试
    echo ""
    if confirm "是否测试 API 连接？" "y"; then
        test_ai_connection "google" "$api_key" "$model" ""
    fi
    
    press_enter
}

config_azure_openai() {
    clear_screen
    print_header
    
    echo -e "${WHITE}☁️ 配置 Azure OpenAI${NC}"
    print_divider
    echo ""
    
    echo -e "${CYAN}Azure OpenAI 需要以下信息:${NC}"
    echo "  - Azure 端点 URL"
    echo "  - API Key"
    echo "  - 部署名称"
    echo ""
    
    read -p "$(echo -e "${YELLOW}输入 Azure 端点 URL: ${NC}")" azure_endpoint
    read -p "$(echo -e "${YELLOW}输入 API Key: ${NC}")" api_key
    read -p "$(echo -e "${YELLOW}输入部署名称 (Deployment Name): ${NC}")" deployment_name
    read -p "$(echo -e "${YELLOW}API 版本 (默认: 2024-02-15-preview): ${NC}")" api_version
    api_version=${api_version:-"2024-02-15-preview"}
    
    if [ -n "$azure_endpoint" ] && [ -n "$api_key" ] && [ -n "$deployment_name" ]; then
        backup_config
        update_config_value "provider" "azure"
        update_config_value "base_url" "$azure_endpoint"
        update_config_value "api_key" "$api_key"
        update_config_value "model" "$deployment_name"
        update_config_value "api_version" "$api_version"
        
        echo ""
        log_info "Azure OpenAI 配置完成！"
        log_info "端点: $azure_endpoint"
        log_info "部署: $deployment_name"
    else
        log_error "配置不完整，已取消"
    fi
    
    press_enter
}

config_groq() {
    clear_screen
    print_header
    
    echo -e "${WHITE}⚡ 配置 Groq${NC}"
    print_divider
    echo ""
    
    echo -e "${CYAN}Groq 提供超快的推理速度${NC}"
    echo -e "${CYAN}获取 API Key: https://console.groq.com/${NC}"
    echo ""
    
    read -p "$(echo -e "${YELLOW}输入 Groq API Key: ${NC}")" api_key
    
    if [ -n "$api_key" ]; then
        backup_config
        update_config_value "provider" "groq"
        update_config_value "api_key" "$api_key"
        update_config_value "base_url" "https://api.groq.com/openai/v1"
    fi
    
    echo ""
    echo -e "${CYAN}选择模型:${NC}"
    echo ""
    print_menu_item "1" "llama-3.3-70b-versatile (推荐)" "⭐"
    print_menu_item "2" "llama-3.1-70b-versatile" "🦙"
    print_menu_item "3" "llama-3.1-8b-instant" "⚡"
    print_menu_item "4" "mixtral-8x7b-32768" "🌬️"
    print_menu_item "5" "gemma2-9b-it" "💎"
    echo ""
    
    read -p "$(echo -e "${YELLOW}请选择 [1-5] (默认: 1): ${NC}")" model_choice
    model_choice=${model_choice:-1}
    
    case $model_choice in
        1) model="llama-3.3-70b-versatile" ;;
        2) model="llama-3.1-70b-versatile" ;;
        3) model="llama-3.1-8b-instant" ;;
        4) model="mixtral-8x7b-32768" ;;
        5) model="gemma2-9b-it" ;;
        *) model="llama-3.3-70b-versatile" ;;
    esac
    
    update_config_value "model" "$model"
    
    echo ""
    log_info "Groq 配置完成！"
    log_info "模型: $model"
    
    # 询问是否测试
    echo ""
    if confirm "是否测试 API 连接？" "y"; then
        test_ai_connection "groq" "$api_key" "$model" "https://api.groq.com/openai/v1"
    fi
    
    press_enter
}

config_mistral() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🌬️ 配置 Mistral AI${NC}"
    print_divider
    echo ""
    
    echo -e "${CYAN}获取 API Key: https://console.mistral.ai/${NC}"
    echo ""
    
    read -p "$(echo -e "${YELLOW}输入 Mistral API Key: ${NC}")" api_key
    
    if [ -n "$api_key" ]; then
        backup_config
        update_config_value "provider" "mistral"
        update_config_value "api_key" "$api_key"
        update_config_value "base_url" "https://api.mistral.ai/v1"
    fi
    
    echo ""
    echo -e "${CYAN}选择模型:${NC}"
    echo ""
    print_menu_item "1" "mistral-large-latest (推荐)" "⭐"
    print_menu_item "2" "mistral-medium-latest" "🚀"
    print_menu_item "3" "mistral-small-latest" "⚡"
    print_menu_item "4" "open-mixtral-8x22b" "🌬️"
    print_menu_item "5" "codestral-latest" "💻"
    echo ""
    
    read -p "$(echo -e "${YELLOW}请选择 [1-5] (默认: 1): ${NC}")" model_choice
    model_choice=${model_choice:-1}
    
    case $model_choice in
        1) model="mistral-large-latest" ;;
        2) model="mistral-medium-latest" ;;
        3) model="mistral-small-latest" ;;
        4) model="open-mixtral-8x22b" ;;
        5) model="codestral-latest" ;;
        *) model="mistral-large-latest" ;;
    esac
    
    update_config_value "model" "$model"
    
    echo ""
    log_info "Mistral AI 配置完成！"
    log_info "模型: $model"
    
    # 询问是否测试
    echo ""
    if confirm "是否测试 API 连接？" "y"; then
        test_ai_connection "mistral" "$api_key" "$model" "https://api.mistral.ai/v1"
    fi
    
    press_enter
}

# ================================ 渠道配置 ================================

config_channels() {
    clear_screen
    print_header
    
    echo -e "${WHITE}📱 消息渠道配置${NC}"
    print_divider
    echo ""
    
    print_menu_item "1" "Telegram 机器人" "📨"
    print_menu_item "2" "Discord 机器人" "🎮"
    print_menu_item "3" "WhatsApp" "💬"
    print_menu_item "4" "Slack" "💼"
    print_menu_item "5" "微信 (WeChat)" "🟢"
    print_menu_item "6" "iMessage" "🍎"
    print_menu_item "0" "返回主菜单" "↩️"
    echo ""
    
    read -p "$(echo -e "${YELLOW}请选择 [0-6]: ${NC}")" choice
    
    case $choice in
        1) config_telegram ;;
        2) config_discord ;;
        3) config_whatsapp ;;
        4) config_slack ;;
        5) config_wechat ;;
        6) config_imessage ;;
        0) return ;;
        *) log_error "无效选择"; press_enter; config_channels ;;
    esac
}

config_telegram() {
    clear_screen
    print_header
    
    echo -e "${WHITE}📨 配置 Telegram 机器人${NC}"
    print_divider
    echo ""
    
    echo -e "${CYAN}配置步骤:${NC}"
    echo "  1. 在 Telegram 中搜索 @BotFather"
    echo "  2. 发送 /newbot 创建新机器人"
    echo "  3. 按提示设置名称，获取 Bot Token"
    echo "  4. 搜索 @userinfobot 获取你的 User ID"
    echo ""
    print_divider
    echo ""
    
    read -p "$(echo -e "${YELLOW}输入 Bot Token: ${NC}")" bot_token
    read -p "$(echo -e "${YELLOW}输入你的 User ID: ${NC}")" user_id
    
    if [ -n "$bot_token" ] && [ -n "$user_id" ]; then
        backup_config
        
        # 添加 Telegram 配置到文件
        if grep -q "telegram:" "$CONFIG_FILE"; then
            log_warn "Telegram 配置已存在，将更新..."
        else
            cat >> "$CONFIG_FILE" << EOF

# Telegram 配置
telegram:
  enabled: true
  token: "$bot_token"
  allowed_users:
    - "$user_id"
EOF
        fi
        
        echo ""
        log_info "Telegram 配置完成！"
        log_info "Bot Token: ${bot_token:0:10}..."
        log_info "User ID: $user_id"
        
        # 询问是否测试
        echo ""
        if confirm "是否发送测试消息？" "y"; then
            test_telegram_bot "$bot_token" "$user_id"
        fi
    else
        log_error "配置不完整，已取消"
    fi
    
    press_enter
}

config_discord() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🎮 配置 Discord 机器人${NC}"
    print_divider
    echo ""
    
    echo -e "${CYAN}配置步骤:${NC}"
    echo "  1. 访问 https://discord.com/developers/applications"
    echo "  2. 创建新应用，进入 Bot 页面"
    echo "  3. 创建 Bot 并复制 Token"
    echo "  4. 在 OAuth2 页面生成邀请链接"
    echo "  5. 邀请机器人到你的服务器"
    echo ""
    print_divider
    echo ""
    
    read -p "$(echo -e "${YELLOW}输入 Bot Token: ${NC}")" bot_token
    read -p "$(echo -e "${YELLOW}输入频道 ID: ${NC}")" channel_id
    
    if [ -n "$bot_token" ] && [ -n "$channel_id" ]; then
        backup_config
        
        if grep -q "discord:" "$CONFIG_FILE"; then
            log_warn "Discord 配置已存在，将更新..."
        else
            cat >> "$CONFIG_FILE" << EOF

# Discord 配置
discord:
  enabled: true
  token: "$bot_token"
  channels:
    - "$channel_id"
EOF
        fi
        
        echo ""
        log_info "Discord 配置完成！"
        
        # 询问是否测试
        echo ""
        if confirm "是否发送测试消息？" "y"; then
            test_discord_bot "$bot_token" "$channel_id"
        fi
    else
        log_error "配置不完整，已取消"
    fi
    
    press_enter
}

config_whatsapp() {
    clear_screen
    print_header
    
    echo -e "${WHITE}💬 配置 WhatsApp${NC}"
    print_divider
    echo ""
    
    echo -e "${CYAN}WhatsApp 配置需要扫描二维码登录${NC}"
    echo ""
    echo "将运行 ClawdBot 的 WhatsApp 配置向导..."
    echo ""
    
    if confirm "是否继续？"; then
        if command -v clawdbot &> /dev/null; then
            clawdbot onboard --provider whatsapp
        else
            log_error "ClawdBot 未安装，请先运行安装脚本"
        fi
    fi
    
    press_enter
}

config_slack() {
    clear_screen
    print_header
    
    echo -e "${WHITE}💼 配置 Slack${NC}"
    print_divider
    echo ""
    
    echo -e "${CYAN}配置步骤:${NC}"
    echo "  1. 访问 https://api.slack.com/apps"
    echo "  2. 创建新应用，选择 'From scratch'"
    echo "  3. 在 OAuth & Permissions 中添加所需权限"
    echo "  4. 安装应用到工作区并获取 Bot Token"
    echo ""
    print_divider
    echo ""
    
    read -p "$(echo -e "${YELLOW}输入 Bot Token (xoxb-...): ${NC}")" bot_token
    read -p "$(echo -e "${YELLOW}输入 App Token (xapp-...): ${NC}")" app_token
    
    if [ -n "$bot_token" ] && [ -n "$app_token" ]; then
        backup_config
        
        cat >> "$CONFIG_FILE" << EOF

# Slack 配置
slack:
  enabled: true
  bot_token: "$bot_token"
  app_token: "$app_token"
EOF
        
        echo ""
        log_info "Slack 配置完成！"
        
        # 询问是否测试
        echo ""
        if confirm "是否验证 Slack 连接？" "y"; then
            test_slack_bot "$bot_token"
        fi
    else
        log_error "配置不完整，已取消"
    fi
    
    press_enter
}

config_wechat() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🟢 配置微信${NC}"
    print_divider
    echo ""
    
    echo -e "${YELLOW}⚠️ 注意: 微信接入需要使用第三方工具${NC}"
    echo ""
    echo -e "${CYAN}推荐方案:${NC}"
    echo "  1. 使用 wechaty 框架"
    echo "  2. 或使用 itchat 库"
    echo ""
    echo "将运行 ClawdBot 的微信配置向导..."
    echo ""
    
    if confirm "是否继续？"; then
        if command -v clawdbot &> /dev/null; then
            clawdbot onboard --provider wechat
        else
            log_error "ClawdBot 未安装"
        fi
    fi
    
    press_enter
}

config_imessage() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🍎 配置 iMessage${NC}"
    print_divider
    echo ""
    
    echo -e "${YELLOW}⚠️ 注意: iMessage 仅支持 macOS${NC}"
    echo ""
    
    if [[ "$OSTYPE" != "darwin"* ]]; then
        log_error "iMessage 仅支持 macOS 系统"
        press_enter
        return
    fi
    
    echo -e "${CYAN}iMessage 配置需要授予完整磁盘访问权限${NC}"
    echo ""
    
    if confirm "是否继续配置？"; then
        if command -v clawdbot &> /dev/null; then
            clawdbot onboard --provider imessage
        else
            log_error "ClawdBot 未安装"
        fi
    fi
    
    press_enter
}

# ================================ 身份配置 ================================

config_identity() {
    clear_screen
    print_header
    
    echo -e "${WHITE}👤 身份与个性配置${NC}"
    print_divider
    echo ""
    
    # 显示当前配置
    local current_bot_name=$(get_config_value "bot_name")
    local current_user_name=$(get_config_value "user_name")
    local current_timezone=$(get_config_value "timezone")
    
    echo -e "${CYAN}当前配置:${NC}"
    echo "  助手名称: ${current_bot_name:-未设置}"
    echo "  你的称呼: ${current_user_name:-未设置}"
    echo "  时区: ${current_timezone:-未设置}"
    echo ""
    print_divider
    echo ""
    
    read -p "$(echo -e "${YELLOW}助手名称 (留空保持不变): ${NC}")" bot_name
    read -p "$(echo -e "${YELLOW}如何称呼你 (留空保持不变): ${NC}")" user_name
    read -p "$(echo -e "${YELLOW}时区 (如 Asia/Shanghai，留空保持不变): ${NC}")" timezone
    
    echo ""
    echo -e "${CYAN}设置助手个性 (输入多行文本，输入空行结束):${NC}"
    personality=""
    while IFS= read -r line; do
        [ -z "$line" ] && break
        personality+="$line\n"
    done
    
    backup_config
    
    [ -n "$bot_name" ] && update_config_value "bot_name" "$bot_name"
    [ -n "$user_name" ] && update_config_value "user_name" "$user_name"
    [ -n "$timezone" ] && update_config_value "timezone" "$timezone"
    
    echo ""
    log_info "身份配置已更新！"
    
    press_enter
}

# ================================ 安全配置 ================================

config_security() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🔒 安全配置${NC}"
    print_divider
    echo ""
    
    echo -e "${RED}⚠️ 警告: 以下设置涉及安全风险，请谨慎配置${NC}"
    echo ""
    
    print_menu_item "1" "允许执行系统命令" "⚙️"
    print_menu_item "2" "允许文件访问" "📁"
    print_menu_item "3" "允许网络浏览" "🌐"
    print_menu_item "4" "沙箱模式 (推荐开启)" "📦"
    print_menu_item "5" "配置白名单" "✅"
    print_menu_item "0" "返回主菜单" "↩️"
    echo ""
    
    read -p "$(echo -e "${YELLOW}请选择 [0-5]: ${NC}")" choice
    
    case $choice in
        1)
            if confirm "允许 ClawdBot 执行系统命令？这可能带来安全风险" "n"; then
                update_config_value "enable_shell_commands" "true"
                log_info "已启用系统命令执行"
            else
                update_config_value "enable_shell_commands" "false"
                log_info "已禁用系统命令执行"
            fi
            ;;
        2)
            if confirm "允许 ClawdBot 读写文件？" "n"; then
                update_config_value "enable_file_access" "true"
                log_info "已启用文件访问"
            else
                update_config_value "enable_file_access" "false"
                log_info "已禁用文件访问"
            fi
            ;;
        3)
            if confirm "允许 ClawdBot 浏览网络？" "y"; then
                update_config_value "enable_web_browsing" "true"
                log_info "已启用网络浏览"
            else
                update_config_value "enable_web_browsing" "false"
                log_info "已禁用网络浏览"
            fi
            ;;
        4)
            if confirm "启用沙箱模式？(推荐)" "y"; then
                update_config_value "sandbox_mode" "true"
                log_info "已启用沙箱模式"
            else
                update_config_value "sandbox_mode" "false"
                log_warn "已禁用沙箱模式，请注意安全风险"
            fi
            ;;
        5)
            config_whitelist
            ;;
        0)
            return
            ;;
    esac
    
    press_enter
    config_security
}

config_whitelist() {
    clear_screen
    print_header
    
    echo -e "${WHITE}✅ 配置白名单${NC}"
    print_divider
    echo ""
    
    echo -e "${CYAN}添加允许访问的目录路径 (每行一个，空行结束):${NC}"
    echo ""
    
    paths=""
    while IFS= read -r line; do
        [ -z "$line" ] && break
        paths+="    - \"$line\"\n"
    done
    
    if [ -n "$paths" ]; then
        backup_config
        
        # 添加白名单到配置
        cat >> "$CONFIG_FILE" << EOF

# 白名单配置
whitelist:
  directories:
$(echo -e "$paths")
EOF
        
        log_info "白名单配置已保存"
    fi
}

# ================================ 服务管理 ================================

manage_service() {
    clear_screen
    print_header
    
    echo -e "${WHITE}⚡ 服务管理${NC}"
    print_divider
    echo ""
    
    # 检查服务状态
    if pgrep -f "clawdbot" > /dev/null 2>&1; then
        echo -e "  当前状态: ${GREEN}● 运行中${NC}"
    else
        echo -e "  当前状态: ${RED}● 已停止${NC}"
    fi
    echo ""
    
    print_menu_item "1" "启动服务" "▶️"
    print_menu_item "2" "停止服务" "⏹️"
    print_menu_item "3" "重启服务" "🔄"
    print_menu_item "4" "查看状态" "📊"
    print_menu_item "5" "查看日志" "📋"
    print_menu_item "6" "运行诊断" "🔍"
    print_menu_item "0" "返回主菜单" "↩️"
    echo ""
    
    read -p "$(echo -e "${YELLOW}请选择 [0-6]: ${NC}")" choice
    
    case $choice in
        1)
            echo ""
            log_info "正在启动服务..."
            if command -v clawdbot &> /dev/null; then
                clawdbot start
                log_info "服务已启动"
            else
                log_error "ClawdBot 未安装"
            fi
            ;;
        2)
            echo ""
            log_info "正在停止服务..."
            if command -v clawdbot &> /dev/null; then
                clawdbot stop
                log_info "服务已停止"
            else
                log_error "ClawdBot 未安装"
            fi
            ;;
        3)
            echo ""
            log_info "正在重启服务..."
            if command -v clawdbot &> /dev/null; then
                clawdbot restart
                log_info "服务已重启"
            else
                log_error "ClawdBot 未安装"
            fi
            ;;
        4)
            echo ""
            if command -v clawdbot &> /dev/null; then
                clawdbot status
            else
                log_error "ClawdBot 未安装"
            fi
            ;;
        5)
            echo ""
            if command -v clawdbot &> /dev/null; then
                echo -e "${CYAN}按 Ctrl+C 退出日志查看${NC}"
                sleep 1
                clawdbot logs -f
            else
                log_error "ClawdBot 未安装"
            fi
            ;;
        6)
            echo ""
            if command -v clawdbot &> /dev/null; then
                clawdbot doctor
            else
                log_error "ClawdBot 未安装"
            fi
            ;;
        0)
            return
            ;;
    esac
    
    press_enter
    manage_service
}

# ================================ 高级设置 ================================

advanced_settings() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🔧 高级设置${NC}"
    print_divider
    echo ""
    
    print_menu_item "1" "编辑配置文件" "📝"
    print_menu_item "2" "备份配置" "💾"
    print_menu_item "3" "恢复配置" "📥"
    print_menu_item "4" "重置配置" "🔄"
    print_menu_item "5" "管理技能 (Skills)" "🎯"
    print_menu_item "6" "清理日志" "🧹"
    print_menu_item "7" "更新 ClawdBot" "⬆️"
    print_menu_item "8" "卸载 ClawdBot" "🗑️"
    print_menu_item "0" "返回主菜单" "↩️"
    echo ""
    
    read -p "$(echo -e "${YELLOW}请选择 [0-8]: ${NC}")" choice
    
    case $choice in
        1)
            echo ""
            log_info "正在打开配置文件..."
            if [ -n "$EDITOR" ]; then
                $EDITOR "$CONFIG_FILE"
            elif command -v nano &> /dev/null; then
                nano "$CONFIG_FILE"
            elif command -v vim &> /dev/null; then
                vim "$CONFIG_FILE"
            else
                log_error "未找到文本编辑器"
            fi
            ;;
        2)
            echo ""
            local backup_file=$(backup_config)
            if [ -n "$backup_file" ]; then
                log_info "配置已备份到: $backup_file"
            else
                log_error "备份失败"
            fi
            ;;
        3)
            restore_config
            ;;
        4)
            if confirm "确定要重置所有配置吗？这将删除当前配置" "n"; then
                backup_config
                rm -f "$CONFIG_FILE"
                log_info "配置已重置，请重新运行安装脚本"
            fi
            ;;
        5)
            manage_skills
            ;;
        6)
            if confirm "确定要清理所有日志吗？" "n"; then
                rm -rf "$LOG_DIR"/*
                log_info "日志已清理"
            fi
            ;;
        7)
            echo ""
            log_info "正在更新 ClawdBot..."
            npm update -g clawdbot
            log_info "更新完成"
            ;;
        8)
            if confirm "确定要卸载 ClawdBot 吗？" "n"; then
                npm uninstall -g clawdbot
                if confirm "是否同时删除配置文件？" "n"; then
                    rm -rf "$CONFIG_DIR"
                fi
                log_info "ClawdBot 已卸载"
                exit 0
            fi
            ;;
        0)
            return
            ;;
    esac
    
    press_enter
    advanced_settings
}

restore_config() {
    clear_screen
    print_header
    
    echo -e "${WHITE}📥 恢复配置${NC}"
    print_divider
    echo ""
    
    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A $BACKUP_DIR 2>/dev/null)" ]; then
        log_error "没有找到备份文件"
        return
    fi
    
    echo -e "${CYAN}可用备份:${NC}"
    echo ""
    
    local i=1
    local backups=()
    for file in "$BACKUP_DIR"/*.yaml; do
        if [ -f "$file" ]; then
            backups+=("$file")
            local filename=$(basename "$file")
            local date_str=$(echo "$filename" | grep -oE '[0-9]{8}_[0-9]{6}')
            echo "  [$i] $date_str"
            ((i++))
        fi
    done
    
    echo ""
    read -p "$(echo -e "${YELLOW}选择要恢复的备份 [1-$((i-1))]: ${NC}")" choice
    
    if [ -n "$choice" ] && [ "$choice" -ge 1 ] && [ "$choice" -lt "$i" ]; then
        local selected_backup="${backups[$((choice-1))]}"
        cp "$selected_backup" "$CONFIG_FILE"
        log_info "配置已从备份恢复"
    else
        log_error "无效选择"
    fi
}

manage_skills() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🎯 技能管理${NC}"
    print_divider
    echo ""
    
    echo -e "${CYAN}技能目录: $SKILLS_DIR${NC}"
    echo ""
    
    if [ -d "$SKILLS_DIR" ]; then
        echo -e "${CYAN}已安装技能:${NC}"
        for file in "$SKILLS_DIR"/*.md; do
            if [ -f "$file" ]; then
                local name=$(basename "$file" .md)
                echo "  • $name"
            fi
        done
    fi
    
    echo ""
    print_menu_item "1" "创建新技能" "➕"
    print_menu_item "2" "编辑技能" "✏️"
    print_menu_item "3" "删除技能" "🗑️"
    print_menu_item "4" "打开技能目录" "📂"
    print_menu_item "0" "返回" "↩️"
    echo ""
    
    read -p "$(echo -e "${YELLOW}请选择 [0-4]: ${NC}")" choice
    
    case $choice in
        1)
            read -p "$(echo -e "${YELLOW}技能名称: ${NC}")" skill_name
            if [ -n "$skill_name" ]; then
                create_skill_template "$skill_name"
            fi
            ;;
        2)
            read -p "$(echo -e "${YELLOW}技能名称: ${NC}")" skill_name
            if [ -f "$SKILLS_DIR/$skill_name.md" ]; then
                ${EDITOR:-nano} "$SKILLS_DIR/$skill_name.md"
            else
                log_error "技能不存在"
            fi
            ;;
        3)
            read -p "$(echo -e "${YELLOW}技能名称: ${NC}")" skill_name
            if [ -f "$SKILLS_DIR/$skill_name.md" ]; then
                if confirm "确定删除技能 $skill_name？"; then
                    rm "$SKILLS_DIR/$skill_name.md"
                    log_info "技能已删除"
                fi
            else
                log_error "技能不存在"
            fi
            ;;
        4)
            if command -v open &> /dev/null; then
                open "$SKILLS_DIR"
            elif command -v xdg-open &> /dev/null; then
                xdg-open "$SKILLS_DIR"
            fi
            ;;
        0)
            return
            ;;
    esac
    
    press_enter
    manage_skills
}

create_skill_template() {
    local name=$1
    local file="$SKILLS_DIR/$name.md"
    
    cat > "$file" << EOF
# $name

## 描述
在这里描述技能的用途。

## 触发条件
- 用户说 "关键词"
- 或定时触发

## 执行步骤
1. 步骤一
2. 步骤二
3. 步骤三

## 输出格式
\`\`\`
预期的输出格式模板
\`\`\`

## 示例
输入: "示例输入"
输出: "示例输出"
EOF

    log_info "技能模板已创建: $file"
    
    if confirm "是否立即编辑？"; then
        ${EDITOR:-nano} "$file"
    fi
}

# ================================ 查看配置 ================================

view_config() {
    clear_screen
    print_header
    
    echo -e "${WHITE}📋 当前配置${NC}"
    print_divider
    echo ""
    
    if [ -f "$CONFIG_FILE" ]; then
        # 语法高亮显示 (如果有 bat)
        if command -v bat &> /dev/null; then
            bat --style=numbers --language=yaml "$CONFIG_FILE"
        else
            cat -n "$CONFIG_FILE"
        fi
    else
        log_error "配置文件不存在"
    fi
    
    echo ""
    print_divider
    press_enter
}

# ================================ 快速测试 ================================

quick_test_menu() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🧪 快速测试${NC}"
    print_divider
    echo ""
    
    # 显示 ClawdBot 状态
    if check_clawdbot_installed; then
        local version=$(clawdbot --version 2>/dev/null || echo "unknown")
        echo -e "  ${GREEN}✓${NC} ClawdBot 已安装: $version"
    else
        echo -e "  ${YELLOW}⚠${NC} ClawdBot 未安装"
    fi
    echo ""
    print_divider
    echo ""
    
    echo -e "${CYAN}API 连接测试:${NC}"
    print_menu_item "1" "测试 AI API 连接" "🤖"
    print_menu_item "2" "测试 Telegram 机器人" "📨"
    print_menu_item "3" "测试 Discord 机器人" "🎮"
    print_menu_item "4" "测试 Slack 机器人" "💼"
    print_menu_item "5" "测试 Ollama 本地模型" "🟠"
    echo ""
    echo -e "${CYAN}ClawdBot 诊断 (需要已安装):${NC}"
    print_menu_item "6" "clawdbot doctor (诊断)" "🔍"
    print_menu_item "7" "clawdbot status (渠道状态)" "📊"
    print_menu_item "8" "clawdbot health (Gateway 健康)" "💚"
    echo ""
    print_menu_item "9" "运行全部 API 测试" "🔄"
    print_menu_item "0" "返回主菜单" "↩️"
    echo ""
    
    read -p "$(echo -e "${YELLOW}请选择 [0-9]: ${NC}")" choice
    
    case $choice in
        1) quick_test_ai ;;
        2) quick_test_telegram ;;
        3) quick_test_discord ;;
        4) quick_test_slack ;;
        5) quick_test_ollama ;;
        6) quick_test_doctor ;;
        7) quick_test_status ;;
        8) quick_test_health ;;
        9) run_all_tests ;;
        0) return ;;
        *) log_error "无效选择"; press_enter; quick_test_menu ;;
    esac
}

quick_test_ai() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🤖 测试 AI API 连接${NC}"
    print_divider
    echo ""
    
    # 读取当前配置
    local provider=$(get_config_value "provider")
    local api_key=$(get_config_value "api_key")
    local model=$(get_config_value "model")
    local base_url=$(grep "^  base_url:" "$CONFIG_FILE" 2>/dev/null | head -1 | sed 's/.*base_url:[[:space:]]*//' | tr -d '"')
    
    if [ -z "$provider" ] || [ -z "$api_key" ] || [ "$api_key" = "your-api-key-here" ]; then
        log_error "AI 模型尚未配置，请先完成配置"
        press_enter
        quick_test_menu
        return
    fi
    
    echo -e "当前配置:"
    echo -e "  提供商: ${WHITE}$provider${NC}"
    echo -e "  模型: ${WHITE}$model${NC}"
    [ -n "$base_url" ] && echo -e "  API 地址: ${WHITE}$base_url${NC}"
    
    test_ai_connection "$provider" "$api_key" "$model" "$base_url"
    
    press_enter
    quick_test_menu
}

quick_test_telegram() {
    clear_screen
    print_header
    
    echo -e "${WHITE}📨 测试 Telegram 机器人${NC}"
    print_divider
    echo ""
    
    # 读取 Telegram 配置
    local token=$(grep "token:" "$CONFIG_FILE" 2>/dev/null | head -1 | sed 's/.*token:[[:space:]]*//' | tr -d '"')
    local user_id=$(grep -A5 "telegram:" "$CONFIG_FILE" 2>/dev/null | grep -E "^\s*-\s*" | head -1 | sed 's/.*-[[:space:]]*//' | tr -d '"')
    
    if [ -z "$token" ]; then
        log_error "Telegram 尚未配置，请先完成配置"
        press_enter
        quick_test_menu
        return
    fi
    
    if [ -z "$user_id" ]; then
        read -p "$(echo -e "${YELLOW}输入你的 User ID: ${NC}")" user_id
    fi
    
    test_telegram_bot "$token" "$user_id"
    
    press_enter
    quick_test_menu
}

quick_test_discord() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🎮 测试 Discord 机器人${NC}"
    print_divider
    echo ""
    
    # 读取 Discord 配置
    local token=$(grep -A5 "discord:" "$CONFIG_FILE" 2>/dev/null | grep "token:" | head -1 | sed 's/.*token:[[:space:]]*//' | tr -d '"')
    local channel_id=$(grep -A10 "discord:" "$CONFIG_FILE" 2>/dev/null | grep -E "^\s*-\s*" | head -1 | sed 's/.*-[[:space:]]*//' | tr -d '"')
    
    if [ -z "$token" ]; then
        log_error "Discord 尚未配置，请先完成配置"
        press_enter
        quick_test_menu
        return
    fi
    
    if [ -z "$channel_id" ]; then
        read -p "$(echo -e "${YELLOW}输入频道 ID: ${NC}")" channel_id
    fi
    
    test_discord_bot "$token" "$channel_id"
    
    press_enter
    quick_test_menu
}

quick_test_slack() {
    clear_screen
    print_header
    
    echo -e "${WHITE}💼 测试 Slack 机器人${NC}"
    print_divider
    echo ""
    
    # 读取 Slack 配置
    local bot_token=$(grep "bot_token:" "$CONFIG_FILE" 2>/dev/null | head -1 | sed 's/.*bot_token:[[:space:]]*//' | tr -d '"')
    
    if [ -z "$bot_token" ]; then
        log_error "Slack 尚未配置，请先完成配置"
        press_enter
        quick_test_menu
        return
    fi
    
    test_slack_bot "$bot_token"
    
    press_enter
    quick_test_menu
}

quick_test_ollama() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🟠 测试 Ollama 连接${NC}"
    print_divider
    echo ""
    
    local provider=$(get_config_value "provider")
    local base_url=$(grep "^  base_url:" "$CONFIG_FILE" 2>/dev/null | head -1 | sed 's/.*base_url:[[:space:]]*//' | tr -d '"')
    local model=$(get_config_value "model")
    
    if [ "$provider" != "ollama" ]; then
        echo -e "${YELLOW}当前未配置 Ollama，使用默认地址测试${NC}"
        base_url="http://localhost:11434"
        model="llama3"
    fi
    
    test_ollama_connection "$base_url" "$model"
    
    press_enter
    quick_test_menu
}

quick_test_doctor() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🔍 ClawdBot 诊断${NC}"
    print_divider
    
    run_clawdbot_doctor
    
    press_enter
    quick_test_menu
}

quick_test_status() {
    clear_screen
    print_header
    
    echo -e "${WHITE}📊 ClawdBot 渠道状态${NC}"
    print_divider
    
    run_clawdbot_status
    
    press_enter
    quick_test_menu
}

quick_test_health() {
    clear_screen
    print_header
    
    echo -e "${WHITE}💚 Gateway 健康检查${NC}"
    print_divider
    
    run_clawdbot_health
    
    press_enter
    quick_test_menu
}

run_all_tests() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🔄 运行全部 API 测试${NC}"
    print_divider
    echo ""
    
    echo -e "${YELLOW}正在测试已配置的服务...${NC}"
    echo ""
    
    local total_tests=0
    local passed_tests=0
    
    # 测试 AI
    local provider=$(get_config_value "provider")
    local api_key=$(get_config_value "api_key")
    local model=$(get_config_value "model")
    local base_url=$(grep "^  base_url:" "$CONFIG_FILE" 2>/dev/null | head -1 | sed 's/.*base_url:[[:space:]]*//' | tr -d '"')
    
    if [ -n "$provider" ] && [ -n "$api_key" ] && [ "$api_key" != "your-api-key-here" ]; then
        total_tests=$((total_tests + 1))
        echo -e "${CYAN}[测试 $total_tests] AI API ($provider)${NC}"
        
        local test_url=""
        local http_code=""
        
        case "$provider" in
            anthropic)
                http_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "https://api.anthropic.com/v1/messages" \
                    -H "x-api-key: $api_key" -H "anthropic-version: 2023-06-01" -H "Content-Type: application/json" \
                    -d '{"model":"'$model'","max_tokens":10,"messages":[{"role":"user","content":"hi"}]}' 2>/dev/null)
                ;;
            google)
                http_code=$(curl -s -o /dev/null -w "%{http_code}" \
                    "https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$api_key" \
                    -H "Content-Type: application/json" -d '{"contents":[{"parts":[{"text":"hi"}]}]}' 2>/dev/null)
                ;;
            *)
                test_url="${base_url:-https://api.openai.com/v1}/chat/completions"
                http_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$test_url" \
                    -H "Authorization: Bearer $api_key" -H "Content-Type: application/json" \
                    -d '{"model":"'$model'","messages":[{"role":"user","content":"hi"}],"max_tokens":10}' 2>/dev/null)
                ;;
        esac
        
        if [ "$http_code" = "200" ]; then
            log_info "AI API 测试通过"
            passed_tests=$((passed_tests + 1))
        else
            log_error "AI API 测试失败 (HTTP $http_code)"
        fi
        echo ""
    fi
    
    # 测试 Telegram
    local tg_token=$(grep "token:" "$CONFIG_FILE" 2>/dev/null | head -1 | sed 's/.*token:[[:space:]]*//' | tr -d '"')
    if [ -n "$tg_token" ] && [[ "$tg_token" == *":"* ]]; then
        total_tests=$((total_tests + 1))
        echo -e "${CYAN}[测试 $total_tests] Telegram 机器人${NC}"
        local bot_info=$(curl -s "https://api.telegram.org/bot${tg_token}/getMe" 2>/dev/null)
        if echo "$bot_info" | grep -q '"ok":true'; then
            log_info "Telegram Bot 验证成功"
            passed_tests=$((passed_tests + 1))
        else
            log_error "Telegram Bot 验证失败"
        fi
        echo ""
    fi
    
    # 测试 Discord
    local dc_token=$(grep -A5 "discord:" "$CONFIG_FILE" 2>/dev/null | grep "token:" | head -1 | sed 's/.*token:[[:space:]]*//' | tr -d '"')
    if [ -n "$dc_token" ]; then
        total_tests=$((total_tests + 1))
        echo -e "${CYAN}[测试 $total_tests] Discord 机器人${NC}"
        local bot_info=$(curl -s "https://discord.com/api/v10/users/@me" -H "Authorization: Bot $dc_token" 2>/dev/null)
        if echo "$bot_info" | grep -q '"id"'; then
            log_info "Discord Bot 验证成功"
            passed_tests=$((passed_tests + 1))
        else
            log_error "Discord Bot 验证失败"
        fi
        echo ""
    fi
    
    # 测试 Slack
    local slack_token=$(grep "bot_token:" "$CONFIG_FILE" 2>/dev/null | head -1 | sed 's/.*bot_token:[[:space:]]*//' | tr -d '"')
    if [ -n "$slack_token" ]; then
        total_tests=$((total_tests + 1))
        echo -e "${CYAN}[测试 $total_tests] Slack 机器人${NC}"
        local auth_result=$(curl -s "https://slack.com/api/auth.test" -H "Authorization: Bearer $slack_token" 2>/dev/null)
        if echo "$auth_result" | grep -q '"ok":true'; then
            log_info "Slack 验证成功"
            passed_tests=$((passed_tests + 1))
        else
            log_error "Slack 验证失败"
        fi
        echo ""
    fi
    
    # 汇总结果
    echo ""
    print_divider
    echo ""
    echo -e "${WHITE}测试结果汇总:${NC}"
    echo -e "  总测试数: $total_tests"
    echo -e "  通过: ${GREEN}$passed_tests${NC}"
    echo -e "  失败: ${RED}$((total_tests - passed_tests))${NC}"
    
    if [ $passed_tests -eq $total_tests ] && [ $total_tests -gt 0 ]; then
        echo ""
        echo -e "${GREEN}✓ 所有测试通过！${NC}"
    elif [ $total_tests -eq 0 ]; then
        echo ""
        echo -e "${YELLOW}⚠ 没有可测试的配置，请先完成相关配置${NC}"
    fi
    
    # 如果 ClawdBot 已安装，提示可用的诊断命令
    if check_clawdbot_installed; then
        echo ""
        echo -e "${CYAN}提示: 可使用以下命令进行更详细的诊断:${NC}"
        echo "  • clawdbot doctor  - 健康检查 + 修复建议"
        echo "  • clawdbot status  - 渠道状态"
        echo "  • clawdbot health  - Gateway 健康状态"
    fi
    
    press_enter
    quick_test_menu
}

# ================================ 主菜单 ================================

show_main_menu() {
    clear_screen
    print_header
    
    echo -e "${WHITE}请选择操作:${NC}"
    echo ""
    
    print_menu_item "1" "系统状态" "📊"
    print_menu_item "2" "AI 模型配置" "🤖"
    print_menu_item "3" "消息渠道配置" "📱"
    print_menu_item "4" "身份与个性配置" "👤"
    print_menu_item "5" "安全设置" "🔒"
    print_menu_item "6" "服务管理" "⚡"
    print_menu_item "7" "快速测试" "🧪"
    print_menu_item "8" "高级设置" "🔧"
    print_menu_item "9" "查看当前配置" "📋"
    echo ""
    print_menu_item "0" "退出" "🚪"
    echo ""
    print_divider
}

main() {
    # 检查依赖
    check_dependencies
    
    # 确保配置目录存在
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$LOG_DIR"
    mkdir -p "$DATA_DIR"
    mkdir -p "$SKILLS_DIR"
    mkdir -p "$BACKUP_DIR"
    
    # 主循环
    while true; do
        show_main_menu
        read -p "$(echo -e "${YELLOW}请选择 [0-9]: ${NC}")" choice
        
        case $choice in
            1) show_status ;;
            2) config_ai_model ;;
            3) config_channels ;;
            4) config_identity ;;
            5) config_security ;;
            6) manage_service ;;
            7) quick_test_menu ;;
            8) advanced_settings ;;
            9) view_config ;;
            0)
                echo ""
                echo -e "${CYAN}再见！🦞${NC}"
                exit 0
                ;;
            *)
                log_error "无效选择"
                press_enter
                ;;
        esac
    done
}

# 执行主函数
main "$@"
