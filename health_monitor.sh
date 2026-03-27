#!/usr/bin/env bash

GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
RESET="\e[0m"

LOG_FILE="/var/log/health_monitor.log"
DRY_RUN=false

# Handle --dry-run flag
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
fi

# Check if services.txt exists
if [[ ! -f services.txt ]]; then
    echo "ERROR: services.txt not found!"
    exit 1
fi

# Check if file is empty
if [[ ! -s services.txt ]]; then
    echo "ERROR: services.txt is empty!"
    exit 1
fi

total=0
healthy=0
recovered=0
failed=0

log_event() {
    local level=$1
    local message=$2
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message" | sudo tee -a $LOG_FILE > /dev/null
}

echo "Running Health Monitor..."
echo "User: $(whoami) | Host: $(hostname)"
echo "----------------------------------"

while read -r service; do

    [[ -z "$service" || "$service" =~ ^# ]] && continue

    ((total++))
    systemctl list-unit-files | grep -q "^$service.service"
    if [[ $? -ne 0 ]]; then
        echo "⚠ $service does not exist, skipping..."
        log_event "WARNING" "$service not found"
        continue
    fi

    status=$(systemctl is-active "$service")
    if [[ "$status" == "active" ]]; then
        echo -e "${GREEN}✔ $service is running${RESET}"
        log_event "INFO" "$service is healthy"
	((healthy++))
    else
        echo -e "${RED}✖ $service is NOT running. Attempting restart...${RESET}"

        if [[ "$DRY_RUN" == true ]]; then
            echo "[DRY RUN] Would restart $service"
            continue
        fi

        sudo systemctl restart "$service"
        sleep 5

        new_status=$(systemctl is-active "$service")

        if [[ "$new_status" == "active" ]]; then
            echo -e "${GREEN}✔ $service recovered${RESET}"
            log_event "RECOVERED" "$service restarted successfully"
            ((recovered++))
        else
            echo "✖ $service failed to recover"
            log_event "FAILED" "$service restart failed"
            ((failed++))
        fi
    fi

done < services.txt

# Summary
echo ""
echo "===== SUMMARY ====="
echo "Total Checked : $total"
echo "Healthy       : $healthy"
echo "Recovered     : $recovered"
echo "Failed        : $failed"
