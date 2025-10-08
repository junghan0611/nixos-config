# Shell configuration module
# Git, Bash, Tmux, Direnv, FZF, Neovim
{ config, lib, pkgs, ... }:

let
  # Import vars
  vars = import ../../../hosts/nuc/vars.nix;

  # Shell aliases
  shellAliases = {
    # Git aliases
    ga = "git add";
    gc = "git commit";
    gco = "git checkout";
    gcp = "git cherry-pick";
    gdiff = "git diff";
    gl = "git prettylog";
    gp = "git push";
    gs = "git status";
    gt = "git tag";

    # Common aliases
    ll = "ls -la";
    la = "ls -A";
    l = "ls -CF";
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
    userName = "Jung Han";
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
      core.editor = "vim";
      diff.tool = "vimdiff";
      merge.tool = "vimdiff";
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
    pinentryPackage = pkgs.pinentry-qt;
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

      # Status bar
      set -g status-bg black
      set -g status-fg white
      set -g status-left '#[fg=green]#H '
      set -g status-right '#[fg=yellow]#(uptime | cut -d "," -f 3-) #[fg=cyan]%Y-%m-%d %H:%M '

      # Window splitting
      bind | split-window -h
      bind - split-window -v

      # Pane navigation
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      # Reload config
      bind r source-file ~/.tmux.conf \; display "Config reloaded!"
    '';
  };
}
