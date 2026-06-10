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

if [[ ${#profiles[@]} -eq 0 ]]; then
    echo "No profiles found in $config_path"
    exit 1
fi

# --- Sort ---
# Use GNU sort -V (natural/version sort) when available; fall back to -f (case-insensitive).
if sort -V /dev/null 2>/dev/null; then
    _sort_asc()  { sort -V;  }
    _sort_desc() { sort -Vr; }
else
    _sort_asc()  { sort -f;  }
    _sort_desc() { sort -fr; }
fi

sort_mode=0
sort_labels=("" " [A-Z]" " [Z-A]")
display_profiles=("${profiles[@]}")

update_display_profiles() {
    display_profiles=()
    local line
    if [[ $sort_mode -eq 1 ]]; then
        while IFS= read -r line; do display_profiles+=("$line"); done \
            < <(printf '%s\n' "${profiles[@]}" | _sort_asc)
    elif [[ $sort_mode -eq 2 ]]; then
        while IFS= read -r line; do display_profiles+=("$line"); done \
            < <(printf '%s\n' "${profiles[@]}" | _sort_desc)
    else
        display_profiles=("${profiles[@]}")
    fi
}

# --- Layout ---
term_width=$(tput cols)
term_height=$(tput lines)

longest=0
for p in "${profiles[@]}"; do
    (( ${#p} > longest )) && longest=${#p}
done

inner_width=$(( longest + 4 ))
(( inner_width < 40 ))              && inner_width=40
(( inner_width > term_width - 4 )) && inner_width=$(( term_width - 4 ))

viewport_size=$(( term_height - 6 ))
(( viewport_size > ${#profiles[@]} )) && viewport_size=${#profiles[@]}
if (( viewport_size < 1 )); then
    echo "Terminal too small to display menu."
    printf '  %s\n' "${profiles[@]}"
    exit 0
fi

total_lines=$(( viewport_size + 5 ))  # top border + title + separator + items + bottom border + hints

h_bar=""; for ((i=0; i<inner_width; i++)); do h_bar+="─"; done
top_border="┌${h_bar}┐"
separator="├${h_bar}┤"
bottom_border="└${h_bar}┘"

# ANSI codes
C='\033[96m'      # bright cyan  (key names in hints)
R='\033[0m'       # reset
HL='\033[37;46m'  # white on dark-cyan (selected row)

draw_menu() {
    tput rc  # jump back to saved draw position

    local sort_label="${sort_labels[$sort_mode]}"
    local scroll_info=""
    (( ${#display_profiles[@]} > viewport_size )) && \
        scroll_info=" ($(( selected + 1 ))/${#display_profiles[@]})"
    local title=" AWS SSO Profiles${sort_label}${scroll_info}"

    printf '%s\033[K\n' "$top_border"
    printf "│ %-$(( inner_width - 1 ))s│\033[K\n" "$title"
    printf '%s\033[K\n' "$separator"

    local i name
    for ((i=scroll_offset; i<scroll_offset+viewport_size; i++)); do
        name="${display_profiles[$i]}"
        if (( ${#name} > inner_width - 4 )); then
            name="${name:0:$(( inner_width - 5 ))}…"
        fi
        if (( i == selected )); then
            printf "│${HL}  %-$(( inner_width - 2 ))s${R}│\033[K\n" "$name"
        else
            printf "│  %-$(( inner_width - 2 ))s│\033[K\n" "$name"
        fi
    done

    printf '%s\033[K\n' "$bottom_border"
    printf "  ${C}↑↓${R} Navigate   ${C}[Enter]${R} Select   ${C}[S]${R} Sort   ${C}[Esc]${R} Cancel\033[K\n"
}

cleanup() {
    tput rc
    for ((i=0; i<total_lines; i++)); do
        printf '\033[2K\n'
    done
    tput rc
    tput cnorm
}

trap 'tput cnorm' EXIT

# Pre-allocate rows so any terminal scroll happens now, then save the position.
for ((i=0; i<total_lines; i++)); do printf '\n'; done
tput cuu "$total_lines"
tput sc  # draw_top

selected=0
scroll_offset=0

tput civis
draw_menu

while true; do
    IFS= read -rsn1 key

    action=""
    if [[ $key == $'\x1b' ]]; then
        IFS= read -rsn1 -t 0.1 k2
        if [[ $k2 == '[' ]]; then
            IFS= read -rsn1 -t 0.1 k3
            case "$k3" in
                A) action=up ;;
                B) action=down ;;
                5) IFS= read -rsn1 -t 0.1; action=pageup ;;    # consumes trailing ~
                6) IFS= read -rsn1 -t 0.1; action=pagedown ;;  # consumes trailing ~
            esac
        else
            action=esc
        fi
    elif [[ $key == '' ]]; then
        action=enter
    elif [[ $key == 's' || $key == 'S' ]]; then
        action="sort"
    fi

    page_jump=$(( viewport_size / 2 ))
    (( page_jump < 1 )) && page_jump=1
    count=${#display_profiles[@]}

    case "$action" in
        up)
            (( selected > 0 )) && (( selected-- ))
            ;;
        down)
            (( selected < count - 1 )) && (( selected++ ))
            ;;
        pageup)
            (( selected -= page_jump ))
            (( selected < 0 )) && selected=0
            ;;
        pagedown)
            (( selected += page_jump ))
            (( selected >= count )) && selected=$(( count - 1 ))
            ;;
        sort)
            cur="${display_profiles[$selected]}"
            sort_mode=$(( (sort_mode + 1) % 3 ))
            update_display_profiles
            selected=0
            for ((i=0; i<${#display_profiles[@]}; i++)); do
                [[ "${display_profiles[$i]}" == "$cur" ]] && { selected=$i; break; }
            done
            ;;
        enter) break ;;
        esc)   cleanup; exit 0 ;;
    esac

    (( selected < scroll_offset )) && scroll_offset=$selected
    (( selected >= scroll_offset + viewport_size )) && \
        scroll_offset=$(( selected - viewport_size + 1 ))

    draw_menu
done

cleanup

selected_profile="${display_profiles[$selected]}"
export AWS_PROFILE="$selected_profile"

echo "Set AWS_PROFILE to: $selected_profile"
aws sso login --profile "$selected_profile"
