#!/bin/bash

set -e

# === Dependency Check ===
for cmd in qrencode zbarimg openssl base64; do
    if ! command -v $cmd &>/dev/null; then
        echo "ERROR: $cmd is required but not installed. Exiting."
        exit 1
    fi
done

main_menu() {
    echo "=============================="
    echo "🔐 QR Code Tool"
    echo "=============================="
    echo "1. Generate password-protected QR code"
    echo "2. Decrypt password-protected QR code"
    echo "q. Quit"
    echo
    read -p "Choose an option [1/2/q]: " choice
}

while true; do
    main_menu
    case "$choice" in
        1)
            echo "== QR Code Generator =="
            read -p "Enter the secret message or phrase: " secret
            if [[ -z "$secret" ]]; then
                echo "No message entered. Going back to menu."
                continue
            fi
            read -s -p "Enter a password to protect your message: " password
            echo
            read -s -p "Confirm your password: " password_confirm
            echo
            if [[ "$password" != "$password_confirm" ]]; then
                echo "Passwords do not match. Going back to menu."
                continue
            fi
            read -e -p "Save QR Code as (e.g. secret-qr.png): " output_file
            if [[ -z "$output_file" ]]; then
                echo "No output file specified. Going back to menu."
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
            echo "✅ Your password-protected QR code has been saved as: $output_file"
            echo "== Decryption Instructions =="
            echo "To decrypt this QR code later:"
            echo "1. Run this tool and choose option 2."
            echo "2. Select the generated QR code image and enter your password."
            echo
            ;;
        2)
            echo "== QR Code Decryptor =="
            read -e -p "Enter the path to the QR Code PNG file: " qr_file
            if [[ -z "$qr_file" ]]; then
                echo "No file specified. Going back to menu."
                continue
            fi
            base64_data=$(zbarimg --raw "$qr_file" 2>/dev/null | tr -d '\n')
            if [[ -z "$base64_data" ]]; then
                echo "Could not decode QR code or QR code is empty. Going back to menu."
                continue
            fi
            tmp_dir=$(mktemp -d)
            trap 'rm -rf "$tmp_dir"' EXIT
            echo "$base64_data" > "$tmp_dir/secret.b64"
            base64 -d "$tmp_dir/secret.b64" > "$tmp_dir/secret.enc"
            read -s -p "Enter decryption password: " password
            echo
            if openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 \
                -in "$tmp_dir/secret.enc" -out "$tmp_dir/secret.txt" \
                -pass pass:"$password" 2>/dev/null; then
                echo "✅ Your secret message is:"
                cat "$tmp_dir/secret.txt"
                echo
            else
                echo "❌ Decryption failed. Wrong password or corrupted data. Going back to menu."
            fi
            ;;
        q|Q)
            echo "Goodbye! Exiting QR Code Tool."
            exit 0
            ;;
        *)
            echo "Invalid selection."
            ;;
    esac
done
