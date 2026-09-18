# Shared helpers for editing the project-owned block inside /etc/boot/startup.sh.
# Sourced by autostart_mmi_mirror_on.sh / autostart_mmi_mirror_off.sh /
# uninstall_mmi_mirror.sh. Part of Toolbox/scripts, deployed as a whole directory.

MMI_BLOCK_BEGIN="# MMI MIRROR V2.2 AUTOSTART BEGIN"
MMI_BLOCK_END="# MMI MIRROR V2.2 AUTOSTART END"

# Prints "<begin_count> <end_count>" for the given file.
startup_block_counts() {
    FILE="$1"
    BEGIN_CNT=$(grep -cF "${MMI_BLOCK_BEGIN}" "${FILE}" 2>/dev/null)
    END_CNT=$(grep -cF "${MMI_BLOCK_END}" "${FILE}" 2>/dev/null)
    [ -n "${BEGIN_CNT}" ] || BEGIN_CNT=0
    [ -n "${END_CNT}" ] || END_CNT=0
    echo "${BEGIN_CNT} ${END_CNT}"
}

# Returns 0 only when the block markers are paired (or fully absent).
# An unpaired BEGIN (missing END) makes a range delete run to end-of-file and
# destroy unrelated startup content - every caller must refuse in that case.
startup_block_pairing_ok() {
    FILE="$1"
    set -- $(startup_block_counts "${FILE}")
    [ "$1" -eq "$2" ] || return 1
    [ "$1" -eq 0 ] && return 0
    FIRST_BEGIN=$(grep -nF "${MMI_BLOCK_BEGIN}" "${FILE}" | head -1 | cut -d: -f1)
    FIRST_END=$(grep -nF "${MMI_BLOCK_END}" "${FILE}" | head -1 | cut -d: -f1)
    [ -n "${FIRST_BEGIN}" ] && [ -n "${FIRST_END}" ] || return 1
    [ "${FIRST_END}" -gt "${FIRST_BEGIN}" ] || return 1
    return 0
}

# Deletes the block between the markers in FILE, operating on a temporary copy
# and verifying the result before replacing FILE in place. Returns 1 and leaves
# FILE untouched if the pre-state or the edited result fails validation.
startup_block_delete() {
    FILE="$1"
    WORK="${FILE}.mmi-block.tmp"

    startup_block_pairing_ok "${FILE}" || return 1
    ORIG_LINES=$(wc -l < "${FILE}")

    cp "${FILE}" "${WORK}" || return 1
    sed -i "/${MMI_BLOCK_BEGIN}/,/${MMI_BLOCK_END}/d" "${WORK}" || {
        rm -f "${WORK}"
        return 1
    }

    set -- $(startup_block_counts "${WORK}")
    [ "$1" -eq 0 ] && [ "$2" -eq 0 ] || {
        rm -f "${WORK}"
        return 1
    }
    # Sanity: an intact removal must not grow the file and must not empty it.
    EDITED_LINES=$(wc -l < "${WORK}")
    [ "${EDITED_LINES}" -le "${ORIG_LINES}" ] || {
        rm -f "${WORK}"
        return 1
    }
    [ -s "${WORK}" ] || {
        rm -f "${WORK}"
        return 1
    }

    cat "${WORK}" > "${FILE}" || {
        rm -f "${WORK}"
        return 1
    }
    rm -f "${WORK}"
    sync
    return 0
}

# Inserts BLOCKFILE after the line containing ANCHOR in FILE, on a temporary
# copy that is verified (single block, correct placement) before replacing
# FILE in place. Returns 1 and leaves FILE untouched on any failure.
startup_block_insert() {
    FILE="$1"
    ANCHOR="$2"
    BLOCKFILE="$3"
    WORK="${FILE}.mmi-block.tmp"

    startup_block_pairing_ok "${FILE}" || return 1
    ANCHOR_CNT=$(grep -cF "${ANCHOR}" "${FILE}" 2>/dev/null)
    [ "${ANCHOR_CNT}" = "1" ] || return 1

    cp "${FILE}" "${WORK}" || return 1
    sed -i "/${ANCHOR}/r ${BLOCKFILE}" "${WORK}" || {
        rm -f "${WORK}"
        return 1
    }

    set -- $(startup_block_counts "${WORK}")
    [ "$1" -eq 1 ] && [ "$2" -eq 1 ] || {
        rm -f "${WORK}"
        return 1
    }
    ANCHOR_LINE=$(grep -nF "${ANCHOR}" "${WORK}" | head -1 | cut -d: -f1)
    BEGIN_LINE=$(grep -nF "${MMI_BLOCK_BEGIN}" "${WORK}" | head -1 | cut -d: -f1)
    END_LINE=$(grep -nF "${MMI_BLOCK_END}" "${WORK}" | head -1 | cut -d: -f1)
    case "${ANCHOR_LINE}:${BEGIN_LINE}:${END_LINE}" in
        *[!0-9:]*) rm -f "${WORK}"; return 1 ;;
    esac
    [ "${BEGIN_LINE}" -gt "${ANCHOR_LINE}" ] && [ "${END_LINE}" -gt "${BEGIN_LINE}" ] || {
        rm -f "${WORK}"
        return 1
    }

    cat "${WORK}" > "${FILE}" || {
        rm -f "${WORK}"
        return 1
    }
    rm -f "${WORK}"
    sync
    return 0
}
