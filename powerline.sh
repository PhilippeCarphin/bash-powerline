#!/bin/bash

if ! source ~/.git-prompt-phil.sh ; then
    echo "${BASH_SOURCE[0]} expects ~/.git-prompt.sh to exist.  It can be obtained at 'https://github.com/git/git/blob/master/contrib/completion/git-prompt.sh'.  Ideally the one corresponding to your version of git but I always just get the one from 'master' (this link).  There is always a chance that a new one will use git commands that your version of git does not have."
    return 1
fi
GIT_PS1_SHOWUNTRACKEDFILES=1
GIT_PS1_SHOWUPSTREAM=verbose

__next_line_mode(){
    if [[ -z "${__next_line}" ]] ; then
        __next_line="ON"
    else
        __next_line=""
    fi
}

is_git_submodule(){
    [[ -n $(git rev-parse --show-superproject-working-tree 2>/dev/null) ]]
}

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

# Supported by the default font of Windows Terminal
# A fade between the colors of each prompt segment using '▓▒░'
# __powerline_separator="\u2593\u2592\u2591"

# A square in the middle of the line '■'
# __powerline_separator="\u25A0"

# A small triangle '►'
# __powerline_separator="\u25BA"
# __powerline_separator=""

# A ''
__powerline_separator_same_color="\ue0b1"

# Notes:
# - Setting colors from the color cube and extra colors
#   \033[38;5;⟨n⟩m Select foreground color
#   \033[48;5;⟨n⟩m Select background color
#     0-  7:  standard colors (as in \033[<30–37>m)
#     8- 15:  high intensity colors (as in \033[<90–97>m)
#    16-231:  6 × 6 × 6 cube (216 colors): 16 + 36 × r + 6 × g + b (0 ≤ r, g, b ≤ 5)
#   232-255:  grayscale from dark to light in 24 steps
#
# 
#
# - Using \033[38;5;m resets the foreground color to default without changing
#   anything else and \033[48;5;m resets the background without resetting
#   anything else.  This is why the last prompt section can leave ${bg_next}
#   empty.
#   NOTE!!: In Iterm.app on MacOS, \033[38;5;m will create blinking text
#   instead of resetting just the foreground color but not in a TMUX session
#   in Iterm.app.
#
# - Because everything that is output is going in PS1, every sequence non
#   non-printing characters must be enclosed in \[...\]
#

__number_to_background_code(){
    if [[ -n ${1} ]] ; then
        echo "48;5;${1}"
    else
        echo "49"
    fi
}

__number_to_foreground_code(){
    if [[ -n ${1} ]] ; then
        echo "38;5;${1}"
    else
        echo "39"
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
    local fg_code=$(__number_to_foreground_code ${bg_left})
    local bg_code=$(__number_to_background_code ${bg_right})
    printf "\[\033[0m\033[${fg_code}m\033[${bg_code}m\]${__powerline_separator}\[\033[0m\]"
}

__git_pwd() {
    local repo_dir=$(git rev-parse --show-toplevel 2>/dev/null)
    local outer=$(basename $repo_dir)
    local inner=$(git rev-parse --show-prefix 2>/dev/null)
    printf "\[\033[1;4m\]${outer}\[\033[22;24m\]${inner:+/${inner}}"
}

__powerline_job_colors(){
    c_host_bg=52 #90
    c_jobid=88 #127
    # c_user=124 # 164
    # c_dir=160 # 170
}


