#!/bin/bash

# GCP Cloud Run VLESS Deployment ??

set -euo pipefail

# ------------------------------------------------------------------------------
# 1. GLOBAL VARIABLES & STYLES
# ------------------------------------------------------------------------------

# ANSI Color Codes
BLUE='\033[94m'
BOLD='\033[1m'
CYAN='\033[96m'
GREEN='\033[92m'
LIGHT_GREEN='\033[1;92m'
NC='\033[0m' # No Color
ORANGE='\033[38;5;208m' # Header Color
RED='\033[91m'
WHITE='\033[1;37m'
YELLOW='\033[93m'

# Global Configuration Variables (Defaults) - Hardcoded to VLESS-WS
PROTOCOL="VLESS-WS"
UUID=""
REGION="us-central1"
CPU="1"
MEMORY="1Gi"
SERVICE_NAME="free"
HOST_DOMAIN="youtube.com"
VLESS_PATH="/"

# Cloud Run Performance Configuration
REQUEST_TIMEOUT="3600"  # seconds (default: 3600 as requested)
MAX_CONCURRENT_REQUESTS="200"  # max concurrent requests per instance (default: 200 as requested)

# Telegram Variables (will be set during selection)
TELEGRAM_DESTINATION="none"
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHANNEL_ID=""
TELEGRAM_CHAT_ID=""
TELEGRAM_GROUP_ID=""

# Project ID holder (Will be set during auto_deployment_setup after Yes/No)
PROJECT_ID=""

# ------------------------------------------------------------------------------
# 2. UTILITY FUNCTIONS (LOGGING, UI, VALIDATION)
# ------------------------------------------------------------------------------

# Emoji Function
show_emojis() {
    # Define Emojis
    EMOJI_SUCCESS="?"
    EMOJI_WARN="??"
    EMOJI_ERROR="?"
    EMOJI_INFO="??"
    EMOJI_SELECT="??"
    EMOJI_DEPLOY="??"
    EMOJI_CLEAN="??"
    EMOJI_SPINNER="?"
    EMOJI_FOLDER="??"
    EMOJI_LINK="??"
    EMOJI_SETTINGS="??"
}

