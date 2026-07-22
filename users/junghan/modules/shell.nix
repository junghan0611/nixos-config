# Shell configuration module
# Git, Bash, Tmux, Direnv, FZF, Neovim
{ config, lib, pkgs, ... }:

let
  # Import vars
  vars = import ../../../hosts/nuc/vars.nix;

  # Shell aliases
  shellAliases = {
    # Git aliases
    gco = "git checkout";
    gch = "git checkout HEAD";
    gdiff = "git diff";
    gs = "git status";
    gsta = "git status";
    gadd = "git add -v";
    gcom = "git commit";
    gcomm = "git commit -m";
    gl = "git prettylog";
    glog = "git log --oneline --graph -10";
    gbl = "git branch --list";
    gpm = "git push -u origin main";
    gpk = "git push -u origin ko";
    gpull = "git pull";

    # Common aliases
    la = "ls -A";
    l = "ls -CF";
    ll = "ls -la";

    ".." = "cd ..";
    "..." = "cd ../..";

    # NixOS specific
    rebuild = "sudo nixos-rebuild switch --flake .#$HOST";
    rebuild-test = "sudo nixos-rebuild test --flake .#$HOST";

    # peon-ping (Claude Code event sounds)
    peon = "bash $HOME/.claude/hooks/peon-ping/peon.sh";
  };
