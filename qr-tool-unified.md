>[!NOTE]
> **professional, unified script** that **auto-detects if a graphical environment (GUI) is available** and uses Zenity dialogs if it is; otherwise, it gracefully falls back to CLI/terminal prompts.
>>This way, you can use it seamlessly on your desktop **or** in Codespaces (or SSH/terminal).

---

## 🟢 **Auto-Detect GUI or CLI Bash QR Tool**

```bash
#!/bin/bash

set -e

# === Dependency Check ===
for cmd in qrencode zbarimg openssl base64; do
    if ! command -v $cmd &>/dev/null; then
        echo "ERROR: $cmd is required but not installed. Exiting."
        exit 1
    fi
done

# === GUI Detection ===
gui_available=0
if command -v zenity &>/dev/null && [[ -n "$DISPLAY" || -n "$WAYLAND_DISPLAY" ]]; then
    gui_available=1
fi

# === Utility Functions ===

escape_zenity() {
    # Escapes &, <, > for Zenity's Pango markup
    echo "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'
}

# === Main Menu Functions ===

main_menu_cli() {
    echo "=============================="
    echo "🔐 QR Code Tool"
    echo "=============================="
    echo "1. Generate password-protected QR code"
    echo "2. Decrypt password-protected QR code"
    echo "q. Quit"
    echo
    read -p "Choose an option [1/2/q]: " choice
}

main_menu_gui() {
    zenity --list --title="🔐 QR Code Tool" \
        --column="Option" --column="Description" \
        "1" "Generate password-protected QR code" \
        "2" "Decrypt password-protected QR code" \
        "q" "Quit" \
        --height=270 --width=400
}

# === App Loop ===
while true; do
    if [[ $gui_available -eq 1 ]]; then
        choice=$(main_menu_gui)
    else
        main_menu_cli
    fi

    case "$choice" in
        1)
            # === GENERATE QR ===
            if [[ $gui_available -eq 1 ]]; then
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
            else
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

            if [[ $gui_available -eq 1 ]]; then
                zenity --info --title="QR Code Generated!" --text="✅ Your password-protected QR code has been saved as:\n$output_file"
                zenity --text-info --title="Decryption Instructions" --width=500 --height=320 --filename=<(cat <<EOF
To decrypt this QR code later:
1. Open this tool and choose option 2.
2. Select the generated QR code image and enter your password.
EOF
)
            else
                echo "✅ Your password-protected QR code has been saved as: $output_file"
                echo "== Decryption Instructions =="
                echo "To decrypt this QR code later:"
                echo "1. Run this tool and choose option 2."
                echo "2. Select the generated QR code image and enter your password."
                echo
            fi
            ;;
        2)
            # === DECRYPT QR ===
            if [[ $gui_available -eq 1 ]]; then
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

                    secret=$(escape_zenity "$(cat "$tmp_dir/secret.txt")")
                    zenity --info --title="Decrypted Secret" --text="✅ Your secret message is:\n\n$secret"
                else
                    zenity --error --text="❌ Decryption failed. Wrong password or corrupted data. Going back to menu."
                fi
            else
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
            fi
            ;;
        q|Q|"")
            if [[ $gui_available -eq 1 ]]; then
                zenity --info --title="Goodbye" --text="Exiting QR Code Tool. Stay secure!"
            else
                echo "Goodbye! Exiting QR Code Tool."
            fi
            exit 0
            ;;
        *)
            if [[ $gui_available -eq 1 ]]; then
                zenity --error --text="Invalid selection."
            else
                echo "Invalid selection."
            fi
            ;;
    esac
done
```

---

## **How it Works**

* **Runs with GUI (Zenity) if available:** On desktop Linux with graphical interface.
* **Falls back to terminal prompts:** In Codespaces, SSH, headless servers, etc.

---

## **How to Use**

1. Save as `qr-tool-unified.sh`
2. Make executable:
   `chmod +x qr-tool-unified.sh`
3. Run:
   `./qr-tool-unified.sh`
4. Enjoy seamless use in both environments!

---