# Beautiful Header/Banner
header() {
    local title="$1"
    local border_color="${ORANGE}"
    local text_color="${YELLOW}"
    
    local title_length=${#title}
    local padding=4
    local total_width=$((title_length + padding))
    
    local top_bottom_fill=$(printf '?%.0s' $(seq 1 $((total_width - 2))))
    local top_bottom="${border_color}?${top_bottom_fill}?${NC}"
    local bottom_line="${border_color}?${top_bottom_fill}?${NC}"
    
    local title_line="${border_color}?${NC} ${text_color}${BOLD}${title}${NC} ${border_color}?${NC}"
    
    echo -e "${top_bottom}"
    echo -e "${title_line}"
    echo -e "${bottom_line}"
}

# Simple Logs with Emoji
log() {
    echo -e "${GREEN}${BOLD}${EMOJI_SUCCESS} [LOG]${NC} ${WHITE}$1${NC}"
}

warn() {
    echo -e "${YELLOW}${BOLD}${EMOJI_WARN} [WARN]${NC} ${WHITE}$1${NC}"
}

error() {
    echo -e "${RED}${BOLD}${EMOJI_ERROR} [ERROR]${NC} ${WHITE}$1${NC}"
    exit 1
}

info() {
    echo -e "${BLUE}${BOLD}${EMOJI_INFO} [INFO]${NC} ${WHITE}$1${NC}"
}

selected_info() {
    echo -e "${GREEN}${BOLD}${EMOJI_SELECT} Selected:${NC} ${CYAN}$1${NC}"
}

# ------------------------------------------------------------------------------
# SPINNER
# ------------------------------------------------------------------------------
spinner() {
    local label="$1"
    shift
    local command="$*"
    local spinstr='|/-\'
    local i=0

    eval "$command" &
    local pid=$!

    while kill -0 $pid 2>/dev/null; do
        i=$(((i + 1) % 4))
        printf "\r${BOLD}${EMOJI_SPINNER} ${label}... ${NC}${YELLOW}[${spinstr:$i:1}]${NC}"
        sleep 0.1
    done

    wait $pid
    printf "\r${BOLD}${EMOJI_SPINNER} ${label}... ${NC}${GREEN}${EMOJI_SUCCESS} Done!${NC}\n"
}

# Function to validate Telegram Bot Token
validate_bot_token() {
    local token_pattern='^[0-9]{8,10}:[a-zA-Z0-9_-]{35}$'
    if [[ ! $1 =~ $token_pattern ]]; then
        warn "Invalid Telegram Bot Token format. Please try again. ??"
        return 1
    fi
    return 0
}

# Function to validate Telegram IDs
validate_id() {
    if [[ ! $1 =~ ^-?[0-9]+$ ]]; then
        warn "Invalid Telegram ID format. Must be a number (e.g., -1001234567890 or 123456789). ??"
        return 1
    fi
    return 0
}

# Function to validate UUID format
validate_uuid() {
    local uuid_pattern='^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    if [[ ! $1 =~ $uuid_pattern ]]; then
        warn "Invalid UUID format. Please ensure it is a valid 32-digit hexadecimal number with 4 hyphens. ??"
        return 1
    fi
    return 0
}

# Function to validate timeout value
validate_timeout() {
    if [[ ! $1 =~ ^[0-9]+$ ]] || [[ $1 -lt 1 ]] || [[ $1 -gt 3600 ]]; then
        warn "Invalid timeout value. Must be between 1 and 3600 seconds. ??"
        return 1
    fi
    return 0
}

# Function to validate concurrent requests
validate_concurrent_requests() {
    if [[ ! $1 =~ ^[0-9]+$ ]] || [[ $1 -lt 1 ]] || [[ $1 -gt 1000 ]]; then
        warn "Invalid concurrent requests value. Must be between 1 and 1000. ??"
        return 1
    fi
    return 0
}

# ------------------------------------------------------------------------------
# 3. USER INPUT FUNCTIONS
# ------------------------------------------------------------------------------

# A. Telegram Destination Selection
select_telegram_destination() {
    header "?? Telegram Notification Settings"
    
    while true; do
        echo -e "${CYAN}Select where to send the deployment link:${NC}"
        echo -e "${BOLD}1.${NC} Don't send to Telegram ${GREEN}[DEFAULT]${NC}"
        echo -e "${BOLD}2.${NC} Send to Channel Only"
        echo -e "${BOLD}3.${NC} Send to Group Only"
        echo -e "${BOLD}4.${NC} Send to Bot Private Message" 
        echo -e "${BOLD}5.${NC} Send to Both Channel and Bot"
        echo
        
        read -p "Select destination (1): " telegram_choice
        telegram_choice=${telegram_choice:-1}
        
        case $telegram_choice in
            1) TELEGRAM_DESTINATION="none"; break ;;
            2) TELEGRAM_DESTINATION="channel"; break ;;
            3) TELEGRAM_DESTINATION="group"; break ;;
            4) TELEGRAM_DESTINATION="bot"; break ;;
            5) TELEGRAM_DESTINATION="both"; break ;;
            *) echo -e "${RED}Invalid selection. Please enter a number between 1-5.${NC}"; continue ;;
        esac
    done

    selected_info "Telegram Destination: $TELEGRAM_DESTINATION"

    if [[ "$TELEGRAM_DESTINATION" != "none" ]]; then
        echo ""
        header "?? Bot Token Configuration"
        while true; do
            read -p "Enter Telegram Bot Token: " TELEGRAM_BOT_TOKEN
            if validate_bot_token "$TELEGRAM_BOT_TOKEN"; then break; else continue; fi
        done
        selected_info "Bot Token: ${TELEGRAM_BOT_TOKEN:0:8}..."
        
        if [[ "$TELEGRAM_DESTINATION" == "channel" || "$TELEGRAM_DESTINATION" == "both" ]]; then
            echo ""
            header "?? Channel ID Configuration"
            while true; do
                read -p "Enter Telegram Channel ID: " TELEGRAM_CHANNEL_ID
                if validate_id "$TELEGRAM_CHANNEL_ID"; then break; fi
            done
            selected_info "Channel ID: $TELEGRAM_CHANNEL_ID"
        fi
        
        if [[ "$TELEGRAM_DESTINATION" == "bot" || "$TELEGRAM_DESTINATION" == "both" ]]; then
            echo ""
            header "?? Chat ID Configuration"
            while true; do
                read -p "Enter your Chat ID (for bot private message): " TELEGRAM_CHAT_ID
                if validate_id "$TELEGRAM_CHAT_ID"; then break; fi
            done
            selected_info "Chat ID: $TELEGRAM_CHAT_ID"
        fi
        
        if [[ "$TELEGRAM_DESTINATION" == "group" ]]; then
            echo ""
            header "?? Group ID Configuration"
            while true; do
                read -p "Enter Telegram Group ID: " TELEGRAM_GROUP_ID
                if validate_id "$TELEGRAM_GROUP_ID"; then break; fi
            done
            selected_info "Group ID: $TELEGRAM_GROUP_ID"
        fi
    fi
    
    echo ""
}

