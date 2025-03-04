# ZFS Disk Replacement Script

This repository contains a handy Bash script—[`zpool_replace.sh`](./zpool_replace.sh)—to help you manage disk replacements in your ZFS pools. It interactively guides you through the process of replacing a missing or degraded disk, checking for resilver operations, and listing candidate new disks that aren’t already part of any ZFS pool.

## Features

- **Multi-Pool Health Check:**  
  Detects which pools are degraded (i.e., not in `ONLINE` state) and prompts you to select one if multiple pools are affected.

- **Missing Disk Detection:**  
  Automatically identifies the disk marked as `REMOVED`, `MISSING`, `UNAVAIL`, or `DEGRADED` in the selected pool.

- **Resilver Protection:**  
  If the pool is already resilvering, the script will notify you and exit to prevent interfering with the ongoing rebuild.

- **All-Pool Disk Exclusion:**  
  Gathers a list of disks currently in **any** ZFS pool, ensuring only truly “new” disks are displayed as replacement candidates.

- **Detailed Disk Info:**  
  Uses `smartctl` and `lsblk` to display each candidate disk’s model, serial number, and size before you pick one.

- **Interactive Replacement:**  
  Asks you to confirm the replacement, then runs the appropriate `zpool replace` command.

- **Friendly Emojis & Prompts:**  
  Offers a more readable and interactive user experience, with clear instructions and prompts at each step.

## Requirements

- **Operating System:**  
  Linux (e.g., Proxmox VE, Ubuntu, Debian)

- **Dependencies:**  
  - ZFS (with the `zpool` command installed)  
  - `smartctl` (from [smartmontools](https://www.smartmontools.org/))  
  - `lsblk`  
  - Basic GNU utilities (e.g., `awk`, `sed`, `grep`)

## Usage

1. **Clone the Repository:**

   ```bash
   git clone https://github.com/hevel86/zfs_scripts.git
   cd zfs_scripts
   ```
2. **Make the Script Executable:**
   ```bash
   chmod +x zpool_replace.sh
   ```
3. **Run the Script:**
   ```bash
   ./zpool_replace.sh
   ```

The script will:
1. **Check** all ZFS pools to see if any are degraded and if resilvering is in progress.
2. **Prompt** you to select the degraded pool if more than one is detected.
3. **Identify** the missing or removed disk in that pool.
4. **Build** a list of disks used by any pool to exclude them from the candidate list.
5. **Show** you the remaining disks along with detailed info (model, serial, size).
6. **Prompt** you to select the replacement disk and confirm.
7. **Execute** the zpool replace command if you confirm.

## Example:

Below is a sample run with placeholders:
```bash
⚠️  Selected degraded pool: <POOL_NAME>

❌ Missing disk identifier (from pool): <MISSING_DISK_ID>

🔍 Scanning for candidate new disks (drives not in any pool)...
💡 Candidate new disks found:
[0] <NEW_DISK_ID> -> Device: <DEVICE_PATH>, Model: <MODEL>, Serial: <SERIAL>, Size: <SIZE>

👉 Enter the number corresponding to the new disk you want to use: 0

✅ Selected new disk:
Identifier: <NEW_DISK_ID>
Device: <DEVICE_PATH>
Model: <MODEL>, Serial: <SERIAL>, Size: <SIZE>

❓ Would you like to replace missing disk <MISSING_DISK_ID> in pool <POOL_NAME> with new disk <NEW_DISK_ID>? [y/N]
```
_After confirming, give it a few seconds to execute before panicking and pulling the plug!_

## Fonts:
Not seeing the emojis in your terminal?  Download `Terminess Nerd Font` [here!](https://www.nerdfonts.com/font-downloads)

## License
This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.


**Happy ZFS managing! 🚀**