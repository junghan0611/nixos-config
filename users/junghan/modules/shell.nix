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
  # Git
  #---------------------------------------------------------------------
  programs.git = {
    enable = true;
    userName = vars.username;
    userEmail = vars.email;

    aliases = {
      co = "checkout";
      ci = "commit";
      st = "status";
      br = "branch";
      hist = "log --pretty=format:'%h %ad | %s%d [%an]' --graph --date=short";
      type = "cat-file -t";
      dump = "cat-file -p";
      prettylog = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(r) %C(bold blue)<%an>%Creset' --abbrev-commit --date=relative";
    };

    extraConfig = {
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

    delta = {
      enable = true;
      options = {
        navigate = true;
        line-numbers = true;
        syntax-theme = "Monokai Extended";
      };
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
    extraConfig = ''
      allow-emacs-pinentry
    '';
  };

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
  programs.tmux = {
    enable = true;
    terminal = "screen-256color";
    shortcut = "a";
    baseIndex = 1;
    escapeTime = 0;
    historyLimit = 10000;

    extraConfig = ''
      # Mouse support
      set -g mouse on

      # Vi mode
      setw -g mode-keys vi

      # Vi-copy mode (v=select, y=copy, Ctrl-v=rectangle)
      bind-key -T copy-mode-vi v send-keys -X begin-selection
      bind-key -T copy-mode-vi C-v send-keys -X rectangle-toggle
      bind-key -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "${pkgs.xclip}/bin/xclip -selection clipboard -i"
      bind-key -T copy-mode-vi Enter send-keys -X copy-pipe-and-cancel "${pkgs.xclip}/bin/xclip -selection clipboard -i"

      # Paste from system clipboard
      bind ] run "${pkgs.xclip}/bin/xclip -selection clipboard -o | tmux load-buffer - && tmux paste-buffer"

      # Status bar
      set -g status-bg black
      set -g status-fg white
      set -g status-left '#[fg=green]#H '
      set -g status-right '#[fg=yellow]#(uptime | cut -d "," -f 3-) #[fg=cyan]%Y-%m-%d %H:%M '

      # Window splitting (current path)
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
      bind c new-window -c "#{pane_current_path}"

      # Pane navigation
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      # Pane resize (Alt + arrows)
      bind -n M-Left resize-pane -L 5
      bind -n M-Right resize-pane -R 5
      bind -n M-Up resize-pane -U 5
      bind -n M-Down resize-pane -D 5

      # Reload config
      bind r source-file ~/.tmux.conf \; display "Config reloaded!"

      # Window auto-rename off
      set -g automatic-rename off
      set -g allow-rename off

      # Renumber windows
      set -g renumber-windows on
    '';
  };
}
