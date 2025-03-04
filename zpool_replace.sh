#!/bin/bash
# Interactive ZFS Disk Replacement Script with Multi-Pool Health Check & Emoji
# This script assists you in replacing a missing disk in any degraded ZFS pool.
# It will:
#   1. Check all pools for a degraded/unhealthy state.
#   2. If one or more degraded pools are found, list them for selection.
#   3. For the selected pool, detect the missing disk.
#   4. Build a list of all disks currently in any pool.
#   5. Scan for candidate new disks (those not in any pool).
#   6. Display detailed info (model, serial, size, etc.) for each candidate.
#   7. Prompt for confirmation before executing the zpool replace command.

# Step 0: Check if any pool is currently resilvering.
scan_line=$(zpool status | grep "^  scan:")
if echo "$scan_line" | grep -q "resilvering"; then
    echo "🔄 The pool is currently resilvering. Please wait until the resilver completes before attempting a replacement."
    exit 0
fi

# Step 1: Gather all degraded (or unhealthy) pools (state not ONLINE).
degraded_pools=()
while read -r line; do
    pool_name=$(echo "$line" | awk '{print $2}')
    degraded_pools+=("$pool_name")
done < <(zpool status | grep -E "^  pool:" | while read -r l; do
    pool=$(echo "$l" | awk '{print $2}')
    state_line=$(zpool status "$pool" | grep "state:" | head -n1)
    state=$(echo "$state_line" | awk '{print $2}')
    if [ "$state" != "ONLINE" ]; then
        echo "$l"
    fi
done)

if [ ${#degraded_pools[@]} -eq 0 ]; then
    echo "✅ All pools are healthy. No degraded pools detected."
    exit 0
fi

# Step 2: List degraded pools and let user select one if there are multiple.
if [ ${#degraded_pools[@]} -gt 1 ]; then
    echo "⚠️  The following degraded pools were detected:"
    for i in "${!degraded_pools[@]}"; do
        echo "[$i] ${degraded_pools[$i]}"
    done
    read -p "👉 Enter the number corresponding to the pool you want to repair: " pool_index
    if ! [[ $pool_index =~ ^[0-9]+$ ]] || [ $pool_index -ge ${#degraded_pools[@]} ]; then
        echo "❌ Invalid selection. Exiting."
        exit 1
    fi
    selected_pool="${degraded_pools[$pool_index]}"
else
    selected_pool="${degraded_pools[0]}"
fi

echo "⚠️  Selected degraded pool: $selected_pool"
echo

# Step 3: Detect the missing disk in the selected pool.
# Use awk to extract the disk identifier where the first field starts with ata-/scsi- and status is REMOVED (or similar).
missing_line=$(zpool status "$selected_pool" | awk '/REMOVED/ && ($1 ~ /^(ata-|scsi-)/){print; exit}')
if [ -z "$missing_line" ]; then
    echo "✅ No missing disk found in pool $selected_pool. Exiting."
    exit 0
fi
missing_identifier=$(echo "$missing_line" | awk '{print $1}')
echo "❌ Missing disk identifier (from pool): $missing_identifier"
echo

# Step 4: Build a list of all disks currently in any pool.
all_pool_disks=()
for pool in $(zpool list -H -o name); do
    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]+((ata-|scsi-)[^[:space:]]+) ]]; then
            pd=$(echo "$line" | awk '{print $1}')
            base_pd=$(echo "$pd" | sed 's/-part.*//')
            all_pool_disks+=("$base_pd")
        fi
    done < <(zpool status "$pool")
done

# Remove duplicate entries.
all_pool_disks=($(printf "%s\n" "${all_pool_disks[@]}" | sort -u))

# Step 5: Scan /dev/disk/by-id for candidate new disks that are not in any pool.
echo "🔍 Scanning for candidate new disks (drives not in any pool)..."
new_candidates=()
for id_path in /dev/disk/by-id/ata-* /dev/disk/by-id/scsi-*; do
    [ -e "$id_path" ] || continue
    id=$(basename "$id_path")
    # Remove partition suffix if present.
    base_id=$(echo "$id" | sed 's/-part.*//')
    skip=0
    for pd in "${all_pool_disks[@]}"; do
        if [[ "$base_id" == "$pd" ]]; then
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

# Function to get disk details using smartctl and lsblk.
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

# Step 6: List candidate new disks with details.
echo "💡 Candidate new disks found:"
for i in "${!new_candidates[@]}"; do
    candidate="${new_candidates[$i]}"
    device=$(readlink -f "/dev/disk/by-id/$candidate")
    read model serial size <<< $(get_disk_info "$device")
    echo "[$i] $candidate -> Device: $device, Model: $model, Serial: $serial, Size: $size"
done
echo

# Step 7: Prompt user to select a candidate disk.
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

# Step 8: Confirm replacement.
read -p "❓ Would you like to replace missing disk $missing_identifier in pool $selected_pool with new disk $new_disk? [y/N] " answer
if [[ "$answer" =~ ^[Yy] ]]; then
    cmd="zpool replace $selected_pool $missing_identifier $new_disk"
    echo
    echo "⚙️  OK, I'm about to execute this command:"
    echo "$cmd"
    read -p "👉 Press Enter to continue or Ctrl+C to cancel..."
    $cmd
    echo "✅ Replacement command executed. Please check 'zpool status' for progress."
else
    echo "✋ Replacement cancelled."
fi