# B. Region Selection
select_region() {
    header "?? GCP Region Selection"
    echo -e "${CYAN}Available GCP Regions:${NC}"
    echo -e "${BOLD}1.${NC}  ???? us-central1 (Council Bluffs, Iowa, North America) ${GREEN}[DEFAULT]${NC}"
    echo -e "${BOLD}2.${NC}  ???? us-east1 (Moncks Corner, South Carolina, North America)" 
    echo -e "${BOLD}3.${NC}  ???? us-south1 (Dallas, Texas, North America)"
    echo -e "${BOLD}4.${NC}  ???? us-west1 (The Dalles, Oregon, North America)"
    echo -e "${BOLD}5.${NC}  ???? us-west2 (Los Angeles, California, North America)"
    echo -e "${BOLD}6.${NC}  ???? northamerica-northeast2 (Toronto, Ontario, North America)"
    echo -e "${BOLD}7.${NC}  ???? asia-southeast1 (Jurong West, Singapore)"
    echo -e "${BOLD}8.${NC}  ???? asia-northeast1 (Tokyo, Japan)"
    echo -e "${BOLD}9.${NC}  ???? asia-east1 (Changhua County, Taiwan)"
    echo -e "${BOLD}10.${NC} ???? asia-east2 (Hong Kong)"
    echo -e "${BOLD}11.${NC} ???? asia-south1 (Mumbai, India)"
    echo -e "${BOLD}12.${NC} ???? asia-southeast2 (Jakarta, Indonesia)${NC}"
    echo
    
    while true; do
        read -p "Select region (1): " region_choice
        region_choice=${region_choice:-1}
        case $region_choice in
            1) REGION="us-central1"; break ;;
            2) REGION="us-east1"; break ;;
            3) REGION="us-south1"; break ;;
            4) REGION="us-west1"; break ;;
            5) REGION="us-west2"; break ;;
            6) REGION="northamerica-northeast2"; break ;;
            7) REGION="asia-southeast1"; break ;;
            8) REGION="asia-northeast1"; break ;;
            9) REGION="asia-east1"; break ;;
            10) REGION="asia-east2"; break ;;
            11) REGION="asia-south1"; break ;;
            12) REGION="asia-southeast2"; break ;;
            *) echo -e "${RED}Invalid selection. Please enter a number between 1-12.${NC}" ;;
        esac
    done
    
    selected_info "Region: $REGION"
    echo ""
}