in {
  #---------------------------------------------------------------------
  # Session Variables
  #---------------------------------------------------------------------
  home.sessionVariables = {
    TERM = "xterm-256color";
    PNPM_HOME = "/home/${vars.username}/.local/share/pnpm";
  };

  # Session PATH — ~/.profile에 기록되어 SSH 비인터랙티브에서도 유효
  # pnpm 11 단일 버전(26.05 네이티브). 글로벌 command shim은 $PNPM_HOME/bin에만
  # 생성된다(~/.config/pnpm/rc의 global-bin-dir로 고정). 부모 경로($PNPM_HOME)는
  # v10 시절 잔재라 제거 — 서랍이 둘로 갈리던 원인.
  home.sessionPath = [
    "/home/${vars.username}/.local/share/pnpm/bin"
    "/home/${vars.username}/.local/bin"
    "/home/${vars.username}/go/bin"
    "/home/${vars.username}/bin"
  ];

  # pnpm 전역 설정 — 단일 버전 SSOT 고정. npm auth 토큰이 든 ~/.npmrc를 덮지 않도록
  # pnpm 전용 rc를 쓴다.
  #  - manage-package-manager-versions=false: packageManager 필드 기반 self-download/
  #    재위임을 끈다(디렉토리마다 pnpm 버전 갈아끼우며 .tools/ 서랍 늘리던 원인).
  #  - global-bin-dir: 글로벌 shim 위치를 $PNPM_HOME/bin에 못박는다.
  home.file.".config/pnpm/rc".text = ''
    manage-package-manager-versions=false
    global-bin-dir=/home/${vars.username}/.local/share/pnpm/bin
  '';

  #---------------------------------------------------------------------
  # Git
  #---------------------------------------------------------------------
  programs.git = {
    enable = true;

    settings = {
      user = {
        # Commit attribution → junghan0611 GitHub account.
        # Identity lives in hosts/*/vars.nix (gitName/gitEmail), kept
        # separate from vars.email (the real mail used by email.nix/msmtp).
        name = vars.gitName;
        email = vars.gitEmail;
      };

      alias = {
        co = "checkout";
        ci = "commit";
        st = "status";
        br = "branch";
        hist = "log --pretty=format:'%h %ad | %s%d [%an]' --graph --date=short";
        type = "cat-file -t";
        dump = "cat-file -p";
        prettylog = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(r) %C(bold blue)<%an>%Creset' --abbrev-commit --date=relative";
      };

      init.defaultBranch = "main";
      push.default = "current";
      pull.rebase = true;

      core = {
        editor = "vim";
        filemode = false; # 파일 권한 변경 추적 끄기
        # Korean filename support
        quotePath = false;           # 한글 파일명 정상 표시
        precomposeunicode = true;    # 유니코드 정규화
        autocrlf = "input";          # Linux/Mac line endings

        # Global commit/push safety rail — SSOT in agent-config.
        # Scans staged/pushed diffs for identity terms (public repos only)
        # + secrets (all repos). Blocks the operation on violation.
        # Bypass (GLG only): AGENT_ALLOW_UNSAFE_COMMIT=1
        # See: ~/repos/gh/agent-config/git-hooks/README.md
        hooksPath = "${config.home.homeDirectory}/repos/gh/agent-config/git-hooks";
      };

      diff = {
        tool = "vimdiff";
        # Org-mode and Lisp file support
        org.xfuncname = "^(\\*+ +.*|#\\+title:.*)$";
        lisp.xfuncname = "^(((;;;+ )|\\(|([ \t]+\\(((cl-|el-patch-)?def(un|var|macro|method|custom)|gb/))).*)$";
      };

      merge = {
        tool = "vimdiff";
        conflictstyle = "zdiff3";    # Better conflict markers with delta
      };

      # GitHub identity
      github.user = vars.gitName;

      # Git LFS
      filter.lfs = {
        smudge = "git-lfs smudge -- %f";
        process = "git-lfs filter-process";
        required = true;
        clean = "git-lfs clean -- %f";
      };

      # Better colors
      color = {
        ui = "auto";
        branch = "auto";
        diff = "auto";
        status = "auto";
      };
    };
  };

  # Delta (git diff viewer)
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      line-numbers = true;
      syntax-theme = "Monokai Extended";
    };
  };

  #---------------------------------------------------------------------
  # Bash
  #---------------------------------------------------------------------
  programs.bash = {
    enable = true;
    enableCompletion = true;
    historyControl = [ "erasedups" "ignoredups" "ignorespace" ];
    historyFileSize = 10000;
    historySize = 10000;

    shellAliases = shellAliases;

    # non-interactive SSH (scp, rsync, claude delegate 등)에서도
    # hm-session-vars.sh 환경변수를 로드하기 위해 interactive guard 전에 실행
    bashrcExtra = ''
      [[ -f ~/.profile ]] && . ~/.profile
    '';

    initExtra = ''
      # Ctrl+D로 셸 종료 방지 (10회 연속 입력 시에만 종료)
      export IGNOREEOF=10

      # GPG TTY 설정 (SSH 터미널에서 pinentry 작동 필수)
      export GPG_TTY=$(tty)

      # Set up prompt
      PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

      # Better ls colors
      eval "$(dircolors -b)"

      export PNPM_HOME="/home/${vars.username}/.local/share/pnpm"
      case ":$PATH:" in
        *":$PNPM_HOME/bin:"*) ;;
        *) export PATH="$PNPM_HOME/bin:$PATH" ;;
      esac

      # User specific paths
      export PATH=~/.local/bin:$PATH

      # FZF key bindings
      if command -v fzf &> /dev/null; then
        source ${pkgs.fzf}/share/fzf/key-bindings.bash
        source ${pkgs.fzf}/share/fzf/completion.bash
      fi

      # emacsclient wrapper — 24bit true-color 자동 감지
      # COLORTERM=truecolor인데 TERM의 colors < 257이면 *-direct terminfo로 전환
      # ref: tecosaur doom config.org "Emacs client wrapper"
      e() {
          local term="$TERM"
          if { [ "$COLORTERM" = truecolor ] || [ "$COLORTERM" = 24bit ]; } \
              && [ "$(tput colors 2>/dev/null)" -lt 257 ]; then
              local stub="''${TERM%%-*}"
              if infocmp "''${stub}-direct" >/dev/null 2>&1; then
                  term="''${stub}-direct"
              else
                  term="xterm-direct"
              fi
          fi
          TERM="$term" emacsclient -s user -nw "$@"
      }
      alias v='e'
      alias ec='emacsclient -s user -n'
      alias ecn='emacsclient -s user -c -n'

      # ── tmux — 세션 = 작업 디렉토리 ──────────────────────────────────
      # 설정 본문은 users/junghan/configs/tmux.conf, 진입 함수는 여기.
      # 원래 ~/.bashrc.local 에 있던 것을 repo 로 회수했다. .bashrc.local 은
      # 이 initExtra *다음에* source 되므로, 거기 같은 이름이 남아 있으면 이걸
      # 조용히 덮는다 — 옮길 때 저쪽에서 지워야 한다.

      # tm — 현재 디렉토리 이름으로 세션을 열거나, 이미 있으면 그리로 간다.
      #   tm          → basename "$PWD" 를 세션명으로
      #   tm garden   → 이름을 직접 줄 때
      tm() {
        local name=''${1:-$(basename "$PWD")}
        # tmux는 . 과 : 를 target 구분자로 파싱한다 (session:window.pane) → 치환
        name=''${name//[.: ]/-}
        if [ -n "$TMUX" ]; then
          # 이미 tmux 안이면 attach가 거부된다("sessions should be nested with care")
          # → 없으면 detached로 만들고 클라이언트를 그리로 옮긴다
          tmux has-session -t "=$name" 2>/dev/null || tmux new-session -d -s "$name" -c "$PWD"
          tmux switch-client -t "=$name"
        else
          # -A = 같은 이름이 이미 있으면 새로 만들지 않고 attach
          tmux new-session -A -s "$name" -c "$PWD"
        fi
      }

      # tml — 열려 있는 세션을 fzf 로 골라 들어간다. `tmux ls` 로 이름을 보고
      # `tmux attach -t` 를 다시 치는 왕복을 없앤다.
      #   tml         → 목록에서 선택
      #   tml gar     → 그 쿼리로 시작. 하나만 남으면 (--select-1) 바로 들어간다.
      # tmux 안에서 부르면 attach 가 중첩으로 거부되므로 switch-client — tm 과 같은 규칙.
      tml() {
        local tab=$'\t' list name
        list=$(tmux ls -F "#{session_name}$tab#{session_windows}w #{?session_attached,●,}$tab#{session_path}" 2>/dev/null) || {
          echo "tml: 실행 중인 tmux 세션이 없다 (tm 으로 하나 열어라)" >&2
          return 1
        }
        # 세 칸(이름 / 창수 ● / 경로)을 탭으로 나눠 두면 cut -f1 이 이름만 집는다.
        name=$(printf '%s\n' "$list" | sed "s|$HOME|~|" |
          fzf --reverse --height=40% --prompt='session> ' \
              --query="''${1:-}" --select-1 --exit-0 | cut -f1)
        [ -n "$name" ] || return 0
        if [ -n "$TMUX" ]; then
          tmux switch-client -t "=$name"
        else
          tmux attach -t "=$name"
        fi
      }

      # peon-ping tab completions
      [ -f "$HOME/.claude/hooks/peon-ping/completions.bash" ] && source "$HOME/.claude/hooks/peon-ping/completions.bash"

      # pi garden launcher (pia/pit/pid/… + _pi_garden_pi) lives in ~/.bashrc.local
      # alongside the rest of the pi aliases (pial, etc.), sourced below. Single
      # home — do not duplicate it here (it would be shadowed by .bashrc.local).

      # Claude Config bash 설정 로드
      if [ -f "$HOME/claude-config/bash/bashrc" ]; then
         source "$HOME/claude-config/bash/bashrc"
      fi

      # 사용자 로컬 설정 (있는 경우)
      if [ -f "$HOME/.bashrc.local" ]; then
         source "$HOME/.bashrc.local"
      fi
    '';
  };

  #---------------------------------------------------------------------
  # Direnv
  #---------------------------------------------------------------------
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  #---------------------------------------------------------------------
  # Atuin - Shell history sync
  #---------------------------------------------------------------------
  programs.atuin = {
    enable = true;
    enableBashIntegration = true;
    settings = {
      # auto_sync = true;  # Disabled - manual sync only
      sync_frequency = "1h";
      search_mode = "fuzzy";
      filter_mode = "directory";
      flags = [ "--disable-ctrl-r" ]; # "--disable-up-arrow" ]; 
    };
  };

  #---------------------------------------------------------------------
  # Zoxide - Smarter cd command
  #---------------------------------------------------------------------
  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
  };

  #---------------------------------------------------------------------
  # GLG toolbox (glg, greview.py)
  #---------------------------------------------------------------------
  home.file.".local/bin/glg" = {
    source = ../../../scripts/glg;
    executable = true;
    force = true;
  };
  home.file.".local/bin/greview.py" = {
    source = ../../../scripts/greview.py;
    executable = true;
    force = true;
  };
  home.file.".local/bin/peon-setup" = {
    source = ../../../scripts/peon-setup;
    executable = true;
    force = true;
  };

  #---------------------------------------------------------------------
  # fd (find alternative)
  #---------------------------------------------------------------------
  home.file.".fdignore".text = ''
    .git
    node_modules
    .DS_Store
  '';

  #---------------------------------------------------------------------
  # FZF
  #---------------------------------------------------------------------
  programs.fzf = {
    enable = true;
    defaultCommand = "fd --type f --hidden --follow --exclude .git";
    defaultOptions = [
      "--height 40%"
      "--border"
      "--reverse"
      "--color=dark"
    ];
  };

  #---------------------------------------------------------------------
  # Neovim
  #---------------------------------------------------------------------
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    # 26.05: 기본값 true→false로 변경됨. ruby/python3 provider 유지(기존 동작 보존).
    withRuby = true;
    withPython3 = true;

    extraConfig = ''
      set number
      set relativenumber
      set expandtab
      set tabstop=2
      set shiftwidth=2
      set autoindent
      set smartindent
      set mouse=a
      set clipboard=unnamedplus
      set termguicolors

      " Better search
      set ignorecase
      set smartcase
      set incsearch
      set hlsearch
    '';
  };

  #---------------------------------------------------------------------
  # GPG
  #---------------------------------------------------------------------
  # 중요: 패스프레이즈 캐시 동작 방식
  #
  # TTL 설정은 "한번 입력 후 지정 기간 동안 유지"를 의미합니다.
  # 다음 상황에서는 최초 1회 패스프레이즈 입력이 필요합니다:
  #   - nixos-rebuild switch 후 gpg-agent 서비스 재시작 시
  #   - 시스템 재부팅 시
  #   - gpgconf --kill gpg-agent 실행 후
  #
  # 이는 설정 오류가 아닌 정상적인 보안 동작입니다.
  # 터미널에서 `pass show <entry>` 한 번 실행하면 이후 TTL 기간 동안 캐시됩니다.
  #
  # 캐시 상태 확인: gpg-connect-agent 'keyinfo --list' /bye
  #   - 5번째 필드가 '1'이면 캐시됨, '-'이면 캐시 안 됨
  #
  programs.gpg.enable = true;

  services.gpg-agent = {
    enable = true;
    # SSH 터미널 환경용 (pinentry-qt는 GUI 필요하여 터미널 손상)
    pinentry.package = pkgs.pinentry-curses;
    enableBashIntegration = true;
    # 패스프레이즈 캐시 유지 기간: 1년 (31536000초)
    # 재부팅/rebuild 후 첫 입력 필요, 이후 1년간 유지
    defaultCacheTtl = 31536000;
    maxCacheTtl = 31536000;
    extraConfig = ''
      allow-emacs-pinentry
      allow-loopback-pinentry
    '';
  };

  # authinfo.gpg symlink for Emacs (gptel, etc.)
  # Created conditionally via activation script if source file exists
  home.activation.createAuthInfoLink = lib.hm.dag.entryAfter ["writeBoundary"] ''
    AUTH_FILE="${config.home.homeDirectory}/sync/org/authinfo.gpg"
    AUTH_LINK="${config.home.homeDirectory}/.authinfo.gpg"
    if [ -f "$AUTH_FILE" ]; then
      if [ -L "$AUTH_LINK" ] || [ ! -e "$AUTH_LINK" ]; then
        $DRY_RUN_CMD ln -sf "$AUTH_FILE" "$AUTH_LINK"
      fi
    fi
  '';

  # Import GPG public key from claude-config
  # Note: Private key must be imported manually (requires passphrase):
  #   gpg --import ~/claude-config/gpg-keys/junghanacs_private_key.asc
  home.activation.importGpgKeys = lib.hm.dag.entryAfter ["writeBoundary"] ''
    GPG_KEY_DIR="${config.home.homeDirectory}/claude-config/gpg-keys"
    if [ -d "$GPG_KEY_DIR" ] && [ -f "$GPG_KEY_DIR/junghanacs_public_key.asc" ]; then
      $DRY_RUN_CMD ${pkgs.gnupg}/bin/gpg --import "$GPG_KEY_DIR/junghanacs_public_key.asc" 2>/dev/null || true
    fi
  '';

  #---------------------------------------------------------------------
  # Password Store
  #---------------------------------------------------------------------
  programs.password-store = {
    enable = true;
    package = pkgs.pass.withExtensions (exts: [ exts.pass-otp ]);
    settings = {
      PASSWORD_STORE_DIR = "${config.home.homeDirectory}/.password-store";
    };
  };

  #---------------------------------------------------------------------
  # Tmux
  #---------------------------------------------------------------------
  home.packages = [
    pkgs.tmux
  ];
  # 설정 본문은 users/junghan/configs/tmux.conf 를 직접 symlink.
  # 라이브 편집/테스트를 위해 Home Manager 생성 conf 대신 repo 파일을 사용.

  #---------------------------------------------------------------------
  # Zellij (modern terminal multiplexer)
  #---------------------------------------------------------------------
  programs.zellij = {
    enable = true;

    settings = {
      theme = "dracula";
      default_shell = "bash";
      pane_frames = true;
      simplified_ui = false;
      copy_on_select = true;
      scrollback_editor = "vim";
      mouse_mode = true;
    };
  };

  # Zellij theme file (requires themes{} wrapper for zellij 0.43+)
  xdg.configFile."zellij/themes/dracula.kdl".text = ''
    themes {
      dracula {
        fg "#F8F8F2"
        bg "#282A36"
        black "#21222C"
        red "#FF5555"
        green "#50FA7B"
        yellow "#F1FA8C"
        blue "#BD93F9"
        magenta "#FF79C6"
        cyan "#8BE9FD"
        white "#F8F8F2"
        orange "#FFB86C"
      }
    }
  '';
}
