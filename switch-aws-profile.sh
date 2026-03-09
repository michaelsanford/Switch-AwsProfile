#!/usr/bin/env bash

# Interactive AWS SSO profile switcher with arrow key navigation
# Reads AWS SSO profiles from ~/.aws/config and presents an interactive menu
# Sets AWS_PROFILE environment variable and triggers aws sso login

config_path="$HOME/.aws/config"
profiles=()

while IFS= read -r line; do
    line="${line%$'\r'}"  # Strip carriage return
    if [[ $line =~ ^\[profile[[:space:]]+(.+)\]$ ]]; then
        profiles+=("${BASH_REMATCH[1]}")
    fi
done < "$config_path"

if [ ${#profiles[@]} -eq 0 ]; then
    echo "No profiles found in $config_path"
    exit 1
fi

selected=0
menu_size=$((${#profiles[@]} + 3))  # profiles + header lines

draw_menu() {
    echo -e "\nAWS SSO Profiles (arrow keys, Enter to select, Esc to cancel):\n"
    for i in "${!profiles[@]}"; do
        if [ $i -eq $selected ]; then
            echo -e "  \033[32m> ${profiles[$i]}\033[0m"
        else
            echo "    ${profiles[$i]}"
        fi
    done
}

# Draw initial menu
draw_menu

while true; do
    # Read single character
    IFS= read -rsn1 key
    
    # Handle escape sequences (arrow keys)
    if [[ $key == $'\x1b' ]]; then
        read -rsn2 key
        case $key in
            '[A') # Up arrow
                ((selected > 0)) && ((selected--))
                ;;
            '[B') # Down arrow
                ((selected < ${#profiles[@]} - 1)) && ((selected++))
                ;;
        esac
        # Move cursor up and redraw
        tput cuu $menu_size
        tput ed
        draw_menu
    elif [[ $key == "" ]]; then
        # Enter key
        break
    fi
done

selected_profile="${profiles[$selected]}"
export AWS_PROFILE="$selected_profile"

clear
echo -e "\nSet AWS_PROFILE to: $selected_profile"

aws sso login --profile "$selected_profile"