# C. CPU Configuration
select_cpu() {
    header "???  CPU Configuration"
    echo -e "${CYAN}Available Options:${NC}"
    echo -e "${BOLD}1.${NC} 1  CPU Core (Lightweight traffic) ${GREEN}[DEFAULT]${NC}"
    echo -e "${BOLD}2.${NC} 2  CPU Cores (Balanced)"
    echo -e "${BOLD}3.${NC} 4  CPU Cores (Performance)"
    echo -e "${BOLD}4.${NC} 8  CPU Cores (High Performance)"
    echo -e "${BOLD}5.${NC} 16 CPU Cores (Extreme Load)" 
    echo
    
    while true; do
        read -p "Select CPU cores (1): " cpu_choice
        cpu_choice=${cpu_choice:-1}
        case $cpu_choice in
            1) CPU="1"; break ;;
            2) CPU="2"; break ;;
            3) CPU="4"; break ;;
            4) CPU="8"; break ;;
            5) CPU="16"; break ;;
            *) echo -e "${RED}Invalid selection. Please enter a number between 1-5.${NC}" ;;
        esac
    done
    
    selected_info "CPU: $CPU core(s)"
    echo ""
}

# D. Memory Configuration
select_memory() {
    header "?? Memory Configuration"    
    echo -e "${CYAN}Available Options:${NC}"
    echo -e "${BOLD}1.${NC} 512Mi (Minimum requirement)"
    echo -e "${BOLD}2.${NC} 1Gi (Basic usage) ${GREEN}[DEFAULT]${NC}"
    echo -e "${BOLD}3.${NC} 2Gi (Balanced usage)"
    echo -e "${BOLD}4.${NC} 4Gi (Moderate performance)"
    echo -e "${BOLD}5.${NC} 8Gi (High load/many connections)"
    echo -e "${BOLD}6.${NC} 16Gi (Advanced/Extreme load)"
    echo -e "${BOLD}7.${NC} 32Gi (Maximum limit for Cloud Run)"
    echo
    
    while true; do
        read -p "Select memory (2): " memory_choice
        memory_choice=${memory_choice:-2}
        case $memory_choice in
            1) MEMORY="512Mi"; break ;;
            2) MEMORY="1Gi"; break ;;
            3) MEMORY="2Gi"; break ;;
            4) MEMORY="4Gi"; break ;;
            5) MEMORY="8Gi"; break ;;
            6) MEMORY="16Gi"; break ;;
            7) MEMORY="32Gi"; break ;;
            *) echo -e "${RED}Invalid selection. Please enter a number between 1-7.${NC}" ;;
        esac
    done
    
    selected_info "Memory: $MEMORY"
    echo ""
}

# E. Service Name Configuration
select_service_name() {
    header "?? Service Name Configuration"
    
    echo -e "${CYAN}Deployment Service Name (Default: free):${NC}"
    
    read -p "Enter custom name or press Enter to use default: " custom_name
    SERVICE_NAME=${custom_name:-$SERVICE_NAME}
    
    if [[ -z "$SERVICE_NAME" ]]; then
        warn "Service name cannot be empty. Using default: free."
        SERVICE_NAME="free"
    fi
    
    selected_info "Service Name: $SERVICE_NAME"
    echo ""
}

# F. Host Domain Configuration
select_host_domain() {
    header "?? Host Domain Configuration"
    
    echo -e "${CYAN}SNI/Host Domain (Default: youtube.com):${NC}"
    
    read -p "Enter custom domain or press Enter to use default: " custom_domain
    HOST_DOMAIN=${custom_domain:-$HOST_DOMAIN}
    
    if [[ -z "$HOST_DOMAIN" ]]; then
        warn "Host Domain cannot be empty. Using default: youtube.com."
        HOST_DOMAIN="youtube.com"
    fi
    
    selected_info "Host Domain: $HOST_DOMAIN"
    echo ""
}

