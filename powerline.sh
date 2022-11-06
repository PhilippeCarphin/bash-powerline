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
#
# - Because everything that is output is going in PS1, every sequence non
#   non-printing characters must be enclosed in \[...\]
#


__prompt_triangle(){
    # Print a '' (\ue0b0) whose foreground is the color of
    # the prompt section to the left and whose background
    # color is what comes to the right using color codes from
    # the color cube.
    # You need to know the background of the next section to
    # give the right color to the triangle between this section
    # and the next.
    local fg=$1
    local bg=$2
    printf "\[\033[38;5;${fg}m\033[48;5;${bg}m\]\ue0b0\[\033[0m\]"
}

__prompt_section(){
    local content=$1
    local bg_section=$2
    local bg_next=$3
    local fg_section=$4
    printf "\[\033[48;5;${bg_section}m\033[38;5;${fg_section}m\]%s%s\[\033[0m\]" \
        "${content}" "$(__prompt_triangle ${bg_section} ${bg_next})"
}

__git-pwd() {
    local repo_dir=$(git rev-parse --show-toplevel 2>/dev/null)
    local outer=$(basename $repo_dir)
    local inner=$(git rev-parse --show-prefix 2>/dev/null)
    if [[ -z ${inner} ]] ; then
        printf "${outer}"
    else
        printf "${outer}/${inner}"
    fi
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
    if [[ ${previous_exit_code} == 0 ]] ; then
        __prompt_section " ${previous_exit_code} " "${c_exit_code_success}" "${c_host_bg}" "0"
    else
        __prompt_section " ${previous_exit_code} " "${c_exit_code_failure}" "${c_host_bg}" "0"
    fi

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
        __prompt_section "$(git_pwd)" "${c_dir}" "${git_color}"

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
    previous_exit_code=$?
    PS1="$(__prompt ${previous_exit_code}) "
}

PROMPT_COMMAND=__set_ps1

