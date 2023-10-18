#!/bin/bash

if ! source ~/.git-prompt.sh ; then
    echo "${BASH_SOURCE[0]} expects ~/.git-prompt.sh to exist.  It can be obtained at 'https://github.com/git/git/blob/master/contrib/completion/git-prompt.sh'.  Ideally the one corresponding to your version of git but I always just get the one from 'master' (this link).  There is always a chance that a new one will use git commands that your version of git does not have."
    return 1
fi
GIT_PS1_SHOWUNTRACKEDFILES=
GIT_PS1_SHOWUPSTREAM=verbose
GIT_PS1_SHOWCONFLICTSTATE=1
GIT_PS1_SHOWDIRTYSTATE=

is_git_submodule(){
    [[ -n $(command git rev-parse --show-superproject-working-tree 2>/dev/null) ]]
}

repos_to_ignore=()
if [[ -e ~/.config/powerline_repos_to_ignore.txt ]] ; then
    while read repo ; do
        if [[ "${repo}" == '#'* ]] ; then
            continue
        fi
        repos_to_ignore+=("${repo}")
    done < ~/.config/powerline_repos_to_ignore.txt
fi


__git_ps1_ignore_repo(){
    for r in "${repos_to_ignore[@]}" ; do
        if [[ "${r}" == "${repo_dir}" ]] ; then
            return 0
        fi
    done
    return 1
}


nb_untracked_files(){
    local untracked=($(command git ls-files ${repo_dir} --others --exclude-standard --directory --no-empty-directory))
    local files=0
    local dirs=0
    for f in "${untracked[@]}" ; do
        case $f in
            */) ((dirs++)) ;;
            *) ((files++)) ;;
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
__demo_mode(){
    if [[ -z "${__demo}" ]] ; then
        __demo="ON"
        __original_ps2="${PS2}"
        PS2=" > "
    else
        __demo=""
        PS2="${__original_ps2}"
    fi
}

# The separator's foreground is made to match the background of the section
# to its left and it's background is made to match the section to its right
# A ''
__powerline_separator="\ue0b0"

# A ''
__powerline_separator_same_color="\ue0b1"

__number_to_background_code(){
    if [[ -n ${1} ]] ; then
        echo "48;5;${1}"
    else
        echo "49" # Reset just the background
    fi
}