# G. UUID Configuration
select_uuid() {
    header "?? UUID Configuration"
    
    local default_uuid="33d55e97-26ab-4e59-9f37-7a944044baaa"
        
    while true; do
        echo -e "${CYAN}UUID Options:${NC}"
        echo -e "${BOLD}1.${NC} Use Default UUID (33d5...baaa) ${GREEN}[DEFAULT]${NC}"
        echo -e "${BOLD}2.${NC} Generate New UUID"
        echo -e "${CYAN}You can also paste a custom UUID directly, or press Enter for default.${NC}"
        echo

        read -p "Enter 1, 2, or Paste Custom UUID: " uuid_input
        uuid_input=${uuid_input:-1}

        if [[ "$uuid_input" == "1" ]]; then
            UUID="$default_uuid"
            log "Using Default UUID: $UUID ?"
            break
        elif [[ "$uuid_input" == "2" ]]; then
            if command -v uuidgen &> /dev/null; then
                UUID=$(uuidgen)
            else
                UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "33d55e97-26ab-4e59-9f37-7a944044baaa")
                if [[ "$UUID" == "33d55e97-26ab-4e59-9f37-7a944044baaa" ]]; then
                    warn "uuidgen not found. Using default UUID: $UUID ??"
                fi
            fi
            log "Generated New UUID: $UUID ?"
            break
        elif validate_uuid "$uuid_input"; then
            UUID="$uuid_input"
            log "Using Custom UUID: $UUID ?"
            break
        else
            echo -e "${RED}Invalid input. Please enter 1, 2, or a valid custom UUID.${NC}" 
        fi
    done
    
    selected_info "UUID: $UUID"
    echo ""
}

# H. Request Timeout Configuration (NEW)
select_request_timeout() {
    header "?? Request Timeout Configuration"
    
    echo -e "${CYAN}Configure request timeout for Cloud Run service.${NC}"
    echo -e "${CYAN}Default value: 3600 seconds (1 hour)${NC}"
    echo -e "${YELLOW}Valid range: 1 - 3600 seconds${NC}"
    echo
    
    while true; do
        read -p "Enter request timeout in seconds (3600): " timeout_input
        timeout_input=${timeout_input:-3600}
        
        if validate_timeout "$timeout_input"; then
            REQUEST_TIMEOUT="$timeout_input"
            break
        fi
    done
    
    local timeout_display=""
    if [[ $REQUEST_TIMEOUT -ge 3600 ]]; then
        timeout_display="$((REQUEST_TIMEOUT / 3600)) hour(s)"
    elif [[ $REQUEST_TIMEOUT -ge 60 ]]; then
        timeout_display="$((REQUEST_TIMEOUT / 60)) minute(s)"
    else
        timeout_display="${REQUEST_TIMEOUT} second(s)"
    fi
    
    selected_info "Request Timeout: ${REQUEST_TIMEOUT} seconds (${timeout_display})"
    echo ""
}

# I. Maximum Concurrent Requests Configuration (NEW)
select_max_concurrent_requests() {
    header "?? Maximum Concurrent Requests Configuration"
    
    echo -e "${CYAN}Configure maximum concurrent requests per container instance.${NC}"
    echo -e "${CYAN}Default value: 200 concurrent requests${NC}"
    echo -e "${YELLOW}Valid range: 1 - 1000 requests${NC}"
    echo -e "${YELLOW}Higher values allow better utilization but may increase latency${NC}"
    echo
    
    while true; do
        read -p "Enter max concurrent requests (200): " concurrency_input
        concurrency_input=${concurrency_input:-200}
        
        if validate_concurrent_requests "$concurrency_input"; then
            MAX_CONCURRENT_REQUESTS="$concurrency_input"
            break
        fi
    done
    
    selected_info "Max Concurrent Requests: $MAX_CONCURRENT_REQUESTS per instance"
    echo ""
}

