# 🐧 Kubuntu-T2 System Cloner — v6.6b (Live USB Friendly)

This Bash script provides an **interactive, safe, and highly customizable way to clone a Kubuntu-based system**, including root (`/`), home (`/home`), and GRUB bootloader configurations. Designed specifically to be run from a **Live USB environment**, it handles UUID mismatch risks, bootloader safety, and advanced `rsync` exclusions to enable reliable system backup and recovery.

---

## 🚀 Features (v6.6b)

| Feature                               | Description                                                                 |
|---------------------------------------|-----------------------------------------------------------------------------|
| 🛡️ Bootloader-safe                    | Backs up and verifies `/etc/fstab`, `/boot/grub/grub.cfg` before cloning    |
| 🔁 True clone vs. bootable clone      | Choose between a full disk recovery image or a bootable working clone       |
| 🎛️ Clone modes                        | Clone root only, home only, both, or to update GRUB                       |
| 🚫 Smart exclusions                   | Skips `.cache/`, `Trash`, and `timeshift/` in all root clones               |
| 💾 EFI boot support                   | Mounts and installs GRUB to EFI (default: `/dev/sdc1`)                      |
| 📊 Transfer stats & logs              | Shows rsync stats, itemized changes, and logs saved by timestamp            | 
| 🧭 Timezone-aware logging             | Prompt for user timezone to ensure logs are correct                         |
| 🧰 Post-run log copy (optional)       | Lets user specify persistent path to save logs from Live USB                |
| 🔐 Safe for Live USB                  | Doesn’t rely on persistent storage during execution                         |

---

## 📦 Requirements

- Run from a **Live Ubuntu/Kubuntu USB environment**
- `rsync`, `grub-install`, `update-grub`, and standard GNU coreutils
- Administrator privileges (`sudo` or root)

---

## 🧠 How It Works

This script:
1. Prompts you to choose the operation type (root/home clone, GRUB update).
2. Asks for source and target devices (`/dev/...`) interactively via `lsblk`.
3. Creates a timestamped log directory (`./logs/Kubuntu_T2_bkup_YYYYMMDD_HHMMSS`)
4. Runs `rsync` with smart exclusions, optional `--checksum`, and itemized stats.
5. Prompts whether to run a chrooted GRUB install on the target disk.
6. Optionally copies logs to a persistent location (e.g. your source `/home`).
7. Resets log file ownership to your normal username for later access.

---

## 🔧 How to use it 

1. Download the rsync_clone.sh in the file list
2. Make executable: bash ~$ chmod +x kubuntu_clone_v6.6b.sh
3. Run from Live USB: ~$ sudo ./rsync_clone_v6.6b.sh
4. Follow prompts:
    - Select clone mode (root/home/GRUB recovery)
    - Pick devices (source/root/home/EFI)
    - Choose dry-run or actual clone
    - Confirm exclusions and clone type
    - Choose whether to update GRUB
    - Optionally save logs to a custom folder
    - Enter user name for chown (or it will default to use root)

---

## 💡 Tips

- ✅ Best practice is to run this from a Live USB to avoid conflicts or file locks.
- 📁 Logs are saved under ./logs/Kubuntu_T2_bkup_<timestamp>/ by default.
- 🧪 Use the dry-run mode to simulate a clone safely before executing for real.
- 🧯 Keep your EFI and /boot/grub structure clean if doing full recovery.

Feel free to open issues or send pull requests to improve usability, hardware support, or logging!
