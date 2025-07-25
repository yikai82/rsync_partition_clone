#!/bin/bash

## Kubuntu System Clone & Repair v6.6b Release Version
## Created by YKS
## ✅ Feature Summary:
# (1) 🛡️ Preserves bootloader configs (`/etc/fstab`, `/boot/grub/grub.cfg`) with backup and verification
# (2) 🚫 True clone (Recovery) OR Back Clone (clone to a seperate disk), which has advanced exclusion filters (`Trash`, `.cache/`, `timeshift/`, GRUB/EFI files) using `rsync --delete`
# (3) 🎛️ Four clone modes: full system / root-only / home-only / GRUB update only
# (4) 💻 Interactive device selection with `lsblk` + colorized prompts for confirmation
# (5) 🔄 Dry-run + per-mode checksum: checksum enabled for root, skipped for home
# (6) 💾 EFI boot support with default `/dev/sdc2` and runtime override
# (7) 📊 Logs detailed per-partition stats in MB + itemized changes
# (8) 🕒 Timezone-aware logs via user prompt to ensure accurate timestamps
# (9) 🗂️  Organized per-run logs in `logs/run_YYYYMMDD_HHMMSS/` folder
# (10) 🎨 Color-coded terminal output for info, warnings, success messages



set -euo pipefail   # -e: exit on error
                    # -u: treate unset variables as errors
                    # -o pipefail:catch failture in pipelines
# === COLORS ===
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'       # Standard blue
BOLD_BLUE='\033[1;34m'  # Bright/bold blue
CYAN='\033[1;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color


### ==== LOG SETUP ==== ###
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_DIR="./logs/Kubuntu_T2_bkup_$TIMESTAMP"
mkdir -p "$LOG_DIR"
MAIN_LOG="$LOG_DIR/kubuntu_clone_main_${TIMESTAMP}.log"
ROOT_LOG="$LOG_DIR/kubuntu_clone_root_${TIMESTAMP}.log"
HOME_LOG="$LOG_DIR/kubuntu_clone_home_${TIMESTAMP}.log"
touch "$MAIN_LOG" "$ROOT_LOG" "$HOME_LOG"

# === LOGGING HELPERS === ###
log_info()    { echo -e "${CYAN}[INFO]${NC} $*" | tee -a "$MAIN_LOG"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" | tee -a "$MAIN_LOG" >&2; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*" | tee -a "$MAIN_LOG"; }


# === HEADER ===
echo -e "${CYAN}##############################################################################${NC}"
echo -e "${CYAN}#####     🐧  Kubuntu-T2 System Cloner with Bootloader Preserve v6.6b     #####${NC}"
echo -e "${CYAN}##############################################################################${NC}"

echo -e "\n${BOLD_BLUE}🛠️ Kubuntu-T2 Cloner v6.6 – Feature Summary\033[0m"
echo -e "\033[1;34m==================================================================================================${NC}"
echo -e "| ${BOLD}Feature${NC}                      | Description                                                     |"
echo -e "|------------------------------|-----------------------------------------------------------------|"
echo -e "| 🛡️ ${GREEN}Bootloader safety        | Preserves /etc/fstab and /boot/grub/grub.cfg on target system${NC}   |"
echo -e "| 💡 Smart exclusions$        | ${BOLD}Excludes bootloader files, trash, .cache/, timeshift/ folders   |"
echo -e "| 🎛️ ${YELLOW}Flexible clone modes     | Clone all / only root / only home / GRUB-only update${NC}            |"
echo -e "| 💻 ${GREEN}Device validation${NC}        | Uses lsblk to show devices, prompts for confirmation            |"
echo -e "| 🔄 ${YELLOW}Checksum + dry-run       | Supports --checksum for accuracy and --dry-run for simulation${NC}   |"
echo -e "| 💾 ${GREEN}EFI boot support         | Handles /boot/efi and installs GRUB (default: /dev/sdc2)${NC}        |"
echo -e "| 📊 Clone stats in MB        | Displays size of transferred data in megabytes                  |"
echo -e "| 🗂️ Organized logging        | Logs saved in ./logs/run_YYYYMMDD_HHMMSS/ per session           |"
echo -e "| 🧭 Timezone-aware logging   | Prompts for timezone to match system time in logs               |"
echo -e "${BOLD_BLUE}==================================================================================================${NC}\n"
echo -e "🔧${BOLD_BLUE} What's New in kubuntu_cloner_v6.6b.sh${NC}"
echo -e "${BLUE}====================================================================================================================${NC}"
echo -e "| Feature                                          | Description                                                   |"
echo -e "|--------------------------------------------------|---------------------------------------------------------------|"
echo -e "| 🔁 Root clone type selector                      | Choose between recovery clone and bootable                    |"
echo -e "| ✅ timeshift.json preserved                      | Fixes issue causing Timeshift to hang                         |"
echo -e "| 📂 Post-run log copy                             | Prompt for LOG_COPY_DEST for copied logs                      |"
echo -e "| 🧼 Cleaned versioning and header info            | Script now tracks actual version accurately                   |"
echo -e "| 😎 Ownership (chown)                             | Prompt for LOG_USER to fix owner issue for the backup GRUB    |"                           
echo -e "${BLUE}====================================================================================================================${NC}\n"


