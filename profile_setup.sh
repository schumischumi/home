#!/bin/bash
log_message() {
    local message="$2"  # The message to log
    local status="$1"   # The log status: error, warning, info, debug

    # Get current date and time
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    # Determine log level and format
    case "$status" in
        error)
            log_type="[ERROR]"
            ;;
        warning)
            log_type="[WARNING]"
            ;;
        info)
            log_type="[INFO]"
            ;;
        debug)
            log_type="[DEBUG]"
            if [[ $show_debug -ne 1 ]]; then
                return 0
            fi
            ;;
        *)
            log_type="[INFO]"
            ;;
    esac
    log_entry="$timestamp $log_type: $message"
    echo "$log_entry"
    echo "$log_entry" >> "$logfile"
}
chk_exit() {
    local exit_code=$1
    # shift
    # local ok_codes=("$@")
    # local exit_good=0
    # if [[ ${#ok_codes[@]} -eq 0 ]]; then
    #     ok_codes=(0)
    # fi
    # for n in "${ok_codes[@]}"; do
    #     if [[ "$n" -eq "exit_code" ]]; then
    #         exit_good=1
    #     fi
    # done
    if [[ $exit_code -eq 0 ]]; then
        log_message "error" "$task_name had exit code: $exit_code"
        # shellcheck disable=SC2086
        exit $exit_code
    fi
}

# init
show_debug=0
envs=("HOME" "USER" "HOSTNAMER")
unset_envs=()
SCRIPT_DIR=$(dirname "$(realpath "$0")")
src_dir="$SCRIPT_DIR/src"
echo "$src_dir"
log_dir="$HOME/.profile_setup"
logfile=$log_dir/setup_$(date +"%Y-%m-%d_%H-%M-%S").log
# Create trap to catch errors
trap 'chk_exit' ERR
mkdir -p "$log_dir"

# for env in "${envs[@]}"; do
#     if [[ -z "${!env}" ]]; then
#         unset_envs+=("$env")
#     fi
# done
# if [[ ${#unset_envs[@]} -ne 0 ]]; then
#     log_message "error" "Not all ENVs are set:"
#     echo "${envs[@]}"
#     exit 1
# fi


task_name="Copy Profile files"
log_message "info" "Start: $task_name"  
cp -r  "$SCRIPT_DIR/profile_content" "$HOME"
log_message "info" "End: $task_name"


task_name="Install DNF repositories"
log_message "info" "Start: $task_name"
if [[ ! -f "$log_dir/$(echo "$task_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '_').done" ]]; then
    sudo dnf install -y "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm"
    sudo dnf install -y "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
    sudo dnf install -y 'dnf-command(config-manager)'
    sudo dnf config-manager -y --add-repo https://repository.mullvad.net/rpm/stable/mullvad.repo
    sudo dnf config-manager -y --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
    sudo dnf config-manager --set-enabled fedora-cisco-openh264
    #flatpak remote-modify --enable flathub
    touch "$log_dir/$(echo "$task_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '_').done"
else
    log_message "info" "Skipped: $task_name"
fi
log_message "info" "End: $task_name"


task_name="Update and Reboot"
log_message "info" "Start: $task_name"
if [[ ! -f "$log_dir/$(echo "$task_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '_').done" ]]; then
    sudo dnf -y update
    sudo dnf -y upgrade --refresh
    # install app-stream metadata
    # sudo dnf group -y update core
    # sudo fwupdmgr refresh --force
    # sudo fwupdmgr get-updates
    # sudo fwupdmgr update
    touch "$log_dir/$(echo "$task_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '_').done"
    log_message "info" "End: $task_name"
    log_message "info" "You should reboot now. Exit 0"
    exit 0
else
    log_message "info" "Skipped: $task_name"
fi


task_name="Install DNF packages"
log_message "info" "Start: $task_name"
if [[ -f "$src_dir/dnf-packages.txt" ]] && [[ ! -f "$log_dir/$(echo "$task_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '_').done" ]]; then
    sudo dnf install -y $(awk '{print $1}' "$src_dir/dnf-packages.txt")
    sudo dnf swap 'ffmpeg-free' 'ffmpeg' --allowerasing
    touch "$log_dir/$(echo "$task_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '_').done"
else
    log_message "info" "Skipped: $task_name"
fi
log_message "info" "End: $task_name"


task_name="Install antigen"
log_message "info" "Start: $task_name"
if [ ! -f "$HOME/antigen.zsh" ]; then
    curl -L git.io/antigen > "$HOME/antigen.zsh"
else
    log_message "info" "Skipped: $task_name"
fi
log_message "info" "End: $task_name"


task_name="Install oh-my-zsh"
log_message "info" "Start: $task_name"
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
    log_message "info" "Skipped: $task_name"
fi
log_message "info" "End: $task_name"


task_name="Install Flatpak packages"
log_message "info" "Start: $task_name"
if [[ -f "$src_dir/flatpak-packages.txt" ]] && [[ ! -f "$log_dir/$(echo "$task_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '_').done" ]]; then
    while IFS= read -r app; do
        flatpak install -y "$app"
    done < "$src_dir/flatpak-packages.txt"
    touch "$log_dir/$(echo "$task_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '_').done"
else
    log_message "info" "Skipped: $task_name"
fi
log_message "info" "End: $task_name"


task_name="Create Docker group and add user"
log_message "info" "Start: $task_name"
sudo groupadd docker && sudo gpasswd -a "${USER}" docker
log_message "info" "End: $task_name"


task_name="Create SSH keys"
log_message "info" "Start: $task_name"
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -C "$USER@$HOSTNAME" -N ""
log_message "info" "End: $task_name"

task_name="Copy Fonts"
log_message "info" "Start: $task_name"
if [[ -d "$src_dir/fonts" ]]; then
    mkdir -p ~/.fonts
    cp "$src_dir/fonts/*.ttf" ~/.fonts/
    sudo fc-cache -f -v
else
    log_message "info" "Skipped: $task_name"
fi
log_message "info" "End: $task_name"


task_name="Manual tasks"
log_message "info" "Start: $task_name"
log_message "info" "Firefox Addon: Close Tabs to the Right; https://addons.mozilla.org/de/firefox/addon/close-tabs-right/"
log_message "info" "Firefox Addon: floccus bookmarks sync; https://addons.mozilla.org/en-US/firefox/addon/floccus/"
log_message "info" "Firefox Addon: ublock-origin; https://addons.mozilla.org/en-US/firefox/addon/ublock-origin/"
log_message "info" "Firefox Addon: KeePassXC-Browser; https://addons.mozilla.org/en-US/firefox/addon/keepassxc-browser/"
log_message "info" "Docker: Enable service if needed; sudo systemctl start docker"
log_message "info" "End: $task_name"