# J. Summary and Confirmation
show_config_summary() {
    local temp_project_id=$(gcloud config get-value project 2>/dev/null || echo "Not Configured")
    
    header "?? Configuration Summary"
    
    printf "${CYAN}${BOLD}%-30s${NC} %s\n" "Project ID:" "$temp_project_id"
    printf "${CYAN}${BOLD}%-30s${NC} %s\n" "Protocol:" "$PROTOCOL"
    printf "${CYAN}${BOLD}%-30s${NC} %s\n" "Region:" "$REGION"
    printf "${CYAN}${BOLD}%-30s${NC} %s\n" "Service Name:" "$SERVICE_NAME"
    printf "${CYAN}${BOLD}%-30s${NC} %s\n" "Host Domain:" "$HOST_DOMAIN"
    printf "${CYAN}${BOLD}%-30s${NC} %s\n" "UUID:" "$UUID"
    printf "${CYAN}${BOLD}%-30s${NC} %s\n" "Path:" "$VLESS_PATH"
    printf "${CYAN}${BOLD}%-30s${NC} %s\n" "CPU/Memory:" "$CPU core(s) / $MEMORY"
    printf "${CYAN}${BOLD}%-30s${NC} %s\n" "Request Timeout:" "$REQUEST_TIMEOUT seconds"
    printf "${CYAN}${BOLD}%-30s${NC} %s\n" "Max Concurrent Requests:" "$MAX_CONCURRENT_REQUESTS per instance"
    
    if [[ "$TELEGRAM_DESTINATION" != "none" ]]; then
        printf "${CYAN}${BOLD}%-30s${NC} %s\n" "Telegram:" "$TELEGRAM_DESTINATION (Token: ${TELEGRAM_BOT_TOKEN:0:8}...)"
    else
        printf "${CYAN}${BOLD}%-30s${NC} %s\n" "Telegram:" "Not configured"
    fi
    echo
    
    while true; do
        read -p "$(echo -e "${ORANGE}${BOLD}Proceed with deployment? (y/n): ${NC}")" confirm
        case $confirm in
            [Yy]* ) 
                auto_deployment_setup
                break
                ;;
            [Nn]* ) 
                info "Deployment cancelled by user. ??"
                exit 0
                ;;
            * ) 
                warn "Please answer yes (y) or no (n).${NC}"
                ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# AUTO DEPLOYMENT SETUP
# ------------------------------------------------------------------------------
auto_deployment_setup() {
    log "Starting initial GCP setup... ???"
    
    info "Fetching Project ID for CLI configuration. ??"
    PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
    
    if [[ -z "$PROJECT_ID" ]]; then
        error "GCP Project ID is not configured in gcloud CLI. Please run 'gcloud config set project [PROJECT_ID]' and try again. ??"
    fi
    
    selected_info "Using configured Project ID: $PROJECT_ID"

    log "Verifying gcloud CLI active project to: ${PROJECT_ID} ??"
    spinner "Setting Project ID CLI" "gcloud config set project \"$PROJECT_ID\" --quiet > /dev/null 2>&1"

    log "Enabling required APIs (Cloud Run, Container Registry, Cloud Build)... ??"
    spinner "Enabling APIs" "gcloud services enable run.googleapis.com containerregistry.googleapis.com cloudbuild.googleapis.com --project \"$PROJECT_ID\" --quiet > /dev/null 2>&1"

    log "Initial GCP setup complete. Proceeding with deployment... ??"
    spinner "GCP Setup" "sleep 0.5"
}

# ------------------------------------------------------------------------------
# 4. CORE DEPLOYMENT FUNCTIONS 
# ------------------------------------------------------------------------------

# Clone Repo and Extract Files
clone_and_extract() {
    log "Cloning repository from https://github.com/ahlflk/GCP-VLESS-Cloud-Run.git... ??"
    spinner "Cloning Repository" "git clone https://github.com/ahlflk/GCP-VLESS-Cloud-Run.git temp-repo > /dev/null 2>&1"

    if [ ! -d "temp-repo" ]; then
        error "Failed to clone repository. Check your network or permissions. ??"
    fi
    
    cd temp-repo

    if [ ! -f "Dockerfile" ]; then
        error "Dockerfile not found in repo. ??"
    fi
    if [ ! -f "config.json" ]; then
        error "config.json not found in repo. ??"
    fi

    cp Dockerfile ../Dockerfile > /dev/null 2>&1
    cp config.json ../config.json > /dev/null 2>&1
    cd ..
    rm -rf temp-repo > /dev/null 2>&1
}

