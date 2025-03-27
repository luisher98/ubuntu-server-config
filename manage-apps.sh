#!/bin/bash

# Exit on error
set -e

# Function to check if yq is installed
check_yq() {
    if ! command -v yq &> /dev/null; then
        echo "Error: yq is not installed. Please install it first."
        exit 1
    fi
}

# Function to validate apps.yaml
validate_config() {
    if [ ! -f "apps.yaml" ]; then
        echo "Error: apps.yaml not found"
        exit 1
    fi
}

# Function to list all application groups
list_groups() {
    echo "Available application groups:"
    yq e '.groups | keys | .[]' apps.yaml | while read -r group; do
        echo "- $group"
        echo "  Applications:"
        yq e ".groups.$group.apps | keys | .[]" apps.yaml | while read -r app; do
            echo "    - $app"
        done
    done
}

# Function to add a new application group
add_group() {
    local group_name=$1
    local group_path=$2

    # Check if group already exists
    if yq e ".groups.$group_name" apps.yaml > /dev/null 2>&1; then
        echo "Error: Group '$group_name' already exists"
        exit 1
    fi

    # Add new group to apps.yaml
    yq e ".groups.$group_name = {\"name\": \"$group_name\", \"path\": \"$group_path\", \"apps\": {}}" -i apps.yaml

    # Create directory
    mkdir -p "$group_path"

    echo "Added new group: $group_name"
}

# Function to add a new application to a group
add_app() {
    local group_name=$1
    local app_name=$2
    local app_repo=$3
    local app_port=$4

    # Check if group exists
    if ! yq e ".groups.$group_name" apps.yaml > /dev/null 2>&1; then
        echo "Error: Group '$group_name' does not exist"
        exit 1
    fi

    # Check if app already exists
    if yq e ".groups.$group_name.apps.$app_name" apps.yaml > /dev/null 2>&1; then
        echo "Error: Application '$app_name' already exists in group '$group_name'"
        exit 1
    fi

    # Add new app to apps.yaml
    yq e ".groups.$group_name.apps.$app_name = {
        \"name\": \"$app_name\",
        \"repo\": \"$app_repo\",
        \"branch\": \"main\",
        \"port\": $app_port,
        \"env_template\": \"# Add your environment variables here\\n\",
        \"resources\": {
            \"limits\": {
                \"cpus\": \"1\",
                \"memory\": \"1G\"
            },
            \"reservations\": {
                \"cpus\": \"0.5\",
                \"memory\": \"512M\"
            }
        },
        \"healthcheck\": {
            \"endpoint\": \"/health\",
            \"interval\": \"30s\",
            \"timeout\": \"10s\",
            \"retries\": 3
        }
    }" -i apps.yaml

    # Clone repository
    local group_path=$(yq e ".groups.$group_name.path" apps.yaml)
    local app_path="$group_path/$app_name"
    git clone "$app_repo" "$app_path"

    # Copy setup script
    cp setup-env.sh "$app_path/"
    chmod +x "$app_path/setup-env.sh"

    echo "Added new application: $app_name to group: $group_name"
}

# Function to remove an application group
remove_group() {
    local group_name=$1

    # Check if group exists
    if ! yq e ".groups.$group_name" apps.yaml > /dev/null 2>&1; then
        echo "Error: Group '$group_name' does not exist"
        exit 1
    fi

    # Get group path
    local group_path=$(yq e ".groups.$group_name.path" apps.yaml)

    # Remove from apps.yaml
    yq e "del(.groups.$group_name)" -i apps.yaml

    # Remove directory
    rm -rf "$group_path"

    echo "Removed group: $group_name"
}

# Function to remove an application from a group
remove_app() {
    local group_name=$1
    local app_name=$2

    # Check if group exists
    if ! yq e ".groups.$group_name" apps.yaml > /dev/null 2>&1; then
        echo "Error: Group '$group_name' does not exist"
        exit 1
    fi

    # Check if app exists
    if ! yq e ".groups.$group_name.apps.$app_name" apps.yaml > /dev/null 2>&1; then
        echo "Error: Application '$app_name' does not exist in group '$group_name'"
        exit 1
    fi

    # Get app path
    local group_path=$(yq e ".groups.$group_name.path" apps.yaml)
    local app_path="$group_path/$app_name"

    # Remove from apps.yaml
    yq e "del(.groups.$group_name.apps.$app_name)" -i apps.yaml

    # Remove directory
    rm -rf "$app_path"

    echo "Removed application: $app_name from group: $group_name"
}

# Main script
check_yq
validate_config

case "$1" in
    "list")
        list_groups
        ;;
    "add-group")
        if [ "$#" -ne 3 ]; then
            echo "Usage: $0 add-group <group_name> <group_path>"
            exit 1
        fi
        add_group "$2" "$3"
        ;;
    "add-app")
        if [ "$#" -ne 5 ]; then
            echo "Usage: $0 add-app <group_name> <app_name> <repo_url> <port>"
            exit 1
        fi
        add_app "$2" "$3" "$4" "$5"
        ;;
    "remove-group")
        if [ "$#" -ne 2 ]; then
            echo "Usage: $0 remove-group <group_name>"
            exit 1
        fi
        remove_group "$2"
        ;;
    "remove-app")
        if [ "$#" -ne 3 ]; then
            echo "Usage: $0 remove-app <group_name> <app_name>"
            exit 1
        fi
        remove_app "$2" "$3"
        ;;
    *)
        echo "Usage:"
        echo "  $0 list                    # List all application groups and apps"
        echo "  $0 add-group <name> <path> # Add a new application group"
        echo "  $0 add-app <group> <name> <repo> <port> # Add a new application"
        echo "  $0 remove-group <name>     # Remove an application group"
        echo "  $0 remove-app <group> <name> # Remove an application"
        exit 1
        ;;
esac 