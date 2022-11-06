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
    if [[ -n "${fg}" ]] ; then
        fg_code="38;5;${fg}"
    else
        fg_code="39"
    fi
    if [[ -n "${bg}" ]] ; then
        bg_code="48;5;${bg}"
    else
        bg_code="49"
    fi
    printf "\[\033[0m\033[${fg_code}m\033[${bg_code}m\]\ue0b0\[\033[0m\]"
}

__prompt_section(){
    local content=$1
    local bg_section=$2
    local bg_next=$3
    local fg_section=$4

    if [[ -n "${fg_section}" ]] ; then
        fg_code="38;5;${fg_section}"
    else
        fg_code="39"
    fi

    if [[ -n "${bg_section}" ]] ; then
        bg_code="48;5;${bg_section}"
        # Triangle's foreground is equal to background of this section
        fgt_code="38;5;${bg_section}"
    else
        bg_code="49"
        # To get the color of the default background into the foreground
        # of the triangle, we have to do something super complicated
    fi

    if [[ -n "${bg_next}" ]] ; then
        bgt_code="48;5;${bg_next}"
    else
        bgt_code="49"
    fi
    # echo "${content}" >&2
    printf "\[\033[${bg_code}m\033[${fg_code}m\]%s" "${content}"

    if [[ -n "${bg_section}" ]] ; then
        printf "\[\033[0m\033[${fgt_code}m\033[${bgt_code}m\]\ue0b0"
    else
        # If the background of the section is default, we can't set the
        # foreground of the triangle to default foreground.  Because that's
        # not the same color as the color of the default background.
        #
        # The only thing we can do is set the background of the traiangle to
        # default and invert so that the foreground gets the color of the
        # default background.  So we set the *foreground* equal to the
        # background of the next section and we set the *background* to
        # default.  Then we invert.  Then the foreground of the triangle
        # matches background of the section and the background matches the
        # background of the next section.
        if [[ -n "${bg_next}" ]] ; then
            printf "\[\033[0m\033[49m\033[38;5;${bg_next}m\033[7m\]\ue0b0"
        else
            # This is the case where the background of the next section is
            # also default so we just print a '' between them with some spaces
            # because otherwise the demarcation is not visible.
            printf " \ue0b1 "
        fi
        #
        # I really feel like removing this part since it doubles the size of
        # the code
    fi
    printf "\[\033[0m\]"
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