__number_to_foreground_code(){
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
__prompt_section(){
    local content=$1
    local bg_section=$2
    local fg_section=$3

    local fg_code=$(__number_to_foreground_code ${fg_section})
    local bg_code=$(__number_to_background_code ${bg_section})

    # Print the section's content
    printf "\[\033[${bg_code}m\033[${fg_code}m\]%s" "${content}"
}

__prompt_triangle(){
    local bg_left=$1
    local bg_right=$2
    local bg_code=$(__number_to_background_code ${bg_right})
    if [[ "${bg_left}" == "${bg_right}" ]] ; then
        local fg_code=$(__number_to_foreground_code 240)
        printf "\[\033[0m\033[${bg_code}m\033[${fg_code}m\]${__powerline_separator_same_color}\[\033[0m\]"
    else
        local fg_code=$(__number_to_foreground_code ${bg_left})
        printf "\[\033[0m\033[${fg_code}m\033[${bg_code}m\]${__powerline_separator}\[\033[0m\]"
    fi
}

__git_pwd() {
    local repo_dir=$(command git rev-parse --show-toplevel 2>/dev/null)
    local outer=$(basename $repo_dir 2>/dev/null)
    local inner=$(command git rev-parse --show-prefix 2>/dev/null)
    printf "\[\033[1;4m\]${outer}\[\033[22;24m\]${inner:+/${inner}}"
}

__prompt_git_info(){
    if ! info=($(command git rev-parse --show-toplevel --show-superproject-working-tree 2>/dev/null)) ; then
        return 1
    fi
    repo_dir=${info[0]}
    git_superproject=${info[1]}
    if ! git_branch=$(command git symbolic-ref HEAD 2>/dev/null) ; then
        git_headless=true
        git_detached_branch=$(get_git_detached_branch)
    fi
}

__prompt(){
    local previous_exit_code=${1}
    if [[ ${__powerline_grayscale} == "" ]] ; then
        local c_host_bg=27
        local c_host_fg=
        local c_jobid=130
        local c_user=33
        local c_dir=74
        local c_dir_fg=15
        local c_git_headless=88
        local c_git_headless_fg=0
        local c_git_dirty=184
        local c_git_dirty_fg=0
        local c_git_clean=2
        local c_git_clean_fg=0
        local c_exit_code_success=34
        local c_exit_code_failure=9
        local c_next_line=27
        local c_unstaged_stats=1
        local c_staged_stats=2
        local c_untracked_stats=1
        if [[ -n ${PBS_JOBID} ]] ; then
            c_host_bg=52 #90
            c_jobid=88 #127
        fi
    else
        local c_host_bg=235
        local c_host_fg=
        local c_jobid=130
        local c_user=236
        local c_dir=238
        local c_dir_fg=15
        local c_git_headless=233
        local c_git_headless_fg=7
        local c_git_dirty=240
        # local c_git_dirty_fg=240
        local c_git_clean=244
        # local c_git_clean_fg=240
        local c_exit_code_success=242
        local c_exit_code_success_fg=
        local c_exit_code_failure=233
        local c_exit_code_failure_fg=7
        local c_next_line=234
        local c_unstaged_stats=249
        local c_staged_stats=249
        local c_untracked_stats=15
        if [[ -n ${PBS_JOBID} ]] ; then
            c_host_bg=233 #90
            c_jobid=233 #127
        fi
    fi

    #
    # Exit code section, followed by host section
    #
    local c_exit_code
    local c_exit_code_fg
    if [[ ${previous_exit_code} == 0 ]] ; then
        c_exit_code="${c_exit_code_success}"
        c_exit_code_fg="${c_exit_code_success_fg}"
    else
        c_exit_code="${c_exit_code_failure}"
        c_exit_code_fg="${c_exit_code_failure_fg}"
    fi
    __prompt_section " ${previous_exit_code} " "${c_exit_code}" "${c_exit_code_failure_fg}"
    __prompt_triangle "${c_exit_code}" "${c_host_bg}"

    #
    # Host section followed by user section
    #
    __prompt_section "\\h" "${c_host_bg}" "${c_host_fg}"
    if [[ -n ${PBS_JOBID} ]] ; then
        __prompt_triangle "${c_host_bg}" "${c_jobid}"
        __prompt_section "${PBS_JOBID}" "${c_jobid}"

        __prompt_triangle "${c_jobid}" "${c_user}"
    else
        __prompt_triangle "${c_host_bg}" "${c_user}"
    fi

    #
    # User section followed by directory and git section
    #
    __prompt_section "\\u" "${c_user}"
    __prompt_triangle "${c_user}" "${c_dir}"


    local repo_dir
    local git_superproject
    local git_branch
    local git_headless
    local git_detached_branch
    # Note: __git_ps1_ignore_repo looks at repo_dir which is set by
    # __prompt_git_info so the order is important in the && below:
    if __prompt_git_info && ! __git_ps1_ignore_repo ; then
        local git_extra=""
        if [[ "${git_headless}" == true ]] ; then
            git_color="${c_git_headless}"
            git_color_fg="${c_git_headless_fg}"
            git_extra="$(get_git_detached_branch)"
            if [[ -n ${git_extra} ]] ; then
                git_extra=" [${git_extra}]"
            fi
            # Override colors in headless state
            c_untracked_stats='7'
            c_staged_stats='15'
            c_unstaged_stats='7'
        elif command git diff --no-ext-diff --quiet 2>/dev/null \
          && command git diff --no-ext-diff --cached --quiet 2>/dev/null ; then
            git_color="${c_git_clean}"
            git_color_fg="${c_git_clean_fg}"
            c_untracked_stats='15'
            # git_extra+="\[\033[1;38;5;${c_untracked_stats}m\] $(nb_untracked_files)\[\033[22;39m\]"
        else
            git_color="${c_git_dirty}"
            git_color_fg="${c_git_dirty_fg}"
        fi
        # git_extra="${git_extra} $(git_time_since_last_commit)"
        local diff_stats="$(git_aggr_numstat)"
        local untracked_stats="$(nb_untracked_files)"
        if [[ -n ${diff_stats} ]] || [[ -n ${untracked_stats} ]] ; then
            git_extra+="|"
            git_extra+="${diff_stats}"

            git_extra+="\[\033[1;38;5;${c_untracked_stats}m\]$(nb_untracked_files)\[\033[22;39m\]"
        fi


        # Use single-argument form of __git_ps1 to get the text of the
        # git part of the prompt.
        local git_part
        if [[ "${git_superproject}" != "" ]] ; then
            git_part="$(__git_ps1 " %s${git_extra} \[\033[1;4m\]SM\[\033[21;24m\] ")"
        else
            git_part="$(__git_ps1 " %s${git_extra}")"
        fi

        #
        # Directory section followed by git section
        #
        __prompt_section "$(__git_pwd)" "${c_dir}" "${c_dir_fg}"
        __prompt_triangle "${c_dir}" "${git_color}"

        #
        # Git section followed by nothing
        #
        __prompt_section "${git_part}" "${git_color}" "${git_color_fg}"
        __prompt_triangle "${git_color}" ""
    else
        #
        # Directory section followed by nothing
        #
        __prompt_section "\\w" "${c_dir}" "${c_dir_fg}"
        __prompt_triangle "${c_dir}" ""
    fi

    printf "%s" "\n"
    __prompt_section "$" "${c_next_line}" 15
    __prompt_triangle "${c_next_line}" ""
}

__set_ps1(){
    local previous_exit_code=$?

    # I want the print otherwise I could get rid of two IF statements:
    #   local reset="$(shopt -po xtrace)"
    # which stores in 'reset' the command that I would need to run to
    # set xtrace to what it is currently.  The other if to set it back
    # could be replaced by simply doing
    #   $reset
    local user_had_xtrace
    if shopt -op xtrace >/dev/null; then
        user_had_xtrace=true
        if ! [[ -v BASH_POWERLINE_XTRACE ]] ; then
            printf "Disabling xtrace during prompt evaluation\n"
            set +o xtrace
        fi
    else
        user_had_xtrace=false
    fi
    __phil_ps1_deal_with_vscode

    if [[ -n "${__demo}" ]] ; then
        PS1="=> ${previous_exit_code}\n\n $ "
    else
        PS1="$(__prompt ${previous_exit_code}) "
    fi

    if [[ "${user_had_xtrace}" == true ]] ; then
        if ! [[ -v BASH_POWERLINE_XTRACE ]] ; then
            printf "Reenabling xtrace after prompt evaluation\n"
            set -x
        fi
    fi
}

PS2="\[\033[1;105m\]>\[\033[35;49m\]\[\033[0m\]"
PROMPT_COMMAND=__set_ps1

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
__phil_ps1_deal_with_vscode(){
    if [[ -n ${__vsc_status-} ]] ; then
        previous_exit_code=${__vsc_status}
    fi
}

# In detached head, it may be useful to know that we are on a commit that is
# pointed to by a remote branch.
#
# This function lists the remote branches that are pointing on HEAD and echos
# the list of these branches joined by a space.
get_git_detached_branch(){
    local branches=($(command git branch -r --points-at HEAD --format='%(refname:short)' 2>/dev/null | command grep -v 'HEAD$') )
    local IFS=","
    echo "${branches[*]}"
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

    format_seconds $seconds_since_last_commit
}

git_aggr_numstat(){
    # NOTE: The process substitutions `<(...)` are non-posix so if
    # we have `set -o posix`, bash is going to give weird errors
    # For binary files, git diff --numstat shows
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
        (( total_del += del))
        (( total_ins += ins))
        (( total_files ++ ))
    done < <(command git diff --numstat "$@")
    while read ins del filename ; do
        if [[ "${del}" == "-" ]] && [[ "${ins}" == "-" ]] ; then
            del=1
            ins=1
        fi
        (( stotal_del += del))
        (( stotal_ins += ins))
        (( stotal_files ++ ))
    done < <(command git diff --numstat --staged "$@")
    if ((total_files != 0)) ; then
        printf "\[\033[38;5;${c_unstaged_stats}m\]*(${total_files}f,${total_ins}+,${total_del}-)"
    fi
    if ((stotal_files != 0)) ; then
        printf "\[\033[38;5;${c_staged_stats}m\]+(${stotal_files}f,${stotal_ins}+,${stotal_del}-)"
    fi
    printf "\[\033[39m\]"
}


format_seconds(){
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

