#!/usr/bin/env bash
#:title:        Divine Bash routine: check
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    35
#:revdate:      2019.08.15
#:revremark:    Execute deployment code in a subshell
#:created_at:   2019.05.14

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## This file is intended to be sourced from framework's main script
#
## Checks packages and deployments as requested
#

#>  d__perform_check_routine
#
## Performs checking routine
#
# For each priority level, from smallest to largest, separately:
#.  * Checks whether packages are installed, in order they appear in Divinefile
#.  * Checks whether deployments are installed, in no particular order
#
## Returns:
#.  0 - Routine performed
#.  1 - Routine terminated prematurely
#
d__perform_check_routine()
{
  # Print empty line for visual separation
  printf >&2 '\n'

  # Announce beginning
  if [ "$D__OPT_ANSWER" = false ]; then
    dprint_plaque -pcw "$WHITE" "$D__CONST_PLAQUE_WIDTH" \
      -- "'Checking' Divine intervention"
  else
    dprint_plaque -pcw "$GREEN" "$D__CONST_PLAQUE_WIDTH" \
      -- 'Checking Divine intervention'
  fi

  # Storage variable
  local priority

  # Iterate over taken priorities
  for priority in "${!D__WORKLOAD[@]}"; do

    # Install packages if asked to
    d__check_pkgs "$priority"

    # Install deployments if asked to
    d__check_dpls "$priority"
    
  done

  # Announce completion
  printf '\n'
  if [ "$D__OPT_ANSWER" = false ]; then
    dprint_plaque -pcw "$WHITE" "$D__CONST_PLAQUE_WIDTH" \
      -- "Successfully 'checked' Divine intervention"
  else
    dprint_plaque -pcw "$GREEN" "$D__CONST_PLAQUE_WIDTH" \
      -- 'Successfully checked Divine intervention'
  fi
  return 0
}

#>  d__check_pkgs PRIORITY_LEVEL
#
## For the given priority level, check if packages are installed, one by one, 
#. using their names, which have been previously assembled in $D__WORKLOAD_PKGS 
#. array
#
## Requires:
#.  * Divine Bash utils: dOS (dps.utl.sh)
#.  * Divine Bash utils: dprint (dprint.utl.sh)
#
## Returns:
#.  0 - Packages checked
#.  1 - No attempt to check has been made
#
## Prints:
#.  stdout: Progress messages
#.  stderr: As little as possible
#
d__check_pkgs()
{
  # Check whether packages are asked for
  $D__REQ_PACKAGES || return 1

  # Check whether package manager has been detected
  [ -n "$D__OS_PKGMGR" ] || return 1

  # Extract priority
  local priority
  priority="$1"; shift

  # Check if priority has been passed
  [ -n "$priority" ] || return 1

  # Storage variables
  local task_desc task_name proceeding
  local pkg_str chunks=() pkgname mode

  # Split package names on $D__CONST_DELIMITER
  pkg_str="${D__WORKLOAD_PKGS[$priority]}"
  while [[ $pkg_str ]]; do
    chunks+=( "${pkg_str%%"$D__CONST_DELIMITER"*}" )
    pkg_str="${pkg_str#*"$D__CONST_DELIMITER"}"
  done

  # Iterate over package names
  for pkgname in "${chunks[@]}"; do

    # Empty name - continue
    [ -n "$pkgname" ] || continue

    # Extract mode if it is present
    read -r mode pkgname <<<"$pkgname"
    # Mode is ignored when checking packages (unlike deployments)

    # Name current task
    task_desc='Package'
    task_name="'$pkgname'"

    # Prefix priority
    task_desc="$( printf \
      "(%${D__REQ_MAX_PRIORITY_LEN}d) %s\n" \
      "$priority" "$task_desc" )"

    # Local flag for whether to proceed
    proceeding=true

    # Don't proceed if '-n' option is given
    [ "$D__OPT_ANSWER" = false ] && proceeding=false

    # Print newline to visually separate tasks
    printf '\n'

    # Perform check
    if $proceeding; then
      if d__os_pkgmgr check "$pkgname"; then        
        # Check if record of installation exists in root stash
        if d__stash --root --skip-checks has "pkg_$( dmd5 -s "$pkgname" )"; then
          # Installed by this framework
          dprint_ode "${D__ODE_NAME[@]}" -c "$GREEN" -- \
            'vvv' 'Installed' ':' "$task_desc" "$task_name"
        else
          # Installed by user or OS
          task_name="$task_name (installed by user or OS)"
          dprint_ode "${D__ODE_NAME[@]}" -c "$MAGENTA" -- \
            '~~~' 'Installed' ':' "$task_desc" "$task_name"
        fi
      else
        dprint_ode "${D__ODE_NAME[@]}" -c "$RED" -- \
          'xxx' 'Not installed' ':' "$task_desc" "$task_name"
      fi
    else
      dprint_ode "${D__ODE_NAME[@]}" -c "$WHITE" -- \
        '---' 'Skipped' ':' "$task_desc" "$task_name"
    fi

  done

  return 0
}