export LANG=C
export LC_ALL=C


### === DISABLE SUSPEND === ###
log_info "Disabling suspend/hibernate..."
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target || true
echo


### ==== TIMEZONE PROMPT ==== ###
read -rp "$(echo -e "${YELLOW}${BOLD}Enter timezone for log timestamps [America/Toronto]: ${NC}")" USER_TIMEZONE
USER_TIMEZONE=${USER_TIMEZONE:-America/Toronto}
if timedatectl list-timezones | grep -Fxq "$USER_TIMEZONE"; then
    timedatectl set-timezone "$USER_TIMEZONE"
    log_info "Timezone set to $USER_TIMEZONE"
elif [[ "$USER_TIMEZONE" =~ UTC[+-][0-9]+ ]]; then
    timedatectl set-timezone "$USER_TIMEZONE"
    log_info "Timezone set to $USER_TIMEZONE"
else
    log_error "Timezone '$USER_TIMEZONE' not valid, using default America/Toronto"
    timedatectl set-timezone America/Toronto
fi


### ==== 1.OPERATION MODE ==== ###
echo
echo -e "${CYAN}${BOLD}===== OPERATION MODE SELECTION =====${NC}"
echo "1) Clone both root (/) and home (/home)"
echo "2) Clone only the root (/)"
echo "3) Clone only the home (/home)"
echo "4) Only update GRUB on the target system"
read -rp "$(echo -e "${YELLOW}${BOLD}Enter your choice [1-4]: ${NC}")" OPERATION_MODE

CLONE_ROOT=false
ROOT_IS_TRUE_CLONE=false
CLONE_HOME=false
UPDATE_GRUB_ONLY=false
case $OPERATION_MODE in
    1) CLONE_ROOT=true; CLONE_HOME=true
    echo -e "${CYAN}${BOLD}Root Clone Type:${NC}"
            echo "  a) Standard (bootable, excludes cache, bootloader files, etc.)"
            echo "  b) True clone (raw rsync, no exclusion â not bootable with different UUID)"
            read -rp "$(echo -e "${YELLOW}${BOLD}Choose root clone type [a/b]: ${NC}")" ROOT_TYPE
            ROOT_TYPE=${ROOT_TYPE:-a}
            ROOT_IS_TRUE_CLONE=false
            [[ "$ROOT_TYPE" == "b" ]] && ROOT_IS_TRUE_CLONE=true
            ;;
    2) CLONE_ROOT=true
    echo -e "${CYAN}${BOLD}Root Clone Type:${NC}"
        echo "  a) Standard (bootable, excludes cache, bootloader files, etc.)"
        echo "  b) True clone (raw rsync, no exclusion â not bootable with different UUID)"
        read -rp "$(echo -e "${YELLOW}${BOLD}Choose root clone type [a/b]: ${NC}")" ROOT_TYPE
        ROOT_TYPE=${ROOT_TYPE:-a}
        ROOT_IS_TRUE_CLONE=false
        [[ "$ROOT_TYPE" == "b" ]] && ROOT_IS_TRUE_CLONE=true
        ;;
    3) CLONE_HOME=true ;;
    4) UPDATE_GRUB_ONLY=true ;;
    *) log_error "Invalid input, defaulting to full clone"; CLONE_ROOT=true; CLONE_HOME=true ;;
