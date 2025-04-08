#!/bin/bash

# An array of strings to decorate your prompt.  An element from this array will
# be prepended to each section of the prompt in order.  There are 5 sections in
# the prompt.
#
# You can set this array in your shell startup files after sourcing this file.
#
# The most likely use of this is probably emojis.  For example
# `_powerline_decorations=(🍊 🐰 "🐕 " "🐻 " 🎉 🦆)`.  Depending on the ones you
# use you might want to include a space before or after it.
_powerline_decorations=()

_powerline_decoration(){
    echo "${_powerline_decorations[$deco_index]}"
}

_powerline_setup_main(){
    if ! source ~/.git-prompt.sh ; then
        echo "${BASH_SOURCE[0]} expects ~/.git-prompt.sh to exist.  It can be obtained at 'https://github.com/git/git/blob/master/contrib/completion/git-prompt.sh'.  Ideally the one corresponding to your version of git but I always just get the one from 'master' (this link).  There is always a chance that a new one will use git commands that your version of git does not have."
        return 1
    fi
    # Turn off options these options of GIT_PS1 because we display them ourselves
    GIT_PS1_SHOWUNTRACKEDFILES=
    GIT_PS1_SHOWDIRTYSTATE=

    # These options could be left to the user.  However nothing is stopping them
    # from setting them after having sourced this file.
    GIT_PS1_SHOWUPSTREAM=verbose
    GIT_PS1_SHOWCONFLICTSTATE=1

    # The separator's foreground is made to match the background of the section
    # to its left and it's background is made to match the section to its right
    # A ''
    __powerline_separator="" #\ue0b0"

    # A ''
    __powerline_separator_same_color="\ue0b1"


    # An array of colors to use for various parts of the prompt.  Use
    # bash_powerline_theme.grayscale or the function
    # _powerline_set_prompt_colors_default as an example to create your own themes.
    # See https://en.wikipedia.org/wiki/ANSI_escape_code#8-bit
    declare -gA _powerline_prompt_colors
    _powerline_set_prompt_colors_default
    if [[ -f ~/.bash_powerline_theme ]] ; then
        source ~/.bash_powerline_theme
    fi

    # Some people use git to track their dotfiles by makint their HOME directory
    # into a git repo.  People's homes will usually contain many directories that
    # are inaccessible to other users thus showing a bunch of `permission denied`
    # Plus from the HOME, running git status is very long because it has to check
    # a lot of files.
    declare -ga _powerline_repos_to_ignore
    if [[ -e ~/.config/powerline_repos_to_ignore.txt ]] ; then
        local line
        while read repo ; do
            if [[ "${repo}" == '#'* ]] ; then
                continue
            fi
            local repo_true_path
            if ! repo_true_path="$(command cd -P ${repo} && pwd)" ; then
                echo "${FUNCNAME[0]}(): WARNING: Could not get true path of repo '${repo}'" >&2
            fi
            _powerline_repos_to_ignore+=("${repo_true_path}")
        done < ~/.config/powerline_repos_to_ignore.txt
    fi

    PS2="\[\033[1;105m\]>\[\033[35;49m\]\[\033[0m\]"

    _powerline_add_to_prompt_command
}

#
# Add to PROMPT_COMMAND in a way that fits the BASH version.  In BASH 5, the
# variable PROMPT_COMMAND may be an array in which case bash will execute
# each command one after the other.  This is nice because we can use x+=(y)
# to add to PROMPT_COMMAND in a nice way.
_powerline_add_to_prompt_command(){
    if (( BASH_VERSINFO[0] > 4 )) ; then
        PROMPT_COMMAND=(_powerline_set_ps1 "${PROMPT_COMMAND[@]}")
    else
        PROMPT_COMMAND="_powerline_set_ps1${PROMPT_COMMAND:+ ; ${PROMPT_COMMAND}}"
    fi
}


_powerline_ignore_repo(){
    for r in "${_powerline_repos_to_ignore[@]}" ; do
        if [[ "$(command cd -P ${r} && pwd)" == "${repo_dir}" ]] ; then
            return 0
        fi
    done
    return 1
}


_powerline_nb_untracked_files(){
    local IFS=$'\n'
    local untracked=($(command git ls-files ${repo_dir} --others --exclude-standard --directory --no-empty-directory))
    local files=0
    local dirs=0
    for f in "${untracked[@]}" ; do
        case $f in
            */) ((dirs++)) || : ;;
            *) ((files++)) || : ;;
        esac
    done
    if [[ "${files}" != 0 ]] || [[ "${dirs}" != 0 ]] ; then
        printf "%s" "%%(${files}f,${dirs}d)"
    fi
}

