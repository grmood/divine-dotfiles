#!/usr/bin/env bash
#:title:        Divine Bash routine: usage
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    12
#:revdate:      2019.09.01
#:revremark:    Make usage note narrower
#:created_at:   2018.03.25

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## This file is intended to be sourced from framework's main script
#
## Shows usage note and exits the script
#

#>  d__show_usage_and_exit
#
## Shows usage tip end exits with code 1
#
## Parameters:
#.  *none*
#
## Returns:
#.  1 - (script exit) Always
#
## Prints:
#.  stdout: *nothing*
#.  stderr: Usage tip
#
d__show_usage_and_exit()
{
  # Add bolding if available
  local bold normal
  if which tput &>/dev/null; then bold=$(tput bold); normal=$(tput sgr0); fi

  local usage_tip
  read -r -d '' usage_tip << EOF
${bold}$D__FMWK_NAME usage${normal}:
Check status of dpls:   $ ${bold}${D__EXEC_NAME}${normal} ${bold}c${normal}|${bold}check${normal}   [-ynqvew]  [-b BUNDLE]... [TASK]...
Install dpls:           $ ${bold}${D__EXEC_NAME}${normal} ${bold}i${normal}|${bold}install${normal} [-ynqvewf] [-b BUNDLE]... [TASK]...
Uninstall dpls:         $ ${bold}${D__EXEC_NAME}${normal} ${bold}r${normal}|${bold}remove${normal}  [-ynqvewf] [-b BUNDLE]... [TASK]...

Attach bundles:         $ ${bold}${D__EXEC_NAME}${normal} ${bold}a${normal}|${bold}attach${normal}  [-yn]                     REPO...
Detach bundles:         $ ${bold}${D__EXEC_NAME}${normal} ${bold}d${normal}|${bold}detach${normal}  [-yn]                     REPO...
Plug Grail:             $ ${bold}${D__EXEC_NAME}${normal} ${bold}p${normal}|${bold}plug${normal}    [-ynl]                    REPO/DIR...
Update fmwk/dpls/Grail: $ ${bold}${D__EXEC_NAME}${normal} ${bold}u${normal}|${bold}update${normal}  [-yn]                     [TASK]...

Show framework version: $ ${bold}${D__EXEC_NAME}${normal} --version
Show help summary:      $ ${bold}${D__EXEC_NAME}${normal} -h|--help
EOF

  # Print usage tip
  printf >&2 '%s\n' "$usage_tip"
  exit 1
}

d__show_usage_and_exit