esac


### ==== 2.DEVICE PROMPTS ==== ###
DEFAULT_SOURCE_ROOT="/dev/nvme0n1p3"
DEFAULT_SOURCE_HOME="/dev/nvme0n1p5"
DEFAULT_TARGET_ROOT="/dev/sdc3"
DEFAULT_TARGET_HOME="/dev/sdc5"
DEFAULT_TARGET_EFI="/dev/sdc1"

prompt_for_device() {
    local prompt label def dev
    prompt="$1"; label="$2"; def="$3"

    echo -e "\n${CYAN}[INFO] Available block devices and partitions:${NC}" >&2
    lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT,LABEL | grep -v loop >&2
#    echo -e "${BLUE}$(lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT,LABEL | grep -v loop)${NC}" >&2 # Use this to color the lsblk ouput

    while true; do
        read -rp "$(echo -e "${YELLOW}${BOLD}$prompt [$def]: ${NC}")" dev
        dev=${dev:-$def}
        if [ -b "$dev" ]; then
            echo -e "${CYAN}[INFO] Using $label: $dev${NC}" >&2
            echo "$dev"
            return
        fi
        echo -e "${RED}[ERROR] '$dev' is not a valid block device. Try again.${NC}" >&2
    done
}



[ "$CLONE_ROOT" = true ] && SOURCE_ROOT_DEV=$(prompt_for_device "Source ROOT device" "source root" "$DEFAULT_SOURCE_ROOT") || SOURCE_ROOT_DEV="$DEFAULT_SOURCE_ROOT"
[ "$CLONE_HOME" = true ] && SOURCE_HOME_DEV=$(prompt_for_device "Source HOME device" "source home" "$DEFAULT_SOURCE_HOME") || SOURCE_HOME_DEV="$DEFAULT_SOURCE_HOME"
[ "$CLONE_ROOT" = true ] || [ "$UPDATE_GRUB_ONLY" = true ] && TARGET_ROOT_DEV=$(prompt_for_device "Target ROOT device" "target root" "$DEFAULT_TARGET_ROOT") || TARGET_ROOT_DEV="$DEFAULT_TARGET_ROOT"
[ "$CLONE_HOME" = true ] && TARGET_HOME_DEV=$(prompt_for_device "Target HOME device" "target home" "$DEFAULT_TARGET_HOME") || TARGET_HOME_DEV="$DEFAULT_TARGET_HOME"
TARGET_EFI_DEV=$(prompt_for_device "Target EFI device" "EFI" "$DEFAULT_TARGET_EFI")

MOUNT_SOURCE_ROOT="/mnt/source_root"
MOUNT_SOURCE_HOME="/mnt/source_home"
MOUNT_TARGET_ROOT="/mnt/target_root"
MOUNT_TARGET_HOME="/mnt/target_home"
MOUNT_TARGET_EFI="/mnt/target_efi"
mkdir -p "$MOUNT_SOURCE_ROOT" "$MOUNT_SOURCE_HOME" "$MOUNT_TARGET_ROOT" "$MOUNT_TARGET_HOME" "$MOUNT_TARGET_EFI"


### ==== 3.CONFIRM DEVICES ==== ###
log_info "SRC root: $SOURCE_ROOT_DEV | HOME: $SOURCE_HOME_DEV"
log_info "TGT root: $TARGET_ROOT_DEV | HOME: $TARGET_HOME_DEV | EFI: $TARGET_EFI_DEV"
read -rp "Continue with these devices? [y/N]: " CONFIRM
[[ ! "$CONFIRM" =~ ^[Yy]$ ]] && log_error "Aborted by user." && exit 1


