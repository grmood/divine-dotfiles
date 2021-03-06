#!/usr/bin/env bash
#:title:        Divine Bash procedure: update-pkgs
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.11.30
#:revremark:    Rewrite all Github references to point to new repo location
#:created_at:   2019.05.14

## Part of Divine.dotfiles <https://github.com/divine-dotfiles/divine-dotfiles>
#
## This file is intended to be sourced from framework's main script.
#
## Updates currently installed system packages.
#

# Marker and dependencies
readonly D__PCD_UPDATE_PKGS=loaded
d__load util workflow
d__load procedure detect-os

#>  d__pcd_update_pkgs
#
## Shared subroutine that runs update+upgrade process on the detected system 
#. package manager.
#
## Returns:
#.  0 - Always
#
d__pcd_update_pkgs()
{
  # Cut-off checks
  local d__rsn=()
  if ! $D__REQ_PKGS
  then d__rsn+=( -i- '- Divinefiles not requested' ); fi
  if [ $D__INT_PKG_COUNT -eq 0 ]
  then d__rsn+=( -i- '- zero packages detected across Divinefiles' ); fi
  if [ -z "$D__OS_PKGMGR" ]
  then d__rsn+=( -i- '- package manager not supported' ); fi
  if ((${#d__rsn[@]})); then
    d__notify -qqns -- 'Skipping updating packages:' "${d__rsn[@]}"
    return 0
  fi

  # Print a separating empty line; compose name of the task
  printf >&2 '\n'
  local d__plq="$( printf "(%${D__WKLD_MAX_PRTY_LEN}d)" 0 )"
  d__plq+=" System packages via '$BOLD$D__OS_PKGMGR$NORMAL'"

  # Early exit for dry runs
  if [ "$D__OPT_ANSWER" = false ]; then
    printf >&2 '%s %s\n' "$D__INTRO_UPD_S" "$d__plq"; return 0
  fi

  # Print intro
  printf >&2 '%s %s\n' "$D__INTRO_UPD_N" "$d__plq"

  # Conditionally prompt for user's approval
  if [ "$D__OPT_ANSWER" != true ]; then
    printf >&2 '%s ' "$D__INTRO_CNF_N"
    if ! d__prompt -b; then
      printf >&2 '%s %s\n' "$D__INTRO_UPD_S" "$d__plq"; return 0
    fi
  fi

  # Launch OS package manager
  d__os_pkgmgr update

  # Check return status
  if [ $? -eq 0 ]; then
    printf >&2 '%s %s\n' "$D__INTRO_UPD_0" "$d__plq"
  else
    d__notify -l! -- "System package manager '$D__OS_PKGMGR'" \
      'returned an error code while updating packages' \
      -n- 'This may or may not be problematic'
    printf >&2 '%s %s\n' "$D__INTRO_UPD_1" "$d__plq"
  fi
}

d__pcd_update_pkgs