#!/usr/bin/env bash
#:title:        Divine Bash routine: fmwk-install
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.12.09
#:revremark:    Fix grail path in fmwk install success msg
#:created_at:   2019.10.15

## Part of Divine.dotfiles <https://github.com/divine-dotfiles/divine-dotfiles>
#
## Installs Divine.dotfiles framework and shortcut command.
#

# Marker and dependencies
readonly D__RTN_FMWK_INSTALL=loaded
d__load util workflow

#>  d__rtn_fmwk_install
#
## Performs framework installation routine.
#
## Returns:
#.  0 - Success.
#.  1 - Otherwise.
#
d__rtn_fmwk_install()
{
  # Print a separating empty line, switch context
  printf >&2 '\n'
  d__context -- notch
  d__context -- push "Performing 'fmwk-install' routine"

  # Announce beginning
  if [ "$D__OPT_ANSWER" = false ]; then
    d__announce -s -- "'Installing' Divine.dotfiles"
  else
    d__announce -v -- 'Installing Divine.dotfiles'
  fi

  # Storage & status variables
  local irc=2 iplq ighh idst itmp iaok=true d__bckp ioccbckp
  local idir iadir snm scnm sdir sdst stgt sgd=false erra idrs src dst

  # Perform structured installation
  if d___get_ready; then
    if d___install_fmwk; then d___install_shortcut; irc=0
    else irc=$?; fi
  fi

  # Announce routine completion
  printf >&2 '\n'
  if [ "$D__OPT_ANSWER" = false ]; then
    d__announce -s -- "Finished 'installing' Divine.dotfiles"; return 0
  else case $irc in
    0)  d__announce -v -- 'Successfully installed Divine.dotfiles'
        d___send_pictures; return 0;;
    1)  if [ "$idrs" = o -a -n "$ioccbckp" ]
        then d__pop_backup -dep -- "$idst" "$ioccbckp"; fi
        d__announce -x -- 'Failed to install Divine.dotfiles'; return 1;;
    2)  d__announce -s -- 'Declined to install Divine.dotfiles'; return 2;;
  esac; fi
}

d___get_ready()
{
  # Compose task name; print intro with a separating empty line
  iplq='Pre-flight checks'; printf >&2 '\n%s %s\n' "$D__INTRO_CHK_N" "$iplq"

  # Early exit for dry runs
  if [ "$D__OPT_ANSWER" = false -o "$D__OPT_ANSWER_F" = false ]; then
    printf >&2 '%s %s\n' "$D__INTRO_CHK_S" "$iplq"; return 0
  fi

  # Store remote address
  ighh='divine-dotfiles/divine-dotfiles'

  # Compose destination path
  idst="$D__DIR"

  # Check if destination already exists, and if so, what is it
  if [ -e "$idst" ]; then idrs=o
    if ! [ -d "$idst" ]; then
      d__notify -l! -- 'Framework installation path is occupied by a file:' \
        -i- "$idst"
    else local ilsc
      read -r ilsc <<<"$( ls -Aq1 -- "$idst" 2>/dev/null | wc -l )"
      case $ilsc in
        2)  if [ -d "$idst/grail" -a -d "$idst/state" ]; then idrs=t
              d__notify -l -- 'Framework template with Grail and state' \
                'directories exists at installation path:' -i- "$idst"
            fi;;
        1)  if [ -d "$idst/grail" ]; then idrs=t
              d__notify -l -- 'Framework template with Grail directory' \
                'exists at installation path:' -i- "$idst"
            elif [ -d "$idst/state" ]; then idrs=t
              d__notify -l -- 'Framework template with state directory' \
                'exists at installation path:' -i- "$idst"
            fi;;
        0)  idrs=e; d__notify -l -- 'Empty directory exists at framework' \
              'installation path:' -i- "$idst";;
      esac
      if [ "$idrs" = o ]; then
        d__notify -l! -- 'Non-empty directory exists at framework' \
          'installation path:' -i- "$idst"
      fi
    fi
  fi

  # Continue loading dependencies
  d__load util backup

  # Special processing for occupied paths
  if [ "$idrs" = o ]; then

    # Either early exit or forced install
    if $D__OPT_FORCE; then
      printf >&2 '%s ' "$D__INTRO_CNF_U"
      if ! d__prompt -bp 'Back up & install over?'
      then printf >&2 '%s %s\n' "$D__INTRO_FAILR" "$iplq"; return 1; fi
    else
      d__notify -l! -- 'Re-try with --force to back up & install over'
      printf >&2 '%s %s\n' "$D__INTRO_FAILR" "$iplq"; return 1
    fi

    # Push backup of occupied path
    d__bckp=
    if d__push_backup -- "$idst" "$idst.bak"; then
      ioccbckp="$d__bckp" [ -n "$ioccbckp" ] && d__notify -lv -- \
        'Pre-existing installation path is backed up to:' -i- "$ioccbckp"
    else
      d__notify -lx -- 'Failed to back up pre-existing installation path'
      printf >&2 '%s %s\n' "$D__INTRO_FAILR" "$iplq"; return 1
    fi

  fi

  # Continue loading dependencies
  d__load procedure offer-gh

  # Check if Github interaction method exists
  d__load procedure check-gh
  if [ -z "$D__GH_METHOD" ]; then iaok=false
    d__notify -lx -- 'No way to retrieve framework from Github'
  fi

  # Ensure that the remote repository exists
  d__load util git
  if ! d___gh_repo_exists "$ighh"; then iaok=false
    d__notify -lx -- "Github repository '$ighh' does not appear to exist"
  fi

  # Get on with shortcut-related checks
  d___pfc_shortcut

  # If all good, finish loading dependencies and return; otherwise just return
  if $iaok; then d__load util stash
    printf >&2 '%s %s\n' "$D__INTRO_SUCCS" "$iplq"; return 0
  else
    [ -z "$idrs" ] && rm -rf -- "$idst" &>/dev/null
    printf >&2 '%s %s\n' "$D__INTRO_FAILR" "$iplq"; return 1
  fi
}