#
# For when you want to demonstrate something by running some commands
# and copy-pasting into an email or chat service:
#
# Make the prompt minimal and copy-paste friendly:
#
powerline_demo_mode(){
    if [[ -z "${_powerline_demo_mode}" ]] ; then
        _powerline_demo_mode="ON"
        __original_ps2="${PS2}"
        PS2=" > "
    else
        _powerline_demo_mode=""
        PS2="${__original_ps2}"
    fi
}

_powerline_number_to_background_code(){
    if [[ -n ${1} ]] ; then
        echo "48;5;${1}"
    else
        echo "49" # Reset just the background
    fi
}

_powerline_number_to_foreground_code(){
    if [[ -n ${1} ]] ; then
        echo "38;5;${1}"
    else
        echo "39" # Reset just the foreground
    fi
}

#
# Draws a prompt segment without the triangle.  When drawing the prompt,
# calle this function to draw
#
_powerline_prompt_section(){
    local content=$1
    local bg_section=$2
    local fg_section=$3

    local fg_code=$(_powerline_number_to_foreground_code ${fg_section})
    local bg_code=$(_powerline_number_to_background_code ${bg_section})

    # Print the section's content

    printf "\[\033[${bg_code}m\033[${fg_code}m\]%s" "$(_powerline_decoration)${content}"
    ((deco_index++))
}

# Print a triangle transitioning between the color of the left (previous) section
# and the color of the right (next) section.
# When both colors are the same, just pu
_powerline_prompt_triangle(){
    local bg_left=$1
    local bg_right=$2
    local bg_code=$(_powerline_number_to_background_code ${bg_right})
    if [[ "${bg_left}" == "${bg_right}" ]] ; then
        local fg_code=$(_powerline_number_to_foreground_code 240)
        printf "\[\033[0m\033[${bg_code}m\033[${fg_code}m\]${__powerline_separator_same_color}\[\033[0m\]"
    else
        local fg_code=$(_powerline_number_to_foreground_code ${bg_left})
        printf "\[\033[0m\033[${fg_code}m\033[${bg_code}m\]${__powerline_separator}\[\033[0m\]"
    fi
}

