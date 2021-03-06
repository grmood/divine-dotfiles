#!/usr/bin/env bash
#:title:        Divine Bash routine: attach
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.12.08
#:revremark:    Restore forgotten assets util dep to attach rtn
#:created_at:   2019.05.12

## Part of Divine.dotfiles <https://github.com/divine-dotfiles/divine-dotfiles>
#
## This file is intended to be sourced from framework's main script.
#
## Attaches bundles of deployments by either cloning or downloading Github 
#. repositories.
#

# Marker and dependencies
readonly D__RTN_ATTACH=loaded
d__load procedure prep-stash
d__load procedure offer-gh
d__load procedure check-gh
d__load procedure sync-bundles
d__load util workflow
d__load util stash
d__load util git
d__load util scan
d__load util assets
d__load util transitions

#>  d__rtn_attach
#
## Performs attach routine.
#
## Returns:
#.  0 - All bundles attached.
#.  0 - (script exit) Zero bundle names given.
#.  1 - (script exit) No way to retrieve Github repositories.
#.  1 - At least one given bundle was not attached.
#
d__rtn_attach()
{
  # Check if any tasks were found
  if [ ${#D__REQ_ARGS[@]} -eq 0 ]; then
    d__notify -lst 'Nothing to do' -- 'Not a single bundle name given'
    exit 0
  fi

  # Ensure that there is a method for Github retrieval
  if [ -z "$D__GH_METHOD" ]; then
    d__notify -lxt 'Unable to attach' -- 'Current system does not have' \
      'the tools to retrieve Github repositories'
    exit 1
  fi

  # Survey currently present deployments and Divinefiles
  if ! [ "$D__OPT_ANSWER" = false ]; then
    D__INT_DF_COUNT=0 D__INT_PKG_COUNT=0 D__INT_DPL_COUNT=0
    D__EXT_DF_COUNT=0 D__EXT_PKG_COUNT=0 D__EXT_DPL_COUNT=0
    D__INT_DPL_NAMES=() D__INT_DPL_NAME_PATHS=()
    D__EXT_DPL_NAMES=() D__EXT_DPL_NAME_PATHS=()
    if ! d__scan_for_divinefiles --internal "$D__DIR_DPLS" "$D__DIR_BUNDLES" \
      || ! d__scan_for_dpl_files --internal "$D__DIR_DPLS" "$D__DIR_BUNDLES"
    then
      d__notify -lxt 'Unable to attach' -- \
        'Illegal state of deployment directories detected'
      exit 1
    fi
  fi

  # Print a separating empty line, switch context
  printf >&2 '\n'
  d__context -- notch
  d__context -- push "Performing 'attach' routine"

  # Announce beginning
  if [ "$D__OPT_ANSWER" = false ]; then
    d__announce -s -- "'Attaching' bundles"
  else
    d__announce -v -- 'Attaching bundles'
  fi

  # Storage & status variables
  local barg bdst bplq btmp bany=false ball=true bss bpcs bdcs ii dpln dplp

  # Iterate over script arguments
  for barg in "${D__REQ_ARGS[@]}"
  do d___attach_bundle && bany=true || ball=false; done

  # Process all asset manifests again
  d__load procedure process-all-assets

  # Announce routine completion
  printf >&2 '\n'
  if [ "$D__OPT_ANSWER" = false ]
  then d__announce -s -- "Finished 'attaching' bundles"; return 0
  elif $bany; then
    if $ball; then
      d__announce -v -- 'Successfully attached bundles'; return 0
    else
      d__announce -! -- 'Partly attached bundles'; return 1
    fi
  else
    d__announce -x -- 'Failed to attach bundles'; return 1
  fi
}

#>  d___attach_bundle
#
## INTERNAL USE ONLY
#
d___attach_bundle()
{
  # Print a separating empty line; compose task name
  printf >&2 '\n'; bplq="Bundle '$BOLD$barg$NORMAL'"

  # Early exit for dry runs
  if [ "$D__OPT_ANSWER" = false ]; then
    printf >&2 '%s %s\n' "$D__INTRO_ATC_S" "$bplq"; return 1
  fi

  # Print intro
  printf >&2 '%s %s\n' "$D__INTRO_ATC_N" "$bplq"

  # Accept one of two patterns: 'builtin_repo_name' and 'username/repo'
  if [[ $barg =~ ^[0-9A-Za-z_.-]+$ ]]
  then barg="divine-bundles/$barg"
  elif [[ $barg =~ ^[0-9A-Za-z_.-]+/[0-9A-Za-z_.-]+$ ]]; then :
  else
    d__notify -lx -- "Invalid bundle identifier '$barg'"
    printf >&2 '%s %s\n' "$D__INTRO_ATC_2" "$bplq"; return 1
  fi

  # Ensure that the remote repository exists
  if ! d___gh_repo_exists "$barg"; then
    d__notify -lx -- "Github repository '$barg' does not appear to exist"
    printf >&2 '%s %s\n' "$D__INTRO_ATC_2" "$bplq"; return 1
  fi

  # Compose destination path; print location
  bdst="$D__DIR_BUNDLES/$barg"
  d__notify -ld -- "Repo URL: https://github.com/$barg"
  d__notify -ld -- "Location: $bdst"

  # Check if destination already exists
  if [ -e "$bdst" ]; then
    d__notify -ls -- "Bundle '$barg' appears to be already attached"
    printf >&2 '%s %s\n' "$D__INTRO_ATC_S" "$bplq"; return 1
  fi

  # Conditionally prompt for user's approval
  if [ "$D__OPT_ANSWER" != true ]; then
    printf >&2 '%s ' "$D__INTRO_CNF_N"
    if ! d__prompt -b
    then printf >&2 '%s %s\n' "$D__INTRO_ATC_S" "$bplq"; return 1; fi
  fi

  # Pull the repository into the temporary directory
  btmp="$(mktemp -d)"; case $D__GH_METHOD in
    g)  d___clone_git_repo "$barg" "$btmp";;
    c)  d___dl_gh_repo -c "$barg" "$btmp";;
    w)  d___dl_gh_repo -w "$barg" "$btmp";;
  esac
  if (($?)); then
    printf >&2 '%s %s\n' "$D__INTRO_ATC_1" "$bplq"
    rm -rf -- "$btmp"; return 1
  fi

  # Validate deployments within the bundle
  if ! d__scan_for_divinefiles --external "$btmp" \
    || ! d__scan_for_dpl_files --external "$btmp"
  then
    d__notify -lx -- "Content of bundle '$barg' is in illegal state"
    printf >&2 '%s %s\n' "$D__INTRO_ATC_2" "$bplq"
    rm -rf -- "$btmp"; return 1
  fi

  # Ensure there is a non-zero amount of deployments in the bundle
  if [ $D__EXT_DF_COUNT -eq 0 -a $D__EXT_DPL_COUNT -eq 0 ]; then
    d__notify -lx -- "Repository '$barg' appears to contain no deployments"
    printf >&2 '%s %s\n' "$D__INTRO_ATC_2" "$bplq"
    rm -rf -- "$btmp"; return 1
  fi

  # Compose success string
  bpcs="$D__EXT_DF_COUNT Divinefile"; [ $D__EXT_DF_COUNT -eq 1 ] || bpcs+='s'
  bdcs="$D__EXT_DPL_COUNT deployment"; [ $D__EXT_DPL_COUNT -eq 1 ] || bdcs+='s'
  bss="Attached $bpcs and $bdcs"

  # Cross-validate with internal deployments
  if ! d__cross_validate_dpls; then
    d__notify -lx -- "Bundle '$barg' appears to contain deployments" \
      'with colliding names'
    printf >&2 '%s %s\n' "$D__INTRO_ATC_2" "$bplq"
    rm -rf -- "$btmp"; return 1
  fi

  # Ensure existence of parent directory
  if ! mkdir -p -- "$( dirname -- "$bdst" )"; then
    d__notify -lx -- "Failed to create parent directory for bundle '$barg'"
    printf >&2 '%s %s\n' "$D__INTRO_ATC_1" "$bplq"
    rm -rf -- "$btmp"; return 1
  fi

  # Move the retrieved bundle into place
  if ! mv -n -- "$btmp" "$bdst"; then
    d__notify -lx -- "Failed to move bundle '$barg' into place"
    printf >&2 '%s %s\n' "$D__INTRO_ATC_1" "$bplq"
    rm -rf -- "$btmp"; return 1
  fi

  # Process assets
  for ((ii=0;ii<${#D__EXT_DPL_NAMES[@]};++ii)); do
    dpln="${D__EXT_DPL_NAMES[$ii]}"
    dplp="$bdst/${D__EXT_DPL_NAME_PATHS[$ii]}"
    D__DPL_MNF_PATH="${dplp%$D__SUFFIX_DPL_SH}$D__SUFFIX_DPL_MNF"
    D__DPL_DIR="$( dirname -- "$dplp" )"
    D__DPL_ASSET_DIR="$D__DIR_ASSETS/$dpln"
    d__process_asset_manifest_of_current_dpl
  done

  # Merge records; report success
  d__merge_ext_into_int "$bdst"; d__notify -lv -- "$bss"

  # Set up variables for transitions, then apply transitions
  local bshf="$bdst/$D__CONST_NAME_BUNDLE_SH" brtc
  local udst="$bdst" ovrs nvrs invl untv="$bdst/$D__CONST_NAME_UNTRS"

  # Extract now-current version of attached bundle
  if [ -f "$bshf" ]; then
    while read -r invl || [[ -n "$invl" ]]; do
      [[ $invl = 'D_BUNDLE_VERSION='* ]] || continue
      IFS='=' read -r invl nvrs <<<"$invl "
      if [[ $nvrs = \'*\'\  || $nvrs = \"*\"\  ]]
      then read -r nvrs <<<"${nvrs:1:${#nvrs}-3}"
      else read -r nvrs <<<"$nvrs"; fi
      break
    done <"$bshf"
  fi

  # Initiate transitions
  d___apply_transitions

  # Set stash record
  if  d__stash -gs -- add attached_bundles "$barg"; then
    d__notify -- "Recorded attaching '$barg' bundle to Grail stash"
  else
    d__notify -lx -- "Failed to record attaching '$utl' bundle" \
      'to Grail stash'
  fi
  printf >&2 '%s %s\n' "$D__INTRO_ATC_0" "$bplq"
  return 0
}

d__rtn_attach