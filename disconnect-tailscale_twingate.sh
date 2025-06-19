#!/bin/bash

# Zorin OS Network Disconnect Script
# Author: Gemini
# Date: 2025-06-19

# --- Configuration ---
TWINGATE_COMMAND="sudo twingate disconnect"
TAILSCALE_COMMAND="sudo tailscale down"

# --- Functions ---

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to display a message, using zenity if available
display_message() {
    local title="$1"
    local message="$2"
    local icon="$3" # info, warning, error

    if command_exists zenity; then
        zenity --$icon --title="$title" --text="$message" --width=400 --timeout=5 &> /dev/null
    else
        echo -e "\n--- $title ---\n$message\n"
    fi
}

# Function to ask a confirmation, using zenity if available
ask_confirmation() {
    local title="$1"
    local question="$2"
    local default_no=true # Default to No

    if command_exists zenity; then
        zenity --question --title="$title" --text="$question" --width=400
        if [ $? -eq 0 ]; then # 0 for Yes, 1 for No
            return 0 # User clicked Yes
        else
            return 1 # User clicked No
        fi
    else
        read -p "$question (y/N): " -n 1 -r REPLY
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            return 0 # User typed Y/y
        else
            return 1 # User typed N/n or anything else
        fi
    fi
}

# Function to disconnect Twingate
disconnect_twingate() {
    display_message "Twingate Disconnect" "Attempting to disconnect from Twingate..." "info"
    if ask_confirmation "Confirm Disconnect" "Are you sure you want to disconnect from Twingate?"; then
        if command_exists twingate; then
            echo "Running: $TWINGATE_COMMAND"
            $TWINGATE_COMMAND
            if [ $? -eq 0 ]; then
                display_message "Twingate Status" "Successfully initiated Twingate disconnect." "info"
            else
                display_message "Twingate Error" "Failed to disconnect from Twingate. Please check the terminal for errors. (Might require 'sudo' or Twingate not running)." "error"
            fi
        else
            display_message "Twingate Not Found" "Twingate command not found. Please ensure Twingate is installed and accessible." "warning"
        fi
    else
        display_message "Action Canceled" "Twingate disconnect canceled." "info"
    fi
}

# Function to disconnect Tailscale
disconnect_tailscale() {
    display_message "Tailscale Disconnect" "Attempting to disconnect from Tailscale..." "info"
    if ask_confirmation "Confirm Disconnect" "Are you sure you want to disconnect from Tailscale?"; then
        if command_exists tailscale; then
            echo "Running: $TAILSCALE_COMMAND"
            $TAILSCALE_COMMAND
            if [ $? -eq 0 ]; then
                display_message "Tailscale Status" "Successfully disconnected from Tailscale." "info"
            else
                display_message "Tailscale Error" "Failed to disconnect from Tailscale. Please check the terminal for errors. (Might require 'sudo' or Tailscale not running)." "error"
            fi
        else
            display_message "Tailscale Not Found" "Tailscale command not found. Please ensure Tailscale is installed and accessible." "warning"
        fi
    else
        display_message "Action Canceled" "Tailscale disconnect canceled." "info"
    fi
}

# Main menu function
show_main_menu() {
    local choice=""

    if command_exists zenity; then
        choice=$(zenity --list \
            --title="Network Disconnect Manager" \
            --text="Select an option:" \
            --column="Option" --column="Description" \
            "1" "Disconnect Twingate" \
            "2" "Disconnect Tailscale" \
            "3" "Disconnect Both (Twingate then Tailscale)" \
            "4" "Exit" \
            --height=300 --width=500 --hide-column=1)
    else
        echo -e "\n--- Network Disconnect Manager ---"
        echo "1) Disconnect Twingate"
        echo "2) Disconnect Tailscale"
        echo "3) Disconnect Both (Twingate then Tailscale)"
        echo "4) Exit"
        read -p "Enter your choice (1-4): " choice
    fi

    echo "$choice" # Return the choice
}

# --- Main Logic ---
display_message "Welcome" "Welcome to the Zorin OS Network Disconnect Script.
This script can help you disconnect from Twingate and Tailscale VPNs.
\nMake sure you have 'sudo' privileges if needed for the disconnect commands." "info"

if ! command_exists zenity; then
    display_message "Zenity Not Found" "Zenity (GUI dialog tool) is not installed. The script will use terminal prompts instead.
You can install it with: sudo apt install zenity" "warning"
fi

while true; do
    CHOICE=$(show_main_menu)

    case "$CHOICE" in
        "1" | "Disconnect Twingate")
            disconnect_twingate
            ;;
        "2" | "Disconnect Tailscale")
            disconnect_tailscale
            ;;
        "3" | "Disconnect Both (Twingate then Tailscale)")
            disconnect_twingate
            disconnect_tailscale
            ;;
        "4" | "Exit")
            display_message "Goodbye" "Exiting script. Have a great day!" "info"
            break
            ;;
        *)
            display_message "Invalid Choice" "Invalid option. Please try again." "error"
            ;;
    esac
    # Add a small delay for better zenity visibility on quick actions
    sleep 1
done