# Config File Preparation
prepare_config_files() {
    log "Preparing Xray config file for $PROTOCOL... ??"
    if [[ ! -f "config.json" ]]; then
        error "config.json not found. ?"
    fi
    spinner "Preparing Config" "sed -i \"s/PLACEHOLDER_UUID/$UUID/g\" config.json && sed -i \"s|/vless|$VLESS_PATH|g\" config.json"
}

# Share Link Creation
create_share_link() {
    local SERVICE_NAME="$1"
    local DOMAIN="$2"
    local UUID="$3"
    
    local PATH_ENCODED=$(echo "$VLESS_PATH" | sed 's/\//%2F/g')
    
    DOMAIN="${DOMAIN#https://}"
    DOMAIN="${DOMAIN%/}"
    
    local LINK="vless://${UUID}@${HOST_DOMAIN}:443?path=${PATH_ENCODED}&security=tls&encryption=none&host=${DOMAIN}&type=ws&sni=${DOMAIN}#${SERVICE_NAME}_VLESS-WS"
    
    echo "$LINK"
}

# Telegram Notification Function
send_to_telegram() {
    local chat_id="$1"
    local message="$2"
    message=$(echo "$message" | sed 's/"/\\"/g')
    
    curl -s -o /dev/null -w "%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -d "{\"chat_id\": \"${chat_id}\", \"text\": \"${message}\", \"parse_mode\": \"HTML\", \"disable_web_page_preview\": true}" \
        https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage
}

send_deployment_notification() {
    local message="$1"
    
    case $TELEGRAM_DESTINATION in
        "channel")
            send_to_telegram "$TELEGRAM_CHANNEL_ID" "$message" > /dev/null 2>&1
            log "Notification sent to Telegram Channel. ??"
            ;;
        "bot")
            send_to_telegram "$TELEGRAM_CHAT_ID" "$message" > /dev/null 2>&1
            log "Notification sent to Bot private message. ??"
            ;;
        "group")
            send_to_telegram "$TELEGRAM_GROUP_ID" "$message" > /dev/null 2>&1
            log "Notification sent to Telegram Group. ??"
            ;;
        "both")
            send_to_telegram "$TELEGRAM_CHANNEL_ID" "$message" > /dev/null 2>&1
            send_to_telegram "$TELEGRAM_CHAT_ID" "$message" > /dev/null 2>&1
            log "Notification sent to both Channel and Bot. ??"
            ;;
        "none")
            log "Skipping Telegram notification. ??"
            ;;
    esac
}

