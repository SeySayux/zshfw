# Load local stuff

iterm2_has_help=1

iterm2_help() {
    cat << 'EOF'

    %BiTerm2%b - iTerm2 shell integration.
    %BAuthor%b: Frank Erens %U<frank@synthi.net>%u
    %BDependencies%b: None
    %BKnown conflicts%b: None
    %BNotes%b: Modifies PS1, must be loaded after theme!
    %BSee also%b: https://www.iterm2.com/documentation-shell-integration.html

EOF
}

growl() {
      local msg="\\e]9;\n\n${*}\\007"
      case $TERM in
        screen*)
          echo -ne '\eP'${msg}'\e\\' ;;
        *)
          echo -ne ${msg} ;;
      esac
      return
}

badge() {
    printf "\e]1337;SetBadgeFormat=%s\a" $(echo -n "$@" | base64)
}

imgcat() {
    # tmux requires unrecognized OSC sequences to be wrapped with DCS tmux;
    # <sequence> ST, and for all ESCs in <sequence> to be replaced with ESC ESC. It
    # only accepts ESC backslash for ST.
    function print_osc() {
        if [[ $TERM == screen* ]] ; then
            printf "\033Ptmux;\033\033]"
        else
            printf "\033]"
        fi
    }

    # More of the tmux workaround described above.
    function print_st() {
    if [[ $TERM == screen* ]] ; then
        printf "\a\033\\"
    else
        printf "\a"
    fi
    }

    # print_image filename inline base64contents
    #   filename: Filename to convey to client
    #   inline: 0 or 1
    #   base64contents: Base64-encoded contents
    function print_image() {
    print_osc
    printf '1337;File='
    if [[ -n "$1" ]]; then
        printf 'name='`echo -n "$1" | base64`";"
    fi
    if $(base64 --version 2>&1 | egrep 'fourmilab|GNU' > /dev/null)
    then
        BASE64ARG=-d
    else
        BASE64ARG=-D
    fi
    echo -n "$3" | base64 $BASE64ARG | wc -c | awk '{printf "size=%d",$1}'
    printf ";inline=$2"
    printf ":"
    echo -n "$3"
    print_st
    printf '\n'
    }

    function error() {
    echo "ERROR: $*" 1>&2
    }

    function show_help() {
    echo "Usage: imgcat filename ..." 1>& 2
    echo "   or: cat filename | imgcat" 1>& 2
    }

    ## Main

    if [ -t 0 ]; then
        has_stdin=f
    else
        has_stdin=t
    fi

    # Show help if no arguments and no stdin.
    if [ $has_stdin = f -a $# -eq 0 ]; then
        show_help
        return
    fi

    # Look for command line flags.
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--h|--help)
                show_help
                return
                ;;
            -*)
                error "Unknown option flag: $1"
                show_help
                return 1
                ;;
            *)
                if [ -r "$1" ] ; then
                    print_image "$1" 1 "$(base64 < "$1")"
                else
                    error "imgcat: $1: No such file or directory"
                    return 2
                fi
                ;;
        esac
        shift
    done

    # Read and print stdin
    if [ $has_stdin = t ]; then
        print_image "" 1 "$(cat | base64)"
    fi

    return 0
}

alias show=imgcat