#>  d__check_dpls PRIORITY_LEVEL
#
## For the given priority level, checks whether deployments are installed, one 
#. by one, using their *.dpl.sh files, paths to which have been previously 
#. assembled in $D__WORKLOAD_DPLS array
#
## Requires:
#.  * Divine Bash utils: dOS (dps.utl.sh)
#.  * Divine Bash utils: dprint (dprint.utl.sh)
#
## Returns:
#.  0 - Deployments checked
#.  1 - No attempt to check has been made
#
## Prints:
#.  stdout: Progress messages
#.  stderr: As little as possible
#
d__check_dpls()
{
  # Extract priority
  local priority
  priority="$1"; shift

  # Check if priority has been passed
  [ -n "$priority" ] || return 1

  # Storage variables
  local task_desc task_name proceeding
  local dpl_str chunks=() divinedpl_filepath
  local name desc warning mode
  local aa_mode dpl_status

  # Split *.dpl.sh filepaths on $D__CONST_DELIMITER
  dpl_str="${D__WORKLOAD_DPLS[$priority]}"
  while [[ $dpl_str ]]; do
    chunks+=( "${dpl_str%%"$D__CONST_DELIMITER"*}" )
    dpl_str="${dpl_str#*"$D__CONST_DELIMITER"}"
  done

  # Iterate over *.dpl.sh filepaths
  for divinedpl_filepath in "${chunks[@]}"; do

    # Check if *.dpl.sh is a readable file
    [ -r "$divinedpl_filepath" -a -f "$divinedpl_filepath" ] || continue

    # Empty out storage variables
    name=
    desc=
    mode=
    # Undefine global functions
    unset -f d_dpl_check
    unset -f d_dpl_install
    unset -f d_dpl_remove

    # Extract name assignment from *.dpl.sh file (first one wins)
    read -r name < <( sed -n "s/$D__REGEX_DPL_NAME/\1/p" \
      <"$divinedpl_filepath" )
    # Process name
    # Trim name, removing quotes if any
    name="$( dtrim -Q -- "$name" )"
    # Truncate name to 64 chars
    name="$( dtrim -- "${name::64}" )"
    # Detect whether name is not empty
    [ -n "$name" ] || {
      # Fall back to name precefing *.dpl.sh suffix
      name="$( basename -- "$divinedpl_filepath" )"
      name=${name%$D__SUFFIX_DPL_SH}
    }

    # Extract description assignment from *.dpl.sh file (first one wins)
    read -r desc < <( sed -n "s/$D__REGEX_DPL_DESC/\1/p" \
      <"$divinedpl_filepath" )
    # Process description
    # Trim description, removing quotes if any
    desc="$( dtrim -Q -- "$desc" )"

    # Extract warning assignment from *.dpl.sh file (first one wins)
    read -r warning < <( sed -n "s/$D__REGEX_DPL_WARNING/\1/p" \
      <"$divinedpl_filepath" )
    # Process warning
    # Trim warning, removing quotes if any
    warning="$( dtrim -Q -- "$warning" )"

    # Extract mode assignment from *.dpl.sh file (first one wins)
    read -r mode < <( sed -n "s/$D__REGEX_DPL_FLAGS/\1/p" \
      <"$divinedpl_filepath" )
    # Process mode
    # Trim mode, removing quotes if any
    mode="$( dtrim -Q -- "$mode" )"

    # Process $D_DPL_FLAGS
    aa_mode=false
    [[ $mode = *a* ]] && aa_mode=true
    [[ $mode = *c* ]] && aa_mode=true

    # Name current task
    task_desc='Deployment'
    task_name="'$name'"

    # Prefix priority
    task_desc="$( printf \
      "(%${D__REQ_MAX_PRIORITY_LEN}d) %s\n" \
      "$priority" "$task_desc" )"

    # Local flag for whether to proceed
    proceeding=true

    # Don't proceed if '-n' option is given
    [ "$D__OPT_ANSWER" = false ] && proceeding=false

    # Print newline to visually separate tasks
    printf '\n'

    # Conditionally print intro
    if $proceeding && [ "$aa_mode" = true -o "$D__OPT_ANSWER" != true \
      -o "$D__OPT_QUIET" = false ]
    then

      # Print message about the upcoming checking
      dprint_ode "${D__ODE_NAME[@]}" -c "$YELLOW" -- \
        '>>>' 'Checking' ':' "$task_desc" "$task_name" \
        && intro_printed=true
      # If description is available, show it
      [ -n "$desc" ] && dprint_ode "${D__ODE_DESC[@]}" -- \
        '' 'Description' ':' "$desc"

    fi

    ## Unless given a '-y' option (or unless aa_mode is enabled), prompt for 
    #. user's approval
    if $proceeding && [ "$aa_mode" = true -o "$D__OPT_ANSWER" != true ]
    then

      # In verbose mode, print location of script to be sourced
      dprint_debug "Location: $divinedpl_filepath"
      # If warning is relevant, show it
      [ -n "$warning" -a "$aa_mode" = true ] \
        && dprint_ode "${D__ODE_WARN[@]}" -c "$RED" -- \
          '' 'Warning' ':' "$warning"

      # Prompt slightly differs depending on whether 'always ask' is enabled
      if $aa_mode; then
        dprint_ode "${D__ODE_DANGER[@]}" -c "$RED" -- '!!!' 'Danger' ': '
      else
        dprint_ode "${D__ODE_PROMPT[@]}" -- '' 'Confirm' ': '
      fi

      # Prompt user
      dprompt_key --bare && proceeding=true || {
        task_name="$task_name (declined by user)"
        proceeding=false
      }

    fi

    # If still proceeding, enter the final stage
    if $proceeding; then

      # Open subshell for security
      (

        # Expose variables to deployment
        D_DPL_NAME="$name"
        D__DPL_SH_PATH="$divinedpl_filepath"
        D__DPL_MNF_PATH="${divinedpl_filepath%$D__SUFFIX_DPL_SH}"
        D__DPL_QUE_PATH="${D__DPL_MNF_PATH}$D__SUFFIX_DPL_QUE"
        D__DPL_MNF_PATH+="$D__SUFFIX_DPL_MNF"
        D__DPL_DIR="$( dirname -- "$divinedpl_filepath" )"
        D__DPL_ASSET_DIR="$D__DIR_ASSETS/$D_DPL_NAME"
        D__DPL_BACKUP_DIR="$D__DIR_BACKUPS/$D_DPL_NAME"

        # Print debug message
        dprint_debug "Sourcing: $divinedpl_filepath"

        # Hold your breath...
        source "$divinedpl_filepath"

        # Ensure all assets are copied and main queue is filled, or bail
        d__process_manifests_of_current_dpl || exit 1

        # Get return code of d_dpl_check, or fall back to zero
        if declare -f d_dpl_check &>/dev/null; then
          d_dpl_check; dpl_status=$?
        else
          dpl_status=0
        fi

        # Process return code
        case $dpl_status in
          1)
            if [ "$D_DPL_INSTALLED_BY_USER_OR_OS" = true ]; then
              task_name="$task_name (installed by user or OS)"
              dprint_ode "${D__ODE_NAME[@]}" -c "$MAGENTA" -- \
                '~~~' 'Installed' ':' "$task_desc" "$task_name"
            else
              dprint_ode "${D__ODE_NAME[@]}" -c "$GREEN" -- \
                'vvv' 'Installed' ':' "$task_desc" "$task_name"
            fi
            ;;
          2)
            dprint_ode "${D__ODE_NAME[@]}" -c "$RED" -- \
              'xxx' 'Not installed' ':' "$task_desc" "$task_name"
            ;;
          3)
            dprint_ode "${D__ODE_NAME[@]}" -c "$MAGENTA" -- \
              '~~~' 'Irrelevant' ':' "$task_desc" "$task_name"
            ;;
          4)
            if [ "$D_DPL_INSTALLED_BY_USER_OR_OS" = true ]; then
              task_name="$task_name (partly installed by user or OS)"
            fi
            dprint_ode "${D__ODE_NAME[@]}" -c "$YELLOW" -- \
              'vx-' 'Partly installed' ':' "$task_desc" "$task_name"
            ;;
          *)
            dprint_ode "${D__ODE_NAME[@]}" -c "$BLUE" -- \
              '???' 'Unknown' ':' "$task_desc" "$task_name"
            ;;
        esac

        # Exit subshell properly
        exit 0

      )

      # If subshell exited abnormally, flip the procession flag
      [ $? -ne 0 ] && proceeding=false

    fi

    # Make a final check for whether arrived here without bailing
    if ! $proceeding; then
      dprint_ode "${D__ODE_NAME[@]}" -c "$WHITE" -- \
        '---' 'Skipped' ':' "$task_desc" "$task_name"
    fi

  done
  
  return 0
}

d__perform_check_routine