# Deploy to Cloud Run with enhanced configuration
deploy_to_cloud_run() {
    local project_id="$PROJECT_ID"

    log "Building and pushing Docker image... ??"
    spinner "Building Docker Image" "gcloud builds submit --tag gcr.io/$project_id/$SERVICE_NAME:v1 . --quiet > /dev/null 2>&1"

    log "Deploying to Cloud Run service with enhanced settings... ??"
    
    # Build the deployment command with timeout and concurrency settings
    local deploy_cmd="gcloud run deploy $SERVICE_NAME \
        --image gcr.io/$project_id/$SERVICE_NAME:v1 \
        --platform managed \
        --region $REGION \
        --allow-unauthenticated \
        --port 8080 \
        --memory $MEMORY \
        --cpu $CPU \
        --timeout ${REQUEST_TIMEOUT}s \
        --concurrency $MAX_CONCURRENT_REQUESTS \
        --quiet"
    
    spinner "Deploying Service" "$deploy_cmd > /dev/null 2>&1"

    local service_url=$(gcloud run services describe $SERVICE_NAME --region $REGION --format='value(status.url)' --quiet 2>/dev/null)
    if [[ -z "$service_url" ]]; then
        error "Failed to retrieve service URL after deployment. ??"
    fi

    local share_link=$(create_share_link "$SERVICE_NAME" "$service_url" "$UUID")

    log "Deployment completed! ??"
    selected_info "Service URL: $service_url"
    selected_info "Share Link: $share_link"
    selected_info "Request Timeout: ${REQUEST_TIMEOUT}s"
    selected_info "Max Concurrent Requests: $MAX_CONCURRENT_REQUESTS"

    # Create enhanced Telegram message
    local timeout_display=""
    if [[ $REQUEST_TIMEOUT -ge 3600 ]]; then
        timeout_display="$((REQUEST_TIMEOUT / 3600)) hour(s)"
    elif [[ $REQUEST_TIMEOUT -ge 60 ]]; then
        timeout_display="$((REQUEST_TIMEOUT / 60)) minute(s)"
    else
        timeout_display="${REQUEST_TIMEOUT} second(s)"
    fi
    
    local telegram_message="?? <b>GCP V2Ray Deployment Complete!</b>

?? <b>Details:</b>

<blockquote>?? <b>Protocol:</b> ${PROTOCOL}

??? <b>Region:</b> ${REGION}

??/?? <b>CPU/Memory:</b> ${CPU} core(s) / ${MEMORY}

?? <b>Request Timeout:</b> ${timeout_display}

?? <b>Max Concurrent Requests:</b> ${MAX_CONCURRENT_REQUESTS}</blockquote>

<b>?? Share Link:</b>

<pre><code>${share_link}</code></pre>"
    
    send_deployment_notification "$telegram_message"
}

# Create Folder with deployment-info.txt
create_project_folder() {
    local project_id="$PROJECT_ID"
    local service_url=$(gcloud run services describe $SERVICE_NAME --region $REGION --format='value(status.url)' --quiet 2>/dev/null)
    local share_link=$(create_share_link "$SERVICE_NAME" "$service_url" "$UUID")

    log "Saving project files and info to folder: GCP-VLESS-Cloud-Run/ ${EMOJI_FOLDER}"
    mkdir -p GCP-VLESS-Cloud-Run
    mv Dockerfile GCP-VLESS-Cloud-Run/ > /dev/null 2>&1
    mv config.json GCP-VLESS-Cloud-Run/ > /dev/null 2>&1
    
    cat > GCP-VLESS-Cloud-Run/deployment-info.txt << EOF
==============================
GCP VLESS Cloud Run Deployment Info
==============================
Protocol: $PROTOCOL
Region: $REGION
CPU/Memory: $CPU core(s) / $MEMORY
Request Timeout: ${REQUEST_TIMEOUT} seconds
Max Concurrent Requests: ${MAX_CONCURRENT_REQUESTS}
==============================
Share Link: $share_link
==============================
Project ID: $project_id
Deployment Date: $(date)
==============================
EOF
    
    log "Project files and info saved successfully in: GCP-VLESS-Cloud-Run/ ${EMOJI_FOLDER}"
    info "Check the 'GCP-VLESS-Cloud-Run' folder for your deployment files and details. ${EMOJI_FOLDER}" 
}

# ------------------------------------------------------------------------------
# 5. MAIN EXECUTION BLOCK
# ------------------------------------------------------------------------------

# Initialize emojis
show_emojis

# Run user input functions in specified order
run_user_inputs() {
    header "${EMOJI_DEPLOY} GCP Cloud Run VLESS Deployment"
    select_telegram_destination
    select_region
    select_cpu
    select_memory
    select_service_name
    select_host_domain
    select_uuid
    select_request_timeout          # NEW: Request timeout configuration
    select_max_concurrent_requests  # NEW: Max concurrent requests configuration
    show_config_summary
}

# Main execution
run_user_inputs

# Core Deployment Steps
clone_and_extract
prepare_config_files
deploy_to_cloud_run
create_project_folder 

info "All done! Check your GCP Console for the deployed service. ??"