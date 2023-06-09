#!/bin/bash

if ! source ~/.git-prompt-phil.sh ; then
    echo "${BASH_SOURCE[0]} expects ~/.git-prompt.sh to exist.  It can be obtained at 'https://github.com/git/git/blob/master/contrib/completion/git-prompt.sh'.  Ideally the one corresponding to your version of git but I always just get the one from 'master' (this link).  There is always a chance that a new one will use git commands that your version of git does not have."
    return 1
fi
GIT_PS1_SHOWUNTRACKEDFILES=1
GIT_PS1_SHOWUPSTREAM=verbose
GIT_PS1_SHOWCONFLICTSTATE=1
GIT_PS1_SHOWDIRTYSTATE=

is_git_submodule(){
    [[ -n $(command git rev-parse --show-superproject-working-tree 2>/dev/null) ]]
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
        if [[ -n ${PBS_JOBID} ]] ; then
            c_host_bg=52 #90
            c_jobid=88 #127
        fi
    else
        GIT_PS1_SHOWDIRTYSTATE="yes because black and white is not obvious enough"
        local c_host_bg=234
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


    local info
    if info="$(command git rev-parse --git-dir 2>/dev/null)" ; then
        # Copy somt code from git-prompt.sh to determine what color to use
        # for the git part of the prompt.
        local git_color
        local git_color_fg
        local g="${info%$'\n'}"
        local b="$(command git symbolic-ref HEAD 2>/dev/null)"
        local head
        __git_eread "$g/HEAD" head
        b="${head#ref: }"
        local git_extra=""
        if [[ "${head}" == "${b}" ]] ; then
            git_color="${c_git_headless}"
            git_color_fg="${c_git_headless_fg}"
            git_extra="$(git_detached_branch)"
            if [[ -n ${git_extra} ]] ; then
                git_extra=" [${git_extra}]"
            fi
        elif command git diff --no-ext-diff --quiet 2>/dev/null \
          && command git diff --no-ext-diff --cached --quiet 2>/dev/null ; then
            git_color="${c_git_clean}"
            git_color_fg="${c_git_clean_fg}"
        else
            git_color="${c_git_dirty}"
            git_color_fg="${c_git_dirty_fg}"
            # git_extra="${git_extra} $(git_time_since_last_commit)"
            git_extra+="$(git_aggr_numstat)"
        fi

        # Use single-argument form of __git_ps1 to get the text of the
        # git part of the prompt.
        local git_part
        if is_git_submodule ; then
            git_part="$(__git_ps1 " %s${git_extra} \033[1;4mSM\033[21;24m ")"
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

    local user_had_xtrace
    if shopt -op xtrace >/dev/null; then
        user_had_xtrace=true
        printf "Disabling xtrace during prompt evaluation\n"
    else
        user_had_xtrace=false
    fi
    __phil_ps1_deal_with_vscode

    set +o xtrace
    if [[ -n "${__demo}" ]] ; then
        PS1="=> ${previous_exit_code}\n\n $ "
    else
        PS1="$(__prompt ${previous_exit_code}) "
    fi

    if [[ "${user_had_xtrace}" == true ]] ; then
        printf "Reenabling xtrace after prompt evaluation\n"
        set -x
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
git_detached_branch(){
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
    local ins del filename
    local total_ins=0
    local total_del=0
    local total_files=0
    local stotal_ins=0
    local stotal_del=0
    local stotal_files=0
    while read ins del filename ; do
        (( total_del += del))
        (( total_ins += ins))
        (( total_files ++ ))
    done < <(command git diff --numstat "$@")
    while read ins del filename ; do
        (( stotal_del += del))
        (( stotal_ins += ins))
        (( stotal_files ++ ))
    done < <(command git diff --numstat --staged "$@")
    if ((total_files != 0)) || ((stotal_files != 0)) ; then
        printf "|"
    fi
    if ((total_files != 0)) ; then
        printf "\[\033[31m\]*(${total_files}f,${total_ins}+,${total_del}-)"
    fi
    if ((stotal_files != 0)) ; then
        printf "\[\033[32m\]+(${stotal_files}f,${stotal_ins}+,${stotal_del}-)"
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

