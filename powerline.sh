#!/bin/bash

if ! source ~/.git-prompt.sh ; then
    echo "${BASH_SOURCE[0]} expects ~/.git-prompt.sh to exist.  It can be obtained at 'https://github.com/git/git/blob/master/contrib/completion/git-prompt.sh'.  Ideally the one corresponding to your version of git but I always just get the one from 'master' (this link).  There is always a chance that a new one will use git commands that your version of git does not have."
    return 1
fi

__next_line=""
__next_line_mode(){
    if [[ -z "${__next_line}" ]] ; then
        __next_line="ON"
    else
        __next_line=""
    fi
}

__demo=""
__demo_mode(){
    if [[ -z "${__demo}" ]] ; then
        __demo="ON"
    else
        __demo=""
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
    local fg_section=$4

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

__prompt(){
    local previous_exit_code=${1}

    local c_host_bg=27
    local c_host_fg=
    local c_user=33
    local c_dir=74
    local c_dir_fg=
    local c_git_headless=52
    local c_git_dirty=184
    local c_git_clean=2
    local c_exit_code_success=34
    local c_exit_code_failure=9
    local c_next_line=27

    #
    # Exit code section, followed by host section
    #
    local c_exit_code
    if [[ ${previous_exit_code} == 0 ]] ; then
        c_exit_code="${c_exit_code_success}"
    else
        c_exit_code="${c_exit_code_failure}"
    fi
    __prompt_section " ${previous_exit_code} " "${c_exit_code}" "${c_host_bg}" "0"
    __prompt_triangle "${c_exit_code}" "${c_host_bg}"

    #
    # Host section followed by user section
    #
    __prompt_section "\\h" "${c_host_bg}" "${c_user}" "${c_host_fg}"
    __prompt_triangle "${c_host_bg}" "${c_user}"

    #
    # Host section followed by directory section
    #
    __prompt_section "\\u" "${c_user}" "${c_dir}"
    __prompt_triangle "${c_user}" "${c_dir}"

    local g
    local info
    local git_color
    # PS1=""
    # __git_ps1 "." "." "(%s asdfasd)"
    # echo "PS1 after __git_ps1 = ${PS1}"
    if info="$(git rev-parse --git-dir 2>/dev/null)" ; then
        local g="${info%$'\n'}"
        local b="$(git symbolic-ref HEAD 2>/dev/null)"
        local git_part="$(__git_ps1 "(%s)")"
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
        fi
        #
        # Directory section followed by git section
        #
        __prompt_section "$(__git_pwd)" "${c_dir}" "${git_color}" "${c_dir_fg}"
        __prompt_triangle "${c_dir}" "${git_color}"

        #
        # Git section followed by nothing
        #
        __prompt_section "${git_part}" "${git_color}" "" "0"
        __prompt_triangle "${git_color}" ""
    else
        #
        # Directory section followed by nothing
        #
        __prompt_section "\\w" "${c_dir}" "" "${c_dir_fg}"
        __prompt_triangle "${c_dir}" ""
    fi
    if [[ -n ${__next_line} ]] ; then
        printf "%s" "\n"
        __prompt_section "$" "${c_next_line}" "" ""
        __prompt_triangle "${c_host_bg}" ""
    fi
}

__set_ps1(){
    local previous_exit_code=$?
    if [[ -n "${__demo}" ]] ; then
        PS1='\n $ '
    else
        PS1="$(__prompt ${previous_exit_code}) "
    fi
}
PS2="$(__prompt_section ">" "5" "" ""; __prompt_triangle "5" "") "

PROMPT_COMMAND=__set_ps1

