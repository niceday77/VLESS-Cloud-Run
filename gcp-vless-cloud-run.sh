#!/bin/bash

# GCP Cloud Run VLESS Deployment 🚀

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
UUID="3675119c-14fc-46a4-b5f3-9a2c91a7d802"  # Default UUID
REGION="us-central1"
CPU="1"
MEMORY="1Gi"
SERVICE_NAME="free"
HOST_DOMAIN="youtube.com"
VLESS_PATH="/"

# Telegram Variables (Disabled by default)
TELEGRAM_DESTINATION="none"
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHANNEL_ID=""
TELEGRAM_CHAT_ID=""
TELEGRAM_GROUP_ID=""

# Project ID holder (Will be set during auto_deployment_setup)
PROJECT_ID=""

# ------------------------------------------------------------------------------
# 2. UTILITY FUNCTIONS (LOGGING, UI, VALIDATION)
# ------------------------------------------------------------------------------

# Emoji Function
show_emojis() {
    # Define Emojis
    EMOJI_SUCCESS="✅"
    EMOJI_WARN="⚠️"
    EMOJI_ERROR="❌"
    EMOJI_INFO="💡"
    EMOJI_SELECT="🎯"
    EMOJI_DEPLOY="🚀"
    EMOJI_CLEAN="🧹"
    EMOJI_SPINNER="⏳"  # For spinner
    EMOJI_FOLDER="📁"
    EMOJI_LINK="🔗"
}