### ==== 4. USER OPTIONS ==== ###
# == DRY RUN PROMPT ==
read -rp "$(echo -e "${YELLOW}${BOLD}Dry run (simulate only)? [Y/n]: ${NC}")" DRY
DRY_RUN=false; [[ ! "${DRY:-Y}" =~ ^[Nn]$ ]] && DRY_RUN=true
# == Checksum Prompt ==
if $CLONE_ROOT; then
    read -rp "$(echo -e "${YELLOW}${BOLD}Enable rsync --checksum for root (accurate but slow)? [Y/n]: ${NC}")" CSK
    RSYNC_CHECKSUM_ROOT=false; [[ "${CS:-Y}" =~ ^[Yy]$ ]] && RSYNC_CHECKSUM_ROOT=true
fi



### ==== MOUNT DEVICES ==== ###
mount_if_needed() { dev=$1; mnt=$2; mountpoint -q "$mnt" || mount "$dev" "$mnt"; }
$CLONE_ROOT && mount_if_needed "$SOURCE_ROOT_DEV" "$MOUNT_SOURCE_ROOT" && mount_if_needed "$TARGET_ROOT_DEV" "$MOUNT_TARGET_ROOT"
$CLONE_HOME && mount_if_needed "$SOURCE_HOME_DEV" "$MOUNT_SOURCE_HOME" && mount_if_needed "$TARGET_HOME_DEV" "$MOUNT_TARGET_HOME"

### ==== BACKUP /etc/fstab and grub.cfg ==== ###
BACKUP_DIR="$LOG_DIR/boot_backup_$TIMESTAMP"
mkdir -p "$BACKUP_DIR"
$CLONE_ROOT && cp "$MOUNT_TARGET_ROOT/etc/fstab" "$BACKUP_DIR/fstab" 2>/dev/null || true
$CLONE_ROOT && cp "$MOUNT_TARGET_ROOT/boot/grub/grub.cfg" "$BACKUP_DIR/grub.cfg" 2>/dev/null || true


### ==== RSYNC CLONE ==== ###
rsync_clone() {
    local SRC=$1 DEST=$2 LABEL=$3 USE_CS=$4 LOGF=$5
    local EX=()
    if [ "$LABEL" = "ROOT" ] ; then

        EX+=( # exclusiions that always applied
        --exclude='.cache/'
        --exclude='*/.local/share/Trash/'
        --exclude='timeshift/'
        --exclude='/home/backintime/*'
    )
    # additional exclusion only for options (a)
        if [ "${ROOT_IS_TRUE_CLONE:-false}" = false ]; then
            EX+=(
                --exclude='/etc/fstab'
                --exclude='/boot/grub/grub.cfg'
                --exclude='/boot/grub/device.map'
            )
        fi
    fi

    local OPT="-aAXHv --delete --stats --itemize-changes"
    [ "$USE_CS" = "true" ] && OPT="$OPT --checksum"
    [ "$DRY_RUN" = "true" ] && OPT="$OPT --dry-run"
    log_info "Starting $LABEL rsync..."
    rsync $OPT "${EX[@]}" "$SRC/" "$DEST/" | tee -a "$LOGF"
    local BYTES=$(du -sb "$DEST" | awk '{print $1}')
    local MB=$(awk "BEGIN{printf \"%.2f\", $BYTES/1048576}")
    log_info "$LABEL size: ${MB}MB" | tee -a "$LOGF"
}

echo "Started: $(date)" >> "$ROOT_LOG" "$HOME_LOG"
$CLONE_ROOT && rsync_clone "$MOUNT_SOURCE_ROOT" "$MOUNT_TARGET_ROOT" "ROOT" "$RSYNC_CHECKSUM_ROOT" "$ROOT_LOG"
$CLONE_HOME && rsync_clone "$MOUNT_SOURCE_HOME" "$MOUNT_TARGET_HOME" "HOME" "false" "$HOME_LOG"

### ==== RESTORE IF CHANGED ==== ###
restore_if_changed() {
    local NAME=$1 TO=$2 BAK=$3
    [ -f "$BAK" ] && [ -f "$TO" ] && ! diff -q "$BAK" "$TO" >/dev/null && {
        log_error "$NAME changed! Restore original? [Y/n]: "
        read ANS; [[ ! "$ANS" =~ ^[Nn]$ ]] && cp "$BAK" "$TO" && log_info "$NAME restored."
    }
}
$CLONE_ROOT && restore_if_changed "fstab" "$MOUNT_TARGET_ROOT/etc/fstab" "$BACKUP_DIR/fstab"
$CLONE_ROOT && restore_if_changed "grub.cfg" "$MOUNT_TARGET_ROOT/boot/grub/grub.cfg" "$BACKUP_DIR/grub.cfg"