d___pfc_shortcut()
{
  # Early exit for dry runs
  if [ "$D__OPT_ANSWER_S" = false ]; then return 0; fi

  # Check that shortcut name is legal
  if ! [[ $D__SHORTCUT_NAME =~ ^[A-Za-z0-9]+$ ]]; then iaok=false
    d__notify -l! -- "Chosen shortcut name '$D__SHORTCUT_NAME'" \
      'is illegal (alphanumerical characters only)'
    return 1
  fi

  # Perform further checks only if all good up until here
  $iaok || return 1

  # If shortcut name is occupied on $PATH, re-prompt until found good one
  if type -P -- "$D__SHORTCUT_NAME" &>/dev/null; then iaok=false
    d__notify -l! -- "Chosen shortcut name '$D__SHORTCUT_NAME'" \
      'already exists on \$PATH'
    if [ "$D__OPT_ANSWER_S" = true ]; then iaok=false; return 1; fi
    while true; do read -r -p "Try another? ('q' to quit) " scnm
      if [ "$scnm" = q ]; then iaok=false; return 1; fi
      if ! [[ $scnm =~ ^[A-Za-z0-9]+$ ]]
      then printf >&2 '%s\n' 'Alphanumerical characters only'; continue; fi
      if type -P -- "$scnm" &>/dev/null
      then printf >&2 '%s\n' 'Already exists on $PATH'; continue; fi
      snm="$scnm"; break
    done
  else snm="$D__SHORTCUT_NAME"; fi

  # Settle on installation directory for the shortcut
  d__notify 'Choosing shortcut installation directory'
  local nwrd=()
  for sdir in "${D__SHORTCUT_DIR_CANDIDATES[@]}"; do
    if ! [[ :$PATH: = *:$sdir:* ]]; then
      d__notify -- "Skipping candidate '$sdir' (not on \$PATH)"
      continue
    fi
    if ! [ -d "$sdir" ]; then
      d__notify -- "Skipping candidate '$sdir' (not a directory)"
      continue
    fi
    if [ -e "$sdir/$snm" ]; then
      d__notify -lx -- ''
      d__notify -- "Skipping candidate '$sdir'" \
        "(file named '$snm' already exists in it)"
      continue
    fi
    if [ -L "$sdir/$snm" ]; then
      iaok=false
      d__notify -lx -- "Dead symlink at: $sdir/$snm" \
        -n- '(Possibly a remnant of previous installation)'
      d__notify -l! -- 'Re-try with --shct-no to install without shortcut'
      return 1
    fi
    if ! [ -w "$sdir" ]; then
      nwrd+=("$sdir")
      d__notify -- "Skipping candidate '$sdir' (not writable)"
      continue
    fi
    sdst="$sdir/$snm"
    d__notify -- "Will install shortcut at '$sdst'"
    break
  done

  # Check if a directory has been chosen
  if [ -n "$sdst" ]; then
    :
  elif ((${#nwrd[@]})) \
    && ( sudo -n true &>/dev/null \
    || d__prompt -p 'Use sudo?' -- 'Candidate directory for shortcut' \
    'installation is not writable without sudo:' -i- "${nwrd[0]}" )
  then
    sdst="${nwrd[0]}/$snm"
  else
    iaok=false
    d__notify -lx -- 'Unable to find a writable installation directory' \
      'for shortcut among candidates'
    d__notify -l! -- 'Re-try with --shct-no to install without shortcut'
  fi
}

d___install_fmwk()
{
  # Print a separating empty line; compose task name
  printf >&2 '\n'; iplq="$BOLD$D__FMWK_NAME$NORMAL framework"

  # Early exit for dry runs
  if [ "$D__OPT_ANSWER_F" = false ]; then
    printf >&2 '%s %s\n' "$D__INTRO_INS_S" "$iplq"
    [ -z "$idrs" ] && rm -rf -- "$idst" &>/dev/null
    return 2
  fi

  # Print intro; print locations
  printf >&2 '%s %s\n' "$D__INTRO_INS_N" "$iplq"
  d__notify -ld -- "Repo URL: https://github.com/$ighh"
  d__notify -ld -- "Location: $idst"

  # Conditionally prompt for user's approval
  if [ "$D__OPT_ANSWER_F" != true ]; then
    printf >&2 '%s ' "$D__INTRO_CNF_N"
    if ! d__prompt -bp 'Install?'; then
      printf >&2 '%s %s\n' "$D__INTRO_INS_S" "$iplq"
      [ -z "$idrs" ] && rm -rf -- "$idst" &>/dev/null
      return 1
    fi
  fi

  # Pull the repository into the temporary directory
  local iopt=( -t 'Divine.dotfiles' )
  [ "$D__FMWK_DEV" = true ] && iopt+=( -b dev )
  itmp="$(mktemp -d)"; case $D__GH_METHOD in
    g)  d___clone_git_repo "${iopt[@]}" -- "$ighh" "$itmp";;
    c)  d___dl_gh_repo -c "${iopt[@]}" -- "$ighh" "$itmp";;
    w)  d___dl_gh_repo -w "${iopt[@]}" -- "$ighh" "$itmp";;
  esac
  if (($?)); then
    printf >&2 '%s %s\n' "$D__INTRO_INS_1" "$iplq"
    rm -rf -- "$itmp"
    [ -z "$idrs" ] && rm -rf -- "$idst" &>/dev/null
    return 1
  fi

  # Move template directory out of the way
  d__bckp=; if ! d__push_backup -- "$idst" "$idst.tmp"; then
    d__notify -lx -- 'Failed to back up template framework directory'
    printf >&2 '%s %s\n' "$D__INTRO_INS_1" "$iplq"
    rm -rf -- "$itmp"
    return 1
  fi

  # Move the retrieved framework into place
  if ! mv -n -- "$itmp" "$idst"; then
    d__notify -lx -- 'Failed to move framework directory into place'
    printf >&2 '%s %s\n' "$D__INTRO_INS_1" "$iplq"
    rm -rf -- "$itmp"
    return 1
  fi

  # Restore grail and state directories; delete template
  erra=() src="$d__bckp/grail" dst="$idst/grail"
  if [ -e "$src" ] && ! mv -n -- "$src" "$dst"
  then erra+=( -i- "- Grail directory" ); fi
  src="$d__bckp/state" dst="$idst/state"
  if  [ -e "$src" ] && ! mv -n -- "$src" "$dst"
  then erra+=( -i- "- state directory" ); fi
  if ((${#erra[@]})); then
    d__notify -lx -- 'Failed to restore template directories' \
      'after installing framework:' "${erra[@]}"
    d__notify l! -- 'Please, move the directories manually from:' \
      -i- "$d__bckp" -n- 'to:' -i- "$idst"
  else rm -rf -- "$d__bckp"; fi

  # Compile list of directories to create; create them, or report error
  erra=() iadir=( \
    "$D__DIR_ASSETS" "$D__DIR_DPLS" "$D__DIR_BACKUPS" \
    "$D__DIR_STASH" "$D__DIR_BUNDLES" "$D__DIR_BUNDLE_BACKUPS" \
  )
  for idir in "${iadir[@]}"; do
    if ! mkdir -p -- "$idir" &>/dev/null; then erra+=( -i- "$idir" ); fi
  done
  if ((${#erra[@]})); then
    d__notify -lx -- 'Failed to create framework directories:' "${erra[@]}"
    return 0
  fi

  # If installed a dev version, set the stash flag
  if [ "$D__FMWK_DEV" = true ]; then
    if d__stash -r -- set 'nightly'; then
      d__notify -- "Recorded 'nightly' flag to root stash"
    else
      d__notify -lx -- "Failed to record 'nightly' flag to root stash"
    fi
  fi

  # Report success
  printf >&2 '%s %s\n' "$D__INTRO_INS_0" "$iplq"
  return 0
}

d___install_shortcut()
{
  # Print a separating empty line; compose task name
  printf >&2 '\n'; iplq="Shortcut command '$BOLD$snm$NORMAL'"

  # Early exit for dry runs
  if [ "$D__OPT_ANSWER_S" = false ]; then
    printf >&2 '%s %s\n' "$D__INTRO_INS_S" 'Shortcut command'; return 2
  fi

  # Compose target; print intro; print locations
  stgt="$D__DIR/intervene.sh"
  printf >&2 '%s %s\n' "$D__INTRO_INS_N" "$iplq"
  d__notify -ld -- "Location: $sdst"
  d__notify -ld -- "Target  : $stgt"
  local ln=ln; d__require_wdir "$sdst" || ln='sudo ln'

  # Install shortcut
  if ! $ln -s -- "$stgt" "$sdst" &>/dev/null; then
    d__notify -lx -- "Failed to create symlink at: '$sdst'"
    printf >&2 '%s %s\n' "$D__INTRO_INS_1" "$iplq"
    return 1
  fi

  # Set stash record
  if d__stash -r -- set di_shortcut "$sdst"; then
    d__notify -- 'Recorded installing shortcut to root stash'
  else
    d__notify -lx -- 'Failed to record installing shortcut to root stash'
  fi

  # Report success
  printf >&2 '%s %s\n' "$D__INTRO_INS_0" "$iplq"
  sgd=true; return 0
}

d___send_pictures()
{
  # Wait a bit
  sleep 2

  # Print empty line for visual separation; compose main command for output
  printf >&2 '\n'; local mcmd
  if $sgd; then mcmd="$snm"
  else mcmd="$D__DIR/intervene.sh"; fi

  # Print plaque
  cat <<EOF
${REVERSE}- ${BOLD}D i v i n e . d o t f i l e s${NORMAL}${REVERSE} -${NORMAL}
     ${GREEN}${REVERSE}${BOLD} i n s t a l l e d ${NORMAL}
             ${GREEN}${REVERSE}-_-${NORMAL}

Have you heard the good news?
You can now access ${BOLD}Divine.dotfiles${NORMAL} in shell using:
    $ $BOLD$mcmd$NORMAL

For help, try:
    ${BOLD}https://github.com/divine-dotfiles/divine-dotfiles${NORMAL}
    ...or $BOLD$D__DIR/README.adoc$NORMAL
    ...or $ $BOLD$mcmd --help$NORMAL

Your personal deployments and assets go into Grail directory at:
    $BOLD~/.grail$NORMAL
(It is a good idea to take your Grail under version control)

For a joy ride, try our bundled Divine deployments using:
    $ $BOLD$mcmd attach essentials$NORMAL && $BOLD$mcmd install$NORMAL
(More info on these at: https://github.com/divine-bundles/essentials)
    
Thank you, and have a safe and productive day.
EOF

  # Return success
  return 0
}

d__rtn_fmwk_install