_powerline_git_pwd() {
    #local repo_dir=$(command git rev-parse --show-toplevel 2>/dev/null)
    local outer=${repo_dir##*/}
    local inner=$(command git rev-parse --show-prefix 2>/dev/null)
    if ! [[ -w ${repo_dir} ]] ; then
        owner=$(stat --format=%U $(command cd -P $PWD && pwd))
        printf "(${owner})"
        # Don't know which I like more.  Leaving this here to maybe try later
        # local container=${repo_dir%%/${outer}}
        # printf "${container}/"
    fi
    printf "\[\033[1;4m\]${outer}\[\033[22;24m\]${inner:+/${inner}}"
}

_powerline_git_info(){
    if ! info=($(command git rev-parse --show-toplevel --show-superproject-working-tree 2>/dev/null)) ; then
        return 1
    fi
    repo_dir=${info[0]}
    git_superproject=${info[1]}
    if ! git_branch=$(command git symbolic-ref HEAD 2>/dev/null) ; then
        git_headless=true
        git_detached_branch=$(_powerline_get_git_detached_branch)
    fi
}

_powerline_set_prompt_colors_default(){
    _powerline_prompt_colors[conda_env_bg]=21
    _powerline_prompt_colors[conda_env_fg]=
    _powerline_prompt_colors[host_bg]=27
    _powerline_prompt_colors[host_fg]=
    if [[ -n ${PBS_JOBID} ]] ; then
        _powerline_prompt_colors[host_bg]=52 #90
        _powerline_prompt_colors[jobid]=88 #127
    fi
    _powerline_prompt_colors[user]=33
    _powerline_prompt_colors[dir]=74
    _powerline_prompt_colors[dir_fg]=15
    _powerline_prompt_colors[git_headless]=88
    _powerline_prompt_colors[git_headless_fg]=0
    _powerline_prompt_colors[git_dirty]=184
    _powerline_prompt_colors[git_dirty_fg]=0
    _powerline_prompt_colors[git_clean]=2
    _powerline_prompt_colors[git_clean_fg]=0
    _powerline_prompt_colors[git_ignored_repo_fg]=0
    _powerline_prompt_colors[git_ignored_repo]=2
    _powerline_prompt_colors[exit_code_success]=34
    _powerline_prompt_colors[exit_code_failure]=9
    _powerline_prompt_colors[next_line]=27
    _powerline_prompt_colors[git_unstaged_stats]=1
    _powerline_prompt_colors[git_staged_stats]=2
    _powerline_prompt_colors[git_untracked_stats]=1
    _powerline_prompt_colors[git_headless_untracked_stats]='7;1'
    _powerline_prompt_colors[git_headless_staged_stats]=15
    _powerline_prompt_colors[git_headless_unstaged_stats]=7
}

_powerline_generate_prompt(){
    local previous_exit_code=${1}
    local deco_index=0

    #
    # Exit code section, followed by host section
    # followed by maybe conda environment or host
    #

    local c_exit_code
    local c_exit_code_fg
    if [[ ${previous_exit_code} == 0 ]] ; then
        c_exit_code="${_powerline_prompt_colors[exit_code_success]}"
        c_exit_code_fg="${_powerline_prompt_colors[exit_code_success_fg]}"
    else
        c_exit_code="${_powerline_prompt_colors[exit_code_failure]}"
        c_exit_code_fg="${_powerline_prompt_colors[exit_code_failure_fg]}"
    fi
    _powerline_prompt_section " ${previous_exit_code} " "${c_exit_code}" "${c_exit_code_fg}"

    if [[ -n ${CONDA_ENV} ]]; then
        _powerline_prompt_triangle "${c_exit_code}" "${_powerline_prompt_colors[conda_env_bg]}"
        _powerline_prompt_section "${CONDA_ENV}" "${_powerline_prompt_colors[conda_env_bg]}" "${_powerline_prompt_colors[conda_env_fg]}"
        _powerline_prompt_triangle "${_powerline_prompt_colors[conda_env_bg]}" "${_powerline_prompt_colors[host_bg]}"
    else
        _powerline_prompt_triangle "${c_exit_code}" "${_powerline_prompt_colors[host_bg]}"
    fi

    #
    # Host section followed by user section
    #
    _powerline_prompt_section "\\h" "${_powerline_prompt_colors[host_bg]}" "${_powerline_prompt_colors[host_fg]}"
    if [[ -n ${PBS_JOBID} ]] ; then
        _powerline_prompt_triangle "${_powerline_prompt_colors[host_bg]}" "${_powerline_prompt_colors[jobid]}"
        _powerline_prompt_section "${PBS_JOBID}" "${_powerline_prompt_colors[jobid]}"

        _powerline_prompt_triangle "${_powerline_prompt_colors[jobid]}" "${_powerline_prompt_colors[user]}"
    else
        _powerline_prompt_triangle "${_powerline_prompt_colors[host_bg]}" "${_powerline_prompt_colors[user]}"
    fi

    #
    # User section followed by directory and git section
    #
    _powerline_prompt_section "\\u" "${_powerline_prompt_colors[user]}"
    _powerline_prompt_triangle "${_powerline_prompt_colors[user]}" "${_powerline_prompt_colors[dir]}"


    local repo_dir
    local git_superproject
    local git_branch
    local git_headless
    local git_detached_branch
    # Note: _powerline_ignore_repo looks at repo_dir which is set by
    # _powerline_git_info so the order is important in the && below:
    if _powerline_git_info ; then
        if _powerline_ignore_repo ; then
            #
            # Directory section followed by marker for ignored git repo
            #
            # _powerline_prompt_section "\\w" "${_powerline_prompt_colors[dir]}" "${_powerline_prompt_colors[dir_fg]}"
            _powerline_prompt_section "\w" "${_powerline_prompt_colors[dir]}" "${_powerline_prompt_colors[dir_fg]}"
            _powerline_prompt_triangle "${_powerline_prompt_colors[dir]}" "${_powerline_prompt_colors[git_ignored_repo]}"

            #
            # Marker for ignored git repo followed by nothing
            #
            _powerline_prompt_section "\033[1m g!\033[21m" "${_powerline_prompt_colors[git_ignored_repo]}" "${_powerline_prompt_colors[git_ignored_repo_fg]}"
            _powerline_prompt_triangle "${_powerline_prompt_colors[git_ignored_repo]}" ""
        else
            local git_part
            _powerline_set_git_part

            #
            # Directory section followed by git section
            #
            if ! [[ -d "$(pwd)" ]] ; then
                _powerline_prompt_section "(DELETED_DIR)" "${_powerline_prompt_colors[dir]}" "${_powerline_prompt_colors[dir_fg]}"
            else
                _powerline_prompt_section "$(_powerline_git_pwd)" "${_powerline_prompt_colors[dir]}" "${_powerline_prompt_colors[dir_fg]}"
            fi
            _powerline_prompt_triangle "${_powerline_prompt_colors[dir]}" "${git_color}"

            #
            # Git section followed by nothing
            #
            _powerline_prompt_section "${git_part}" "${git_color}" "${git_color_fg}"
            _powerline_prompt_triangle "${git_color}" ""
        fi
    else
        #
        # Directory section followed by nothing
        #
        if ! [[ -d "$(pwd)" ]] ; then
            _powerline_prompt_section "(DELETED_DIR)" "${_powerline_prompt_colors[dir]}" "${_powerline_prompt_colors[dir_fg]}"
        else
            _powerline_prompt_section "\\w" "${_powerline_prompt_colors[dir]}" "${_powerline_prompt_colors[dir_fg]}"
        fi
        _powerline_prompt_triangle "${_powerline_prompt_colors[dir]}" ""

        # If we were in a git repo, we would advance the decoration index by 1
        # when drawing the git section.  Here we increment it by 1 so that the
        # next section gets the same decoration whether we are in a git repo or
        # not.
        ((deco_index++))
    fi

    printf "%s" "\n"
    _powerline_prompt_section "$" "${_powerline_prompt_colors[next_line]}" 15
    _powerline_prompt_triangle "${_powerline_prompt_colors[next_line]}" ""
}

_powerline_set_git_part(){
    local git_extra=""
    local c_untracked_stats
    local c_staged_stats
    local c_unstaged_stats
    local diff_stats staged_stats unstaged_stats
    diff_stats=($(_powerline_git_aggr_numstat))
    local clean=$?
    if [[ ${diff_stats[0]} == "_" ]] ; then
        unstaged_stats=""
    else
        unstaged_stats=${diff_stats[0]}
    fi
    if [[ ${diff_stats[1]} == "_" ]] ; then
        staged_stats=""
    else
        staged_stats=${diff_stats[1]}
    fi

    if [[ "${git_headless}" == true ]] ; then
        git_color="${_powerline_prompt_colors[git_headless]}"
        git_color_fg="${_powerline_prompt_colors[git_headless_fg]}"
        git_extra="${git_detached_branch}"
        if [[ -n ${git_extra} ]] ; then
            git_extra=" [${git_extra}]"
        fi
        # Override colors in headless state
        # TODO: Add keys git_untracked_stats_headless, git_staged_stats_headless, git_unstaged_stats_headless
        c_untracked_stats=${_powerline_prompt_colors[git_headless_untracked_stats]}
        c_staged_stats=${_powerline_prompt_colors[git_headless_staged_stats]}
        c_unstaged_stats=${_powerline_prompt_colors[git_headless_unstaged_stats]}
    else
        c_untracked_stats=${_powerline_prompt_colors[git_untracked_stats]}
        c_staged_stats=${_powerline_prompt_colors[git_staged_stats]}
        c_unstaged_stats=${_powerline_prompt_colors[git_unstaged_stats]}

        if [[ ${clean} == 0 ]] ; then
            git_color="${_powerline_prompt_colors[git_clean]}"
            git_color_fg="${_powerline_prompt_colors[git_clean_fg]}"
        else
            git_color="${_powerline_prompt_colors[git_dirty]}"
            git_color_fg="${_powerline_prompt_colors[git_dirty_fg]}"
        fi
    fi


    # git_extra="${git_extra} $(git_time_since_last_commit)"
    local untracked_stats="$(_powerline_nb_untracked_files)"
    if [[ -n ${diff_stats} ]] || [[ -n ${untracked_stats} ]] ; then
        git_extra+="|"
        git_extra+="\[\033[38;5;${c_staged_stats}m\]${staged_stats}\[\033[38;5;${c_unstaged_stats}m\]${unstaged_stats}"
        git_extra+="\[\033[1;38;5;${c_untracked_stats}m\]${untracked_stats}\[\033[22;39m\]"
    fi


    # Use single-argument form of __git_ps1 to get the text of the
    # git part of the prompt.
    if [[ "${git_superproject}" != "" ]] ; then
        git_part="$(__git_ps1 "%s${git_extra} \[\033[1;4m\]SM\[\033[21;24m\] " || :)"
    else
        git_part="$(__git_ps1 "%s${git_extra}" || :)"
    fi
}

_powerline_set_git_part_lite(){
    git_part="$(__git_ps1)"
    if [[ "${git_headless}" == true ]] ; then
        git_color="${_powerline_prompt_colors[git_headless]}"
        git_color_fg="${_powerline_prompt_colors[git_headless_fg]}"
        git_extra="${git_detached_branch}"
        if [[ -n ${git_extra} ]] ; then
            git_extra=" [${git_extra}]"
        fi
        # Override colors in headless state
        c_untracked_stats='7'
        c_staged_stats='15'
        c_unstaged_stats='7'
    elif [[ "${git_part}" != *'*'* ]] && [[ "${git_part}" != *+* ]] ; then
        git_color="${_powerline_prompt_colors[git_clean]}"
        git_color_fg="${_powerline_prompt_colors[git_clean_fg]}"
        c_untracked_stats='15'
        # git_extra+="\[\033[1;38;5;${_powerline_prompt_colors[untracked_stats]}m\] $(_powerline_nb_untracked_files)\[\033[22;39m\]"
    else
        git_color="${_powerline_prompt_colors[git_dirty]}"
        git_color_fg="${_powerline_prompt_colors[git_dirty_fg]}"
    fi
}

powerline_lite_mode(){
    GIT_PS1_SHOWDIRTYSTATE=1
    _powerline_set_git_part(){
        _powerline_set_git_part_lite
    }
}

#
# Function to be set as PROMPT_COMMAND.  It sets PS1 with the output of
# _powerline_generate_prompt.
#
_powerline_set_ps1(){
    local previous_exit_code=$?

    local user_had_xtrace
    if shopt -op xtrace >/dev/null; then
        user_had_xtrace=true
        if [[ -z "${BASH_POWERLINE_XTRACE}" ]] ; then
            printf "Disabling xtrace during prompt evaluation\n"
            set +o xtrace
        else
            user_had_xtrace=false
        fi
    fi

    _powerline_deal_with_vscode

    _powerline_check_prompt_command

    if [[ -n "${_powerline_demo_mode}" ]] ; then
        PS1="=> ${previous_exit_code}\n\n $ "
    else
        PS1="$(_powerline_generate_prompt ${previous_exit_code}) "
    fi

    if [[ "${user_had_xtrace}" == true ]] ; then
        if [[ -z "${BASH_POWERLINE_XTRACE}" ]] ; then
            printf "Reenabling xtrace after prompt evaluation\n"
            set -x
        fi
    fi
}

_powerline_check_prompt_command(){
    local first
    if [[ ${PROMPT_COMMAND@a} == *a* ]] ; then
        first=${PROMPT_COMMAND[0]}
    else
        first=${PROMPT_COMMAND}
    fi

    local warning="\033[1;33mWARNING\033[0m: ${FUNCNAME[0]} is not the first item in PROMPT_COMMAND: displayed previous command exit code may be wrong\n"
    if [[ -n ${__vsc_status:-} ]] ; then
        # We are in vscode integrated shell, we need VSCode's function
        # __vsc_promtp_cmd_original to be first in PROMPT_COMMAND because it uses
        # $? to grab the exit code.  The rest doesn't matter because VSCode will
        # have stored it in __vsc_status which we can look at any time.
        if [[ "${first}" != __vsc_prompt_cmd_original ]] ; then
            printf "\033[1;33mWARNING\033[0m: ${FUNCNAME[0]}:  We are in VSCode integrated terminal yet the first element of PROMPT_COMMAND is not __vsc_prompt_cmd_original.  The displayed previous command exit code will most likely be wrong\n"
        fi
    else
        if [[ "${first}" != _powerline_set_ps1* ]] ; then
            printf "\033[1;33mWARNING\033[0m: ${FUNCNAME[0]} is not the first item in PROMPT_COMMAND: displayed previous command exit code may be wrong\n"
        fi
    fi
}

###############################################################################
#
# VSCode launches integrated terminals with
#
#   /usr/bin/bash --init-file .../vscode-server/.../shellIntegration-bash.sh
#
# which
# - loads either the ~/.bashrc or one of ~/.bash_profile, ~/.bash_login, ~/.profile
#   based on VSCODE_SHELL_LOGIN (instead of passing -l to the command becasue it is
#   incompatible with --init-file)
# - Does something like 'PROMPT_COMMAND="<vscode stuff>; $PROMPT_COMMAND" so
#   that between the end of the previous command and the time *my* PROMPT_COMMAND
#   gets run, <vscode stuff> will have run.  At that point, the value of
#   $? no longer represents the status of the last command that the *user* ran.
# - VSCode inserts its stuff where $? does represent the exit status of the last
#   command.  It stores it in __vsc_status.
#
# If __vsc_status is non-empty, then we are a VSCode integrated shell and we
# should use __vsc_status as the exit code of the previous command.
################################################################################
_powerline_deal_with_vscode(){
    if [[ -n ${__vsc_status-} ]] ; then
        previous_exit_code=${__vsc_status}
    fi
}

# In detached head, it may be useful to know that we are on a commit that is
# pointed to by a remote branch.
#
# This function lists the remote branches that are pointing on HEAD and echos
# the list of these branches joined by a space.
_powerline_get_git_detached_branch(){
    local branches=($(command git branch --points-at HEAD --format='%(refname:short)' | command grep -v '^(HEAD\|^(no') $(command git branch -r --points-at HEAD --format='%(refname:short)'))
    local nb=${#branches[@]}
    local IFS=","
    case ${nb} in
        0) echo "" ;;
        1) echo "${branches[0]}" ;;
        2|3) echo "${branches[*]}" ;;
        *) echo "${branches[0]},($((nb-1)) more ...)" ;;
    esac
}

