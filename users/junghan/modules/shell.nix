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
  };
in {
  #---------------------------------------------------------------------
  # Session Variables
  #---------------------------------------------------------------------
  home.sessionVariables = {
    TERM = "xterm-256color";
  };

  #---------------------------------------------------------------------
  # Git
  #---------------------------------------------------------------------
  programs.git = {
    enable = true;

    settings = {
      user = {
        name = vars.username;
        email = vars.email;
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
      github.user = vars.username;

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

    initExtra = ''
      # Set up prompt
      PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

      # Better ls colors
      eval "$(dircolors -b)"

      export PNPM_HOME="/home/${vars.username}/.local/share/pnpm"
      case ":$PATH:" in
        *":$PNPM_HOME:"*) ;;
        *) export PATH="$PNPM_HOME:$PATH" ;;
      esac

      # User specific paths
      export PATH=~/.local/bin:$PATH

      # FZF key bindings
      if command -v fzf &> /dev/null; then
        source ${pkgs.fzf}/share/fzf/key-bindings.bash
        source ${pkgs.fzf}/share/fzf/completion.bash
      fi

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
      sync_frequency = "5m";
      search_mode = "fuzzy";
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
  programs.gpg.enable = true;

  services.gpg-agent = {
    enable = true;
    pinentry.package = pkgs.pinentry-qt;
    enableBashIntegration = true;
    # Cache passphrase for 24 hours (86400 seconds)
    defaultCacheTtl = 86400;
    maxCacheTtl = 86400;
    extraConfig = ''
      allow-emacs-pinentry
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
  # Tmux (hej-nixos-cluster 스타일 통일)
  #---------------------------------------------------------------------
  programs.tmux = {
    enable = true;
    terminal = "screen-256color";
    shortcut = "a";
    baseIndex = 1;
    escapeTime = 0;
    historyLimit = 50000;
    keyMode = "vi";
    clock24 = true;

    extraConfig = ''
      # OSC-52 클립보드 지원 (SSH 원격 복사)
      set -g set-clipboard on
      set -g allow-passthrough on

      # 마우스 지원
      set -g mouse on

      # Vi 복사 모드 with OSC-52
      bind-key -T copy-mode-vi v send-keys -X begin-selection
      bind-key -T copy-mode-vi C-v send-keys -X rectangle-toggle
      bind-key -T copy-mode-vi y send-keys -X copy-pipe-and-cancel 'cat | base64 -w0 | xargs -I{} printf "\033]52;c;{}\007"'
      bind-key -T copy-mode-vi Enter send-keys -X copy-pipe-and-cancel 'cat | base64 -w0 | xargs -I{} printf "\033]52;c;{}\007"'

      # 상태바 설정 (심플)
      set -g status-bg colour235
      set -g status-fg white
      set -g status-left '#[fg=green]#S #[fg=yellow]#H '
      set -g status-right '#[fg=cyan]%Y-%m-%d %H:%M'

      # 창 분할 키 (현재 경로 유지)
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
      bind c new-window -c "#{pane_current_path}"

      # 창 이동 vim 스타일
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      # 창 크기 조절 (Alt + 방향키)
      bind -n M-Left resize-pane -L 5
      bind -n M-Right resize-pane -R 5
      bind -n M-Up resize-pane -U 5
      bind -n M-Down resize-pane -D 5

      # 설정 리로드
      bind r source-file ~/.tmux.conf \; display "Config reloaded!"

      # 세션 로깅 (작업 기록용)
      bind P pipe-pane -o "cat >>~/tmux-#W.log" \; display "Logging to ~/tmux-#W.log"

      # 윈도우 자동 리넘버링
      set -g renumber-windows on

      # 포커스 이벤트
      set -g focus-events on
    '';
  };

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

    themes = {
      dracula = {
        fg = "#F8F8F2";
        bg = "#282A36";
        black = "#21222C";
        red = "#FF5555";
        green = "#50FA7B";
        yellow = "#F1FA8C";
        blue = "#BD93F9";
        magenta = "#FF79C6";
        cyan = "#8BE9FD";
        white = "#F8F8F2";
        orange = "#FFB86C";
      };
    };
  };
}
