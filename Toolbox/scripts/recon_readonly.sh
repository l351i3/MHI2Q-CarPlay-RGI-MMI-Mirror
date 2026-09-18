#!/bin/sh
# READ-ONLY vehicle recon for CarPlay RGI / MMI Mirror planning.
#
# Guarantees:
#   - never mounts anything read-write and never writes to /mnt/app,
#     /mnt/system or /etc (pure reads of the head unit);
#   - all output goes to the Toolbox SD card under Backup/recon-<timestamp>/.
#
# Produces the per-vehicle baseline needed before any install decision:
# firmware train / unit info, copies of every file the RGI or MMI Mirror
# installers would touch, checksums, marker/process state and a checklist of
# things that must be confirmed manually in the Green Engineering Menu.

export PATH=/proc/boot:/bin:/usr/bin:/usr/sbin:/sbin:/mnt/app/media/gracenote/bin:/mnt/app/armle/bin:/mnt/app/armle/sbin:/mnt/app/armle/usr/bin:/mnt/app/armle/usr/sbin:$PATH

if [ "$_" = "/bin/on" ]; then BASE="$0"; else BASE="$_"; fi
SCRIPTDIR=$( cd -P -- "$(dirname -- "$(command -v -- "$BASE")")" && pwd -P )

# Detect the Toolbox SD card without mounting anything.
if [ -d /net/mmx/fs/sda0/Toolbox ]; then
    VOLUME="/net/mmx/fs/sda0"
elif [ -d /net/mmx/fs/sdb0/Toolbox ]; then
    VOLUME="/net/mmx/fs/sdb0"
else
    echo "No Toolbox SD card found. Aborting (nothing was read or written)."
    exit 1
fi

exec 3>&1
OUT="${VOLUME}/Backup/recon-$(date '+%Y%m%d-%H%M%S')"
mkdir -p "${OUT}/files" || exit 1
LOGFILE="${OUT}/recon.log"
touch "${LOGFILE}" || exit 1
exec >> "${LOGFILE}" 2>&1

log() {
    echo "$*"
    echo "$*" >&3
}
section() {
    echo ""
    echo "===== $* ====="
    echo "===== $* =====" >&3
}

log "===== CarPlay RGI / MMI Mirror READ-ONLY recon started ====="
date
log "Output: ${OUT}"
log "This script only READS the head unit; nothing on /mnt or /etc was modified."

section "1. Firmware train and unit identity"
if [ -f /net/rcc/dev/shmem/version.txt ]; then
    cp -p /net/rcc/dev/shmem/version.txt "${OUT}/version.txt" 2>/dev/null
    log "Full version.txt copied to files-listing below. Key lines:"
    grep -iE "current train|train|mainunit|hw|hmi|variant" "${OUT}/version.txt" 2>/dev/null | head -20
else
    log "WARNING: /net/rcc/dev/shmem/version.txt not readable - train UNKNOWN"
fi
if [ -f /tmp/fazit-id ]; then
    log "FAZIT: $(cat /tmp/fazit-id)"
else
    log "FAZIT: unknown (/tmp/fazit-id absent)"
fi

section "2. Files the installers would touch (copies + checksums)"
dump_file() {
    LABEL="$1"
    SRC="$2"
    if [ -f "${SRC}" ]; then
        if cp -p "${SRC}" "${OUT}/files/${LABEL}" 2>/dev/null; then
            log "PRESENT  ${SRC} (copy saved as files/${LABEL})"
        else
            log "PRESENT  ${SRC} (WARNING: copy to SD failed - metadata only)"
        fi
        log "         size=$(wc -c < "${SRC}")  cksum=$(cksum < "${SRC}" 2>/dev/null)"
    else
        log "ABSENT   ${SRC}"
    fi
}
dump_file "smartphone_integrator.json" "/mnt/system/etc/eso/production/smartphone_integrator.json"
dump_file "dio_manager.json"           "/mnt/system/etc/eso/production/dio_manager.json"
dump_file "libcarplay_hook.so"         "/mnt/app/root/hooks/libcarplay_hook.so"
dump_file "maneuver_render"            "/mnt/app/root/hooks/maneuver_render"
dump_file "flag_atlas.rgba"            "/mnt/app/root/hooks/flag_atlas.rgba"
dump_file "carplay_hook.jar"           "/mnt/app/eso/hmi/lsd/jars/carplay_hook.jar"
dump_file "startup.sh"                 "/etc/boot/startup.sh"

section "3. Directory listings"
log "--- /mnt/app/root/hooks ---"
ls -la /mnt/app/root/hooks 2>/dev/null || log "  (absent)"
log "--- /mnt/app/eso/hmi/lsd/jars ---"
ls -la /mnt/app/eso/hmi/lsd/jars 2>/dev/null || log "  (absent)"
log "--- /mnt/app/root/mmi-mirror ---"
ls -la /mnt/app/root/mmi-mirror 2>/dev/null || log "  (absent)"

section "4. Existing install / autostart markers"
if [ -f /etc/boot/startup.sh ]; then
    log "startup.sh MMI MIRROR AUTOSTART BEGIN count: $(grep -cF '# MMI MIRROR V2.2 AUTOSTART BEGIN' /etc/boot/startup.sh 2>/dev/null)"
    log "startup.sh MMI MIRROR AUTOSTART END count:   $(grep -cF '# MMI MIRROR V2.2 AUTOSTART END' /etc/boot/startup.sh 2>/dev/null)"
    log "startup.sh LD_PRELOAD hook references:       $(grep -c 'libcarplay_hook.so' /etc/boot/startup.sh 2>/dev/null)"
fi
log "AutoStart marker on unit: $(ls /mnt/app/eso/hmi/engdefs/scripts/mqb/.mmi_mirror_autostart 2>/dev/null || echo absent)"
log "mmi-mirror tmp markers: $(ls /tmp/mmi-mirror-* 2>/dev/null | tr '\n' ' ' || echo none)"

section "5. Running processes of interest"
if command -v pidin >/dev/null 2>&1; then
    PROCESSES=$(pidin ar 2>/dev/null | grep -E 'dio_manager|maneuver_render|mmi-mirror|sshd|carplay' | head -20)
    if [ -n "${PROCESSES}" ]; then
        log "${PROCESSES}"
    else
        log "(no matching processes running)"
    fi
else
    log "pidin unavailable"
fi

section "6. Manual checks required in the Green Engineering Menu (not readable here)"
log "a) production/version_prod/Console: note the MainUnit (MU) version number"
log "b) Confirm the instrument cluster is the 12.3\" Virtual Cockpit"
log "c) Confirm whether a windshield HUD is fitted (affects what guidance surfaces on)"

log ""
log "===== Recon finished. Give the train, MU number and this folder to the review. ====="
log "Nothing outside ${OUT} was written; no head-unit file was modified."
echo "===== CarPlay RGI / MMI Mirror READ-ONLY recon finished =====" >&3
exit 0