### ==== GRUB UPDATE (chroot) ==== ###
mount_chroot_deps() {
    for d in dev proc sys run; do mount --bind /$d "$MOUNT_TARGET_ROOT/$d"; done
    mkdir -p "$MOUNT_TARGET_ROOT/boot/efi"
    mount "$TARGET_EFI_DEV" "$MOUNT_TARGET_EFI"
    mount --bind "$MOUNT_TARGET_EFI" "$MOUNT_TARGET_ROOT/boot/efi"
}
unmount_chroot_deps() {
    umount "$MOUNT_TARGET_ROOT/boot/efi" "$MOUNT_TARGET_EFI" || true
    for d in run sys proc dev; do umount "$MOUNT_TARGET_ROOT/$d" || true; done
}

if [ "$DRY_RUN" = false ]; then
    read -rp "$(echo -e "${YELLOW}${BOLD}Run GRUB/EFI update on target? [Y/n]: ${NC}")" GRUBRUN
    [[ ! "$GRUBRUN" =~ ^[Nn]$ ]] && {
        mount_chroot_deps
        chroot "$MOUNT_TARGET_ROOT" update-grub | tee -a "$MAIN_LOG"
        chroot "$MOUNT_TARGET_ROOT" grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Kubuntu --recheck | tee -a "$MAIN_LOG"
        unmount_chroot_deps
        log_success "GRUB update complete."
    }
else
    log_info "Dry-run enabled - skipping GRUB update."
fi


### === Output for log ==== ###
# === Set log file ownership ===
# When running from a live USB, files written to persistent disks (like log files)
# may be owned by 'root' unless we explicitly set ownership. This can cause permission
# issues later when accessing the logs from your actual user account on the installed system.
# We prompt the user to specify their regular username, defaulting to the currently logged-in one.

read -rp "$(echo -e "${YELLOW}${BOLD}Enter your username for chown [$(logname)]: ${NC}")" LOG_USER
LOG_USER=${LOG_USER:-$(logname)}  # Use provided input or fallback to current user

# Check that the username is valid before trying to chown
if id "$LOG_USER" &>/dev/null; then
    chown -R "$LOG_USER:$LOG_USER" "$LOG_DIR"
    chown -R "$LOG_USER:$LOG_USER" "$BACKUP_DIR"
    log_info "Changed ownership of logs to $LOG_USER"
else
    log_error "Username '$LOG_USER' not found. Skipping chown."
fi


ABS_LOG_DIR=$(readlink -f "$LOG_DIR")
log_success "â Operation complete."
echo "Logs:"
echo "  Root: $ROOT_LOG"
echo "  Home: $HOME_LOG"
echo "  Main: $MAIN_LOG"

# Copy the logs to the Source Disk Post Run
log_info "🧭 Reached final post-run log handling section."
echo "Post Run: Copy the logs to the Source Disk"
read -rp "$(echo -e "${YELLOW}${BOLD}Enter path to copy logs after clone (or leave blank to skip): ${NC}")" LOG_COPY_DEST
if [[ -n "$LOG_COPY_DEST" ]]; then
    mkdir -p "$LOG_COPY_DEST"
    cp -r "$LOG_DIR" "$LOG_COPY_DEST"
    log_info "Copied logs to: $LOG_COPY_DEST"
else
    log_info "No log copy destination provided — skipping log copy."
fi



log_info "📝 Backup and clone logs have been saved to:"
log_info "  - Main log:    $ABS_LOG_DIR/$(basename "$MAIN_LOG")"
$CLONE_ROOT && log_info "  - Root clone:  $ABS_LOG_DIR/$(basename "$ROOT_LOG")"
$CLONE_HOME && log_info "  - Home clone:  $ABS_LOG_DIR/$(basename "$HOME_LOG")"
log_info "Use these logs to verify all changes and debug if needed."