if [ "$TERM" != "screen" -a "$ITERM_SHELL_INTEGRATION_INSTALLED" = "" ]; then
  ITERM_SHELL_INTEGRATION_INSTALLED=Yes
  ITERM2_SHOULD_DECORATE_PROMPT="1"
  # Indicates start of command output. Runs just before command executes.
  iterm2_before_cmd_executes() {
    printf "\033]133;C;\007"
  }

  iterm2_set_user_var() {
    printf "\033]1337;SetUserVar=%s=%s\007" "$1" $(printf "%s" "$2" | base64 | tr -d '\n')
  }

  # Users can write their own version of this method. It should call
  # iterm2_set_user_var but not produce any other output.
  # e.g., iterm2_set_user_var currentDirectory $PWD
  # Accessible in iTerm2 (in a badge now, elsewhere in the future) as
  # \(user.currentDirectory).
  whence -v iterm2_print_user_vars > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    iterm2_print_user_vars() {
    }
  fi

  iterm2_print_state_data() {
    printf "\033]1337;RemoteHost=%s@%s\007" "$USER" "$iterm2_hostname"
    printf "\033]1337;CurrentDir=%s\007" "$PWD"
    iterm2_print_user_vars
  }

  # Report return code of command; runs after command finishes but before prompt
  iterm2_after_cmd_executes() {
    printf "\033]133;D;%s\007" "$STATUS"
    iterm2_print_state_data
  }

  # Mark start of prompt
  iterm2_prompt_mark() {
    printf "\033]133;A\007"
  }

  # Mark end of prompt
  iterm2_prompt_end() {
    printf "\033]133;B\007"
  }

  # There are three possible paths in life.
  #
  # 1) A command is entered at the prompt and you press return.
  #    The following steps happen:
  #    * iterm2_preexec is invoked
  #      * PS1 is set to ITERM2_PRECMD_PS1
  #      * ITERM2_SHOULD_DECORATE_PROMPT is set to 1
  #    * The command executes (possibly reading or modifying PS1)
  #    * iterm2_precmd is invoked
  #      * ITERM2_PRECMD_PS1 is set to PS1 (as modified by command execution)
  #      * PS1 gets our escape sequences added to it
  #    * zsh displays your prompt
  #    * You start entering a command
  #
  # 2) You press ^C while entering a command at the prompt.
  #    The following steps happen:
  #    * (iterm2_preexec is NOT invoked)
  #    * iterm2_precmd is invoked
  #      * iterm2_before_cmd_executes is called since we detected that iterm2_preexec was not run
  #      * (ITERM2_PRECMD_PS1 and PS1 are not messed with, since PS1 already has our escape
  #        sequences and ITERM2_PRECMD_PS1 already has PS1's original value)
  #    * zsh displays your prompt
  #    * You start entering a command
  #
  # 3) A new shell is born.
  #    * PS1 has some initial value, either zsh's default or a value set before this script is sourced.
  #    * iterm2_precmd is invoked
  #      * ITERM2_SHOULD_DECORATE_PROMPT is initialized to 1
  #      * ITERM2_PRECMD_PS1 is set to the initial value of PS1
  #      * PS1 gets our escape sequences added to it
  #    * Your prompt is shown and you may begin entering a command.
  #
  # Invariants:
  # * ITERM2_SHOULD_DECORATE_PROMPT is 1 during and just after command execution, and "" while the prompt is
  #   shown and until you enter a command and press return.
  # * PS1 does not have our escape sequences during command execution
  # * After the command executes but before a new one begins, PS1 has escape sequences and
  #   ITERM2_PRECMD_PS1 has PS1's original value.
  iterm2_decorate_prompt() {
    # This should be a raw PS1 without iTerm2's stuff. It could be changed during command
    # execution.
    ITERM2_PRECMD_PS1="$PS1"
    ITERM2_SHOULD_DECORATE_PROMPT=""

    # Add our escape sequences just before the prompt is shown.
    if [[ $PS1 == *'$(iterm2_prompt_mark)'* ]]
    then
      PS1="$PS1%{$(iterm2_prompt_end)%}"
    else
      PS1="%{$(iterm2_prompt_mark)%}$PS1%{$(iterm2_prompt_end)%}"
    fi
  }

  iterm2_precmd() {
    local STATUS="$?"
    if [ -z "$ITERM2_SHOULD_DECORATE_PROMPT" ]; then
      # You pressed ^C while entering a command (iterm2_preexec did not run)
      iterm2_before_cmd_executes
    fi

    iterm2_after_cmd_executes "$STATUS"

    if [ -n "$ITERM2_SHOULD_DECORATE_PROMPT" ]; then
      iterm2_decorate_prompt
    fi
  }

  # This is not run if you press ^C while entering a command.
  iterm2_preexec() {
    # Set PS1 back to its raw value prior to executing the command.
    PS1="$ITERM2_PRECMD_PS1"
    ITERM2_SHOULD_DECORATE_PROMPT="1"
    iterm2_before_cmd_executes
  }

  # If hostname -f is slow on your system, set iterm2_hostname prior to sourcing this script.
  [[ -z "$iterm2_hostname" ]] && iterm2_hostname=`hostname -f`

  [[ -z $precmd_functions ]] && precmd_functions=()
  precmd_functions=($precmd_functions iterm2_precmd)

  [[ -z $preexec_functions ]] && preexec_functions=()
  preexec_functions=($preexec_functions iterm2_preexec)

  iterm2_print_state_data
  printf "\033]1337;ShellIntegrationVersion=5;shell=zsh\007"
fi
