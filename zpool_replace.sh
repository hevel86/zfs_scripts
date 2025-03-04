#!/bin/bash
# Interactive ZFS Disk Replacement Script with Resilver Check & Emojis
# This script assists you in replacing a missing disk in a degraded ZFS pool.
# It will:
#   1. Check if the pool is currently resilvering and exit if so.
#   2. Identify a missing disk from the pool.
#   3. List candidate new disks not already in the pool.
#   4. Show details (model, serial, size) for the candidate new disks.
#   5. Prompt for confirmation and execute the zpool replace command.

# Step 0: Check if the pool is already resilvering.
if zpool status | grep -q "resilver"; then
    echo "🔄 The pool is currently resilvering. Please wait until the resilver completes before attempting a replacement."
    exit 0
fi

# Function to get smartctl info (model, serial) and size (via lsblk) for a given device.
get_disk_info() {
    local device="$1"
    local smart_output model serial size
    smart_output=$(smartctl -i "$device" 2>/dev/null)
    model=$(echo "$smart_output" | awk -F': ' '/Device Model:|Product identification:/ {print $2; exit}')
    serial=$(echo "$smart_output" | awk -F': ' '/Serial Number:|Unit serial number:/ {print $2; exit}')
    size=$(lsblk -dn -o SIZE "$device")
    [ -z "$model" ] && model="Unknown"
    [ -z "$serial" ] && serial="Unknown"
    echo "$model" "$serial" "$size"
}

# Step 1: Detect the degraded pool and the missing disk.
pool=$(zpool status | awk '/pool:/ {pool=$2} /MISSING|UNAVAIL/ {print pool; exit}')
if [ -z "$pool" ]; then
    echo "✅ The pool is healthy. No missing disk detected. Exiting."
    exit 1
fi

missing_line=$(zpool status | grep -E "MISSING|UNAVAIL" | head -n1)
missing_identifier=$(echo "$missing_line" | awk '{print $1}')
echo "⚠️  Detected degraded pool: $pool"
echo "❌ Missing disk identifier (from pool): $missing_identifier"
echo

# Step 2: Build a list of current disks in the pool.
pool_disks=()
while read -r line; do
    # Only process lines that start with an identifier (ata- or scsi-)
    if [[ $line =~ ^[[:space:]]+((ata-|scsi-)[^[:space:]]+) ]]; then
        pd=$(echo "$line" | awk '{print $1}')
        # Strip any partition suffix.
        base_pd=$(echo "$pd" | sed 's/-part.*//')
        pool_disks+=("$base_pd")
    fi
done < <(zpool status "$pool")

# Step 3: Scan /dev/disk/by-id for candidate new disks that are not in the pool.
echo "🔍 Scanning for candidate new disks (drives not in the pool)..."
new_candidates=()
for id_path in /dev/disk/by-id/ata-* /dev/disk/by-id/scsi-*; do
    [ -e "$id_path" ] || continue
    id=$(basename "$id_path")
    skip=0
    for pd in "${pool_disks[@]}"; do
        if [[ "$id" == "$pd" ]]; then
            skip=1
            break
        fi
    done
    if [ $skip -eq 0 ]; then
        new_candidates+=("$id")
    fi
done

if [ ${#new_candidates[@]} -eq 0 ]; then
    echo "🚫 No candidate new disks found. Please insert a new disk and try again."
    exit 1
fi

# Step 4: List candidate new disks with details.
echo "💡 Candidate new disks found:"
for i in "${!new_candidates[@]}"; do
    candidate="${new_candidates[$i]}"
    # Resolve the device path.
    device=$(readlink -f "/dev/disk/by-id/$candidate")
    # Get disk details.
    read model serial size <<< $(get_disk_info "$device")
    echo "[$i] $candidate -> Device: $device, Model: $model, Serial: $serial, Size: $size"
done
echo

# Step 5: Prompt user to select a candidate disk.
read -p "👉 Enter the number corresponding to the new disk you want to use: " candidate_index
if ! [[ $candidate_index =~ ^[0-9]+$ ]] || [ $candidate_index -ge ${#new_candidates[@]} ]; then
    echo "❌ Invalid selection. Exiting."
    exit 1
fi

new_disk="${new_candidates[$candidate_index]}"
new_device=$(readlink -f "/dev/disk/by-id/$new_disk")

echo
echo "✅ Selected new disk:"
echo "Identifier: $new_disk"
echo "Device: $new_device"
read model serial size <<< $(get_disk_info "$new_device")
echo "Model: $model, Serial: $serial, Size: $size"
echo

# Step 6: Confirm replacement.
read -p "❓ Would you like to replace missing disk $missing_identifier with new disk $new_disk? [y/N] " answer
if [[ "$answer" =~ ^[Yy] ]]; then
    cmd="zpool replace $pool $missing_identifier $new_disk"
    echo
    echo "⚙️  OK, I'm about to execute this command:"
    echo "$cmd"
    read -p "👉 Press Enter to continue or Ctrl+C to cancel..."
    # Execute the replacement command.
    $cmd
    echo "✅ Replacement command executed. Please check 'zpool status' for progress."
else
    echo "✋ Replacement cancelled."
fi