__prompt(){
    local previous_exit_code=${1}

    local c_host_bg=27
    local c_host_fg=
    local c_jobid=130
    local c_user=33
    local c_dir=74
    local c_dir_fg=15
    local c_git_headless=88
    local c_git_dirty=184
    local c_git_clean=2
    local c_exit_code_success=34
    local c_exit_code_failure=9
    local c_next_line=27
    if [[ -n ${PBS_JOBID} ]] ; then
        __powerline_job_colors
    fi

    #
    # Exit code section, followed by host section
    #
    local c_exit_code
    if [[ ${previous_exit_code} == 0 ]] ; then
        c_exit_code="${c_exit_code_success}"
    else
        c_exit_code="${c_exit_code_failure}"
    fi
    __prompt_section " ${previous_exit_code} " "${c_exit_code}" "0"
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
    # Host section followed by directory section
    #
    __prompt_section "\\u" "${c_user}"
    __prompt_triangle "${c_user}" "${c_dir}"


    local info
    if info="$(git rev-parse --git-dir 2>/dev/null)" ; then
        # Use single-argument form of __git_ps1 to get the text of the
        # git part of the prompt.
        local git_part
        if is_git_submodule ; then
            git_part="$(__git_ps1 " %s \033[1;4mSM\033[21;24m ")"
        else
            git_part="$(__git_ps1 " %s")"
        fi
        # Copy somt code from git-prompt.sh to determine what color to use
        # for the git part of the prompt.
        local git_color
        local g="${info%$'\n'}"
        local b="$(git symbolic-ref HEAD 2>/dev/null)"
        local head
        __git_eread "$g/HEAD" head
        b="${head#ref: }"
        if [[ "${head}" == "${b}" ]] ; then
            git_color="${c_git_headless}"
        elif git diff --no-ext-diff --quiet \
          && git diff --no-ext-diff --cached --quiet ; then
            git_color="${c_git_clean}"
        else
            git_color="${c_git_dirty}"
            git_part="${git_part} $(git_time_since_last_commit)"
        fi

        #
        # Directory section followed by git section
        #
        __prompt_section "$(__git_pwd)" "${c_dir}" "${c_dir_fg}"
        __prompt_triangle "${c_dir}" "${git_color}"

        #
        # Git section followed by nothing
        #
        __prompt_section "${git_part}" "${git_color}" "0"
        __prompt_triangle "${git_color}" ""
    else
        #
        # Directory section followed by nothing
        #
        __prompt_section "\\w" "${c_dir}" "${c_dir_fg}"
        __prompt_triangle "${c_dir}" ""
    fi
    if [[ -n ${__next_line} ]] ; then
        printf "%s" "\n"
        __prompt_section "$" "${c_next_line}" 15
        __prompt_triangle "${c_next_line}" ""
    fi
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

# Cool PS2 that goes up and changes the last bit of PS1 in Next line mode
PS2="\[\r\033[A\033[1;105m\]>\[\033[35;49m\]\[\033[B\r\\033[105;39m\]>\[\033[35;49m\]\[\033[0m\] "
# - beginning of line
# - up one line (\033[A)
# - ovewrite white on blue $ followed by blue '' on default bg by the same thing but with purple instead of blue
# - go down one line (\033[B)
# - beginning of line \r
# - Write a white '>' on purple bg followed by a purple '' on default bg.
# Only works in "next_line_mode"
# PS2="$(__prompt_section ">" "5" "15" ""; __prompt_triangle "5" "") "

PROMPT_COMMAND=__set_ps1

###############################################################################
# At some point, inside VSCode shell, the displayed exit code was always 1
# regardless of whether or not the previous command had succeeded or not.
#
# VSCode launches integrated terminals with
#
#   /usr/bin/bash --init-file .../vscode-server/.../shellIntegration-bash.sh
#
# which
# - loads either the ~/.bashrc or one of ~/.bash_profile, ~/.bash_login, ~/.profile
#   based on VSCODE_SHELL_LOGIN (instead of passing -l to the command becasue it is
#   incompatible with --init-file)
#
# __vsc_prompt_command_original which stores the status of the previous command
# in __vsc_status and then does stuff to let VSCode know whether the command
# succeeded or failed and then calls what I had set as the PROMPT_COMMAND.
# And by the time __my_git_ps1 function is called $? is always 1!
################################################################################
__phil_ps1_deal_with_vscode(){
    if [[ -n ${__vsc_status-} ]] ; then
        previous_exit_code=${__vsc_status}
    fi
}

git_time_since_last_commit() {
    # This checks if we are in a repo an that there is a commit
    local repo_info
    repo_info=$(git rev-parse --is-inside-work-tree 2>/dev/null)
    if [ -z "$repo_info" ] ; then
        return
    fi

    local last_commit_unix_timestamp now_unix_timestamp seconds_since_last_commit
    if ! last_commit_unix_timestamp=$(git log --pretty=format:'%at' -1 2> /dev/null) ; then
        return
    fi
    now_unix_timestamp=$(date +%s)
    seconds_since_last_commit=$(($now_unix_timestamp - $last_commit_unix_timestamp))

    format_seconds $seconds_since_last_commit
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