# Beautiful Header/Banner (New Design: Fully enclosed box, adjusted to title width)
header() {
    local title="$1"
    local border_color="${ORANGE}"
    local text_color="${YELLOW}"
    
    # Calculate title length
    local title_length=${#title}
    local padding=4 # Space on both sides: " | <space> TITLE <space> | "
    local total_width=$((title_length + padding))
    
    # Create top/bottom border line (using Unicode box drawing characters)
    local top_bottom_fill=$(printf '━%.0s' $(seq 1 $((total_width - 2))))
    local top_bottom="${border_color}┏${top_bottom_fill}┓${NC}"
    local bottom_line="${border_color}┗${top_bottom_fill}┛${NC}"
    
    # Create title line
    local title_line="${border_color}┃${NC} ${text_color}${BOLD}${title}${NC} ${border_color}┃${NC}"
    
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
# SPINNER (Replaced Progress Bar - Fixed for smoothness)
# ------------------------------------------------------------------------------
spinner() {
    local label="$1"
    shift
    local command="$*"
    local spinstr='|/-\'
    local i=0

    # Run command in background
    eval "$command" &
    local pid=$!

    # Spinner loop until command finishes
    while kill -0 $pid 2>/dev/null; do
        i=$(((i + 1) % 4))
        printf "\r${BOLD}${EMOJI_SPINNER} ${label}... ${NC}${YELLOW}[${spinstr:$i:1}]${NC}"
        sleep 0.1
    done

    # Wait for command to complete
    wait $pid

    # Clear the line and show done message smoothly
    printf "\r${BOLD}${EMOJI_SPINNER} ${label}... ${NC}${GREEN}${EMOJI_SUCCESS} Done!${NC}\n"
}

# Function to validate UUID format
validate_uuid() {
    local uuid_pattern='^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    if [[ ! $1 =~ $uuid_pattern ]]; then
        warn "Invalid UUID format. Please ensure it is a valid 32-digit hexadecimal number with 4 hyphens. 🔑"
        return 1
    fi
    return 0
}

# ------------------------------------------------------------------------------
# 3. AUTO DEPLOYMENT SETUP (Project ID CLI & API Enablement) - FULLY AUTOMATIC
# ------------------------------------------------------------------------------
auto_deployment_setup() {
    log "Starting initial GCP setup... 🛠️"
    
    # 1. Check and Set Project ID CLI Configuration
    info "Fetching Project ID for CLI configuration. 🔍"
    PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
    
    if [[ -z "$PROJECT_ID" ]]; then
        error "GCP Project ID is not configured in gcloud CLI. Please run 'gcloud config set project [PROJECT_ID]' and try again. ⚠️"
    fi
    
    selected_info "Using configured Project ID: $PROJECT_ID"

    # Set Project ID CLI Configuration (redundant but ensures the current context)
    log "Verifying gcloud CLI active project to: ${PROJECT_ID} 📝"
    spinner "Setting Project ID CLI" "gcloud config set project \"$PROJECT_ID\" --quiet > /dev/null 2>&1"

    # 2. Enable Required APIs
    log "Enabling required APIs (Cloud Run, Container Registry, Cloud Build)... 🔓"
    spinner "Enabling APIs" "gcloud services enable run.googleapis.com containerregistry.googleapis.com cloudbuild.googleapis.com --project \"$PROJECT_ID\" --quiet > /dev/null 2>&1"

    log "Initial GCP setup complete. Proceeding with deployment... 🎉"
    spinner "GCP Setup" "sleep 0.5"  # Short placeholder for setup confirmation
}

# ------------------------------------------------------------------------------
# 4. CORE DEPLOYMENT FUNCTIONS 
# ------------------------------------------------------------------------------

# Clone Repo and Extract Files
clone_and_extract() {
    log "Cloning repository from https://github.com/ahlflk/GCP-VLESS-Cloud-Run.git... 📥"
    spinner "Cloning Repository" "git clone https://github.com/ahlflk/GCP-VLESS-Cloud-Run.git temp-repo > /dev/null 2>&1"

    if [ ! -d "temp-repo" ]; then
        error "Failed to clone repository. Check your network or permissions. 🌐"
    fi
    
    cd temp-repo

    if [ ! -f "Dockerfile" ]; then
        error "Dockerfile not found in repo. 🐳"
    fi
    if [ ! -f "config.json" ]; then
        error "config.json not found in repo. ⚙️"
    fi

    cp Dockerfile ../Dockerfile > /dev/null 2>&1
    cp config.json ../config.json > /dev/null 2>&1
    cd ..
    rm -rf temp-repo > /dev/null 2>&1
}

# Config File Preparation
prepare_config_files() {
    log "Preparing Xray config file for $PROTOCOL... 📄"
    if [[ ! -f "config.json" ]]; then
        error "config.json not found. ❌"
    fi
    spinner "Preparing Config" "sed -i \"s/PLACEHOLDER_UUID/$UUID/g\" config.json && sed -i \"s|/vless|$VLESS_PATH|g\" config.json"
}

# Share Link Creation (VLESS-WS only)
create_share_link() {
    local SERVICE_NAME="$1"
    local DOMAIN="$2"
    local UUID="$3"
    
    # URL Encode path
    local PATH_ENCODED=$(echo "$VLESS_PATH" | sed 's/\//%2F/g')
    
    # Remove https:// from DOMAIN if present
    DOMAIN="${DOMAIN#https://}"
    DOMAIN="${DOMAIN%/}"
    
    local LINK="vless://${UUID}@${HOST_DOMAIN}:443?path=${PATH_ENCODED}&security=tls&encryption=none&host=${DOMAIN}&type=ws&sni=${DOMAIN}#${SERVICE_NAME}_VLESS-WS"
    
    echo "$LINK"
}

# Deploy to Cloud Run
deploy_to_cloud_run() {
    local project_id="$PROJECT_ID"
    # Project ID is now guaranteed to be set by auto_deployment_setup()

    log "Building and pushing Docker image... 🐳"
    spinner "Building Docker Image" "gcloud builds submit --tag gcr.io/$project_id/$SERVICE_NAME:v1 . --quiet > /dev/null 2>&1"

    log "Deploying to Cloud Run service... ☁️"
    spinner "Deploying Service" "gcloud run deploy $SERVICE_NAME --image gcr.io/$project_id/$SERVICE_NAME:v1 --platform managed --region $REGION --allow-unauthenticated --port 8080 --memory $MEMORY --cpu $CPU --quiet > /dev/null 2>&1"

    local service_url=$(gcloud run services describe $SERVICE_NAME --region $REGION --format='value(status.url)' --quiet 2>/dev/null)
    if [[ -z "$service_url" ]]; then
        error "Failed to retrieve service URL after deployment. 🌐"
    fi

    local share_link=$(create_share_link "$SERVICE_NAME" "$service_url" "$UUID")

    log "Deployment completed! 🎉"
    selected_info "Service URL: $service_url"
    selected_info "Share Link: $share_link"
    
    # Print share link clearly at the end
    echo ""
    echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}                    YOUR VLESS CONNECTION LINK                    ${NC}"
    echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}$share_link${NC}"
    echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Create Folder with deployment-info.txt
create_project_folder() {
    local project_id="$PROJECT_ID"
    local service_url=$(gcloud run services describe $SERVICE_NAME --region $REGION --format='value(status.url)' --quiet 2>/dev/null)
    local share_link=$(create_share_link "$SERVICE_NAME" "$service_url" "$UUID")

    log "Saving project files and info to folder: GCP-VLESS-Cloud-Run/ ${EMOJI_FOLDER}"
    mkdir -p GCP-VLESS-Cloud-Run
    # Move/Copy the generated files into the new folder
    mv Dockerfile GCP-VLESS-Cloud-Run/ > /dev/null 2>&1
    mv config.json GCP-VLESS-Cloud-Run/ > /dev/null 2>&1
    
    cat > GCP-VLESS-Cloud-Run/deployment-info.txt << EOF
==============================
GCP VLESS Cloud Run Deployment Info
==============================
Protocol: $PROTOCOL
Region: $REGION
CPU/Memory: $CPU core(s) / $MEMORY
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

# Display main header
header "${EMOJI_DEPLOY} GCP Cloud Run VLESS Deployment"

# Display configuration being used
echo ""
info "Using default configuration:"
selected_info "Region: $REGION"
selected_info "CPU: $CPU core(s)"
selected_info "Memory: $MEMORY"
selected_info "Service Name: $SERVICE_NAME"
selected_info "Host Domain: $HOST_DOMAIN"
selected_info "UUID: $UUID"
selected_info "Telegram: Disabled"
echo ""

# Start auto deployment setup
auto_deployment_setup

# Core Deployment Steps
clone_and_extract
prepare_config_files
deploy_to_cloud_run
create_project_folder 

info "All done! Check your GCP Console for the deployed service. 🎉"
