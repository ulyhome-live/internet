#!/bin/bash

set -e

# === Dependency Check ===
for cmd in qrencode zbarimg openssl zenity base64; do
    if ! command -v $cmd &>/dev/null; then
        zenity --error --text="$cmd is required but not installed. Exiting."
        exit 1
    fi
done

# === Main Menu Function ===
show_menu() {
    zenity --list --title="🔐 QR Code Tool" \
        --column="Option" --column="Description" \
        "1" "Generate password-protected QR code" \
        "2" "Decrypt password-protected QR code" \
        "q" "Quit" \
        --height=270 --width=400
}

while true; do
    choice=$(show_menu)
    case "$choice" in
        "1")
            # ===== Generate QR code =====
            zenity --info --title="QR Code Generator" \
                --text="This tool lets you create a password-protected QR code from your secret message."

            secret=$(zenity --entry --title="Secret Message" \
                --text="Enter the secret message or phrase to encode:")

            if [[ -z "$secret" ]]; then
                zenity --error --text="No message entered. Going back to menu."
                continue
            fi

            password=$(zenity --password --title="Set Password" --text="Enter a password to protect your message:")
            password_confirm=$(zenity --password --title="Confirm Password" --text="Confirm your password:")

            if [[ "$password" != "$password_confirm" ]]; then
                zenity --error --text="Passwords do not match. Going back to menu."
                continue
            fi

            output_file=$(zenity --file-selection --save --confirm-overwrite \
                --title="Save QR Code as..." --filename="$HOME/secret-qr.png")
            if [[ -z "$output_file" ]]; then
                zenity --error --text="No output file specified. Going back to menu."
                continue
            fi

            tmp_dir=$(mktemp -d)
            trap 'rm -rf "$tmp_dir"' EXIT

            echo "$secret" > "$tmp_dir/secret.txt"

            openssl enc -aes-256-cbc -pbkdf2 -salt -iter 100000 \
                -in "$tmp_dir/secret.txt" \
                -out "$tmp_dir/secret.enc" \
                -pass pass:"$password" 2>/dev/null

            base64 "$tmp_dir/secret.enc" > "$tmp_dir/secret.b64"

            qrencode -o "$output_file" -s 10 < "$tmp_dir/secret.b64"

            zenity --info --title="QR Code Generated!" --text="✅ Your password-protected QR code has been saved as:\n$output_file"

            zenity --text-info --title="Decryption Instructions" --width=500 --height=320 --filename=<(cat <<EOF
To decrypt this QR code later:
1. Open this tool and choose option 2.
2. Select the generated QR code image and enter your password.
EOF
)
            ;;

        "2")
            # ===== Decrypt QR code =====
            zenity --info --title="QR Code Decryptor" \
                --text="This tool lets you decode and decrypt a password-protected QR code."

            qr_file=$(zenity --file-selection --title="Select QR Code PNG" --file-filter="PNG files (png) | *.png")
            if [[ -z "$qr_file" ]]; then
                zenity --error --text="No file selected. Going back to menu."
                continue
            fi

            base64_data=$(zbarimg --raw "$qr_file" 2>/dev/null | tr -d '\n')
            if [[ -z "$base64_data" ]]; then
                zenity --error --text="Could not decode QR code or QR code is empty. Going back to menu."
                continue
            fi

            tmp_dir=$(mktemp -d)
            trap 'rm -rf "$tmp_dir"' EXIT
            echo "$base64_data" > "$tmp_dir/secret.b64"
            base64 -d "$tmp_dir/secret.b64" > "$tmp_dir/secret.enc"

            password=$(zenity --password --title="Enter Decryption Password")
            if [[ -z "$password" ]]; then
                zenity --error --text="No password entered. Going back to menu."
                continue
            fi

            if openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 \
                -in "$tmp_dir/secret.enc" -out "$tmp_dir/secret.txt" \
                -pass pass:"$password" 2>/dev/null; then

                secret=$(cat "$tmp_dir/secret.txt" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
                zenity --info --title="Decrypted Secret" --text="✅ Your secret message is:\n\n$secret"
            else
                zenity --error --text="❌ Decryption failed. Wrong password or corrupted data. Going back to menu."
            fi
            ;;

        "q"|"Q"|"")
            # ===== Quit =====
            zenity --info --title="Goodbye" --text="Exiting QR Code Tool. Stay secure!"
            exit 0
            ;;
        *)
            zenity --error --text="Invalid selection."
            ;;
    esac
done
