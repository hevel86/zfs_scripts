# ZFS Pool Replace Script

This repository contains a handy Bash script to help you manage disk replacements in your ZFS pools. The `zpool_replace.sh` script is designed to interactively guide you through the process of replacing a missing or degraded disk in your ZFS pool. It is especially useful for pools configured with RAIDz2, mirrors, or other vdev types.

## Features

- **Interactive Replacement:**  
  The script walks you through the process by:
  1. Detecting a degraded ZFS pool and identifying the missing disk.
  2. Scanning for candidate replacement disks that are not currently in the pool.
  3. Displaying detailed information (model, serial number, size, etc.) for the missing disk and each candidate.
  4. Prompting you for confirmation before executing the `zpool replace` command.

- **Resilver Check:**  
  Before taking any action, the script checks if the pool is currently resilvering. If so, it will exit, ensuring that you don’t disrupt an in-progress rebuild.

- **Detailed Disk Info:**  
  The script leverages tools like `smartctl` and `lsblk` to retrieve and display important details about your disks.

- **User-Friendly Prompts:**  
  Friendly interactive prompts and emojis help guide you through the replacement process, making it easier to manage disk failures.

## Requirements

- **Operating System:**  
  Linux (e.g. Proxmox VE, Ubuntu, Debian)

- **Dependencies:**  
  - ZFS (with the `zpool` command)
  - [smartmontools](https://www.smartmontools.org/) (for `smartctl`)
  - `lsblk`
  - Basic GNU utilities (such as `awk`, `sed`, and `grep`)

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
    - Check if the pool is healthy or if a resilver is in progress.
    - Identify the missing disk in your degraded pool.
    - Scan and list candidate disks that are not part of the pool.
    - Prompt you to select a replacement disk.
    - Confirm the replacement operation before executing the zpool replace command.

## License
This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.


Happy ZFS managing! 🚀