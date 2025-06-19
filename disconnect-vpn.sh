#!/bin/bash

# Zorin OS Connection Disconnect Tool

# This script provides an interactive terminal-based menu to
# force disconnect from Twingate and Tailscale connections.
# It uses 'whiptail' for the interactive "GUI" experience.

# --- Configuration ---
# Set the title for the whiptail dialog
DIALOG_TITLE="VPN Connection Disconnect Tool"
# Set the backend for the whiptail dialog (can be 'dialog' if 'whiptail' is not preferred or available)
DIALOG_BACKEND="whiptail"

# --- Function Definitions ---

# Function to check for 'whiptail' (or 'dialog') installation
check_dialog_backend() {
    if ! command -v "$DIALOG_BACKEND" &> /dev/null; then
        echo "Error: The '$DIALOG_BACKEND' command is not found."
        echo "This script requires '$DIALOG_BACKEND' for its interactive interface."
        echo "Please install it using: sudo apt update && sudo apt install $DIALOG_BACKEND"
        exit 1
    fi
}

# Function to display a message using the chosen dialog backend
display_message() {
    local title="$1"
    local message="$2"
    local height="$3"
    local width="$4"
    "$DIALOG_BACKEND" --title "$title" --msgbox "$message" "$height" "$width"
}

# Function to disconnect Twingate
disconnect_twingate() {
    display_message "$DIALOG_TITLE" "Attempting to disconnect Twingate..." 10 60
    echo "Running: twingate stop" # No sudo here, as the script is expected to be run with sudo
    if twingate stop; then
        display_message "$DIALOG_TITLE" "Twingate disconnected successfully." 10 60
        return 0
    else
        display_message "$DIALOG_TITLE" "Failed to disconnect Twingate. Check if it's running." 10 70
        return 1
    fi
}

# Function to disconnect Tailscale
disconnect_tailscale() {
    display_message "$DIALOG_TITLE" "Attempting to disconnect Tailscale..." 10 60
    echo "Running: tailscale down" # No sudo here, as the script is expected to be run with sudo
    if tailscale down; then
        display_message "$DIALOG_TITLE" "Tailscale disconnected successfully." 10 60
        return 0
    else
        display_message "$DIALOG_TITLE" "Failed to disconnect Tailscale. Check if it's running." 10 70
        return 1
    fi
}

# --- Main Script Logic ---

# Ensure the script is run with bash
if [ -z "$BASH_VERSION" ]; then
    echo "Please run this script with bash: bash $0"
    exit 1
fi

# IMPORTANT: Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "This script requires root privileges. Please run it with sudo:"
    echo "sudo ./disconnect_vpn.sh"
    exit 1
fi

# Check if the dialog backend is installed
check_dialog_backend

# Main menu loop
while true; do
    CHOICE=$("$DIALOG_BACKEND" --title "$DIALOG_TITLE" --menu "Select an action to perform:" 15 70 4 \
        "1" "Disconnect Twingate" \
        "2" "Disconnect Tailscale" \
        "3" "Disconnect Both (Twingate & Tailscale)" \
        "4" "Exit" 3>&1 1>&2 2>&3)

    # Check for cancellation (ESC key or Cancel button)
    if [ $? -ne 0 ]; then
        display_message "$DIALOG_TITLE" "Operation cancelled by user. Exiting." 10 60
        break
    fi

    case "$CHOICE" in
        1)
            disconnect_twingate
            ;;
        2)
            disconnect_tailscale
            ;;
        3)
            disconnect_twingate
            disconnect_tailscale
            ;;
        4)
            display_message "$DIALOG_TITLE" "Exiting the VPN Disconnect Tool. Goodbye!" 10 60
            break
            ;;
        *)
            display_message "$DIALOG_TITLE" "Invalid choice. Please select a valid option." 10 60
            ;;
    esac

    # Give a moment for the user to read success/failure messages before looping
    sleep 1
done

exit 0