git_time_since_last_commit() {
    # This checks if we are in a repo an that there is a commit
    local repo_info
    repo_info=$(command git rev-parse --is-inside-work-tree 2>/dev/null)
    if [ -z "$repo_info" ] ; then
        return
    fi

    local last_commit_unix_timestamp now_unix_timestamp seconds_since_last_commit
    if ! last_commit_unix_timestamp=$(command git log --pretty=format:'%at' -1 2>/dev/null) ; then
        return
    fi
    now_unix_timestamp=$(date +%s)
    seconds_since_last_commit=$(($now_unix_timestamp - $last_commit_unix_timestamp))

    _powerline_format_seconds $seconds_since_last_commit
}

_powerline_git_aggr_numstat(){
    # NOTE: The process substitutions `<(...)` are non-posix so if
    # we have `set -o posix`, bash is going to give weird errors
    # NOTE: For binary files, git diff --numstat shows
    #   -   -   filename.bin
    # and '-' cannot be used as a number.  If that is the case, we change
    # their values to '1'.
    local ins del filename
    local total_ins=0
    local total_del=0
    local total_files=0
    local stotal_ins=0
    local stotal_del=0
    local stotal_files=0
    while read ins del filename ; do
        if [[ "${del}" == "-" ]] && [[ "${ins}" == "-" ]] ; then
            del=1
            ins=1
        fi
        (( total_del += del)) || :
        (( total_ins += ins)) || :
        (( total_files ++ )) || :
    done < <(command git diff --numstat "$@")
    while read ins del filename ; do
        if [[ "${del}" == "-" ]] && [[ "${ins}" == "-" ]] ; then
            del=1
            ins=1
        fi
        (( stotal_del += del)) || :
        (( stotal_ins += ins)) || :
        (( stotal_files ++ )) || :
    done < <(command git diff --numstat --staged "$@")
    if ((total_files != 0)) ; then
        printf "*(${total_files}f,${total_ins}+,${total_del}-)"
    else
        printf "_"
    fi
    printf "\n"
    if ((stotal_files != 0)) ; then
        printf "+(${stotal_files}f,${stotal_ins}+,${stotal_del}-)"
    else
        printf "_"
    fi
    (( total_files == 0 )) && (( stotal_files == 0))
}


_powerline_format_seconds(){
	seconds=$1
    # Totals
    MINUTES=$(($seconds / 60))
    HOURS=$(($seconds /3600))
    # Sub-hours and sub-minutes
    seconds_per_day=$((60*60*24))
    DAYS=$(($seconds / $seconds_per_day))
    SUB_HOURS=$(( $HOURS % 24))
    SUB_MINUTES=$(( $MINUTES % 60))
    if [ "$DAYS" -gt 5 ] ; then
        echo "${DAYS}days"
    elif [ "$DAYS" -gt 1 ]; then
        echo "${DAYS}d${SUB_HOURS}h${SUB_MINUTES}m"
    elif [ "$HOURS" -gt 0 ]; then
        echo "${HOURS}h${SUB_MINUTES}m"
    else
        echo "${MINUTES}m"
    fi
}

_powerline_setup_main
unset _powerline_setup_main
