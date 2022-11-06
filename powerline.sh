#!/bin/bash

if ! source ~/.git-prompt.sh ; then
    echo "${BASH_SOURCE[0]} expects ~/.git-prompt.sh to exist.  It can be obtained at 'https://github.com/git/git/blob/master/contrib/completion/git-prompt.sh'.  Ideally the one corresponding to your version of git but I always just get the one from 'master' (this link).  There is always a chance that a new one will use git commands that your version of git does not have."
    return 1
fi

# Notes:
# - Setting colors from the color cube and extra colors
#   \033[38;5;⟨n⟩m Select foreground color
#   \033[48;5;⟨n⟩m Select background color
#     0-  7:  standard colors (as in \033[<30–37>m)
#     8- 15:  high intensity colors (as in \033[<90–97>m)
#    16-231:  6 × 6 × 6 cube (216 colors): 16 + 36 × r + 6 × g + b (0 ≤ r, g, b ≤ 5)
#   232-255:  grayscale from dark to light in 24 steps
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

#
# Print a section of the powerline with a triangle at the end.  You need
# to specify the background of the next section because the triangle's
# background has to match.  That's how I chose to do it.  If the second
# argument is empty, that means default background.
__prompt_section(){
    local content=$1
    local bg_section=$2
    local bg_next=$3
    local fg_section=$4

    local fg_code
    if [[ -n "${fg_section}" ]] ; then
        fg_code="38;5;${fg_section}"
    else
        fg_code="39"
    fi

    local bg_code
    if [[ -n "${bg_section}" ]] ; then
        bg_code="48;5;${bg_section}"
    else
        bg_code="49"
    fi

    local bgt_code
    if [[ -n "${bg_next}" ]] ; then
        bgt_code="48;5;${bg_next}"
    else
        bgt_code="49"
    fi

    printf "\[\033[${bg_code}m\033[${fg_code}m\]%s" "${content}"

    # Print the triangle whose foreground matches the section background
    # and whose background matches the background or the next section
    if [[ -n "${bg_section}" ]] ; then
        # Triangle's foreground is equal to background of this section
        local fgt_code="38;5;${bg_section}"
        printf "\[\033[0m\033[${fgt_code}m\033[${bgt_code}m\]\ue0b0"
    else
        if [[ -n "${bg_next}" ]] ; then
            # To get the default background color into the triangles's foreground
            # we set the background to default and the foreground equal to the
            # next section's background and invert the two using code 7.
            printf "\[\033[0m\033[49m\033[38;5;${bg_next}m\033[7m\]\ue0b0"
        else
            # This is the case where both this section and the next have default
            # background.  Then we just print a ''
            printf " \ue0b1 "
        fi
    fi
    printf "\[\033[0m\]"
}

__git_pwd() {
    local repo_dir=$(git rev-parse --show-toplevel 2>/dev/null)
    local outer=$(basename $repo_dir)
    local inner=$(git rev-parse --show-prefix 2>/dev/null)
    printf "\[\033[1;4m\]${outer}\[\033[22;24m\]${inner:+/${inner}}"
}

__prompt(){
    #
    # Note that the git commands are copied from git-prompt.sh so some work
    # is done twice so that I can access the info from some local variables
    # in the function __git_ps1.  There are up to 4 git commands that are
    # needlessly rerun here to decide how to color the git part.  For now
    # this does't cause any slowness.
    #
    local c_host_bg=21
    local c_host_fg=14
    local c_user=27
    local c_dir=33
    local c_git_headless=52
    local c_git_dirty=184
    local c_git_clean=2
    local c_exit_code_success=34
    local c_exit_code_failure=9

    #
    # Exit code section, followed by host section
    #
    local previous_exit_code=${1}
    local c_exit_code
    if [[ ${previous_exit_code} == 0 ]] ; then
        c_exit_code="${c_exit_code_success}"
    else
        c_exit_code="${c_exit_code_failure}"
    fi
    __prompt_section " ${previous_exit_code} " "${c_exit_code}" "${c_host_bg}" "0"

    #
    # Host section followed by user section
    #
    __prompt_section "\\h" "${c_host_bg}" "${c_user}" "${c_host_fg}"

    #
    # Host section followed by directory section
    #
    __prompt_section "\\u" "${c_user}" "${c_dir}"

    local g
    local info
    local git_color
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
        __prompt_section "$(__git_pwd)" "${c_dir}" "${git_color}"

        #
        # Git section followed by nothing
        #
        __prompt_section "${git_part}" "${git_color}" "" "0"
    else
        #
        # Directory section followed by nothing
        #
        __prompt_section "\\w" "${c_dir}"
    fi
}

__set_ps1(){
    local previous_exit_code=$?
    PS1="$(__prompt ${previous_exit_code}) "
}

PROMPT_COMMAND=__set_ps1

