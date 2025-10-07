{ inputs, ... }:

{ config, lib, pkgs, ... }:

let
  isLinux = pkgs.stdenv.isLinux;

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
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "junghan";
  home.homeDirectory = "/home/junghan";

  # This value determines the Home Manager release that your
  # configuration is compatible with.
  home.stateVersion = "25.05";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Enable XDG base directories
  xdg.enable = true;

  #---------------------------------------------------------------------
  # Packages
  #---------------------------------------------------------------------
  home.packages = with pkgs; [
    # CLI tools
    bat
    eza
    fd
    fzf
    gh
    htop
    jq
    ripgrep
    tree
    watch
    ncdu
    duf
    procs

    # Development
    lazygit
    delta
    git-lfs
    direnv

    # System tools
    neofetch

    # Editors
    emacs
  ] ++ (lib.optionals isLinux [
    # Linux-specific packages
    xclip
    wl-clipboard
  ]);

  #---------------------------------------------------------------------
  # Dotfiles
  #---------------------------------------------------------------------
  home.file = {
    ".config/i3/config".text = builtins.readFile ./i3;
    # i3status is configured via programs.i3status below
    ".config/rofi/config.rasi".text = builtins.readFile ./rofi;
    ".Xresources".text = builtins.readFile ./Xresources;
    ".config/ghostty/config".text = builtins.readFile ./ghostty.linux;
    ".config/kitty/kitty.conf".text = builtins.readFile ./kitty;
    ".inputrc".text = builtins.readFile ./inputrc;
  };

  #---------------------------------------------------------------------
  # Programs configuration
  #---------------------------------------------------------------------

  # Git configuration
  programs.git = {
    enable = true;
    userName = "Jung Han";
    userEmail = "junghanacs@gmail.com";

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

  # Bash configuration
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

      # FZF key bindings
      if command -v fzf &> /dev/null; then
        source ${pkgs.fzf}/share/fzf/key-bindings.bash
        source ${pkgs.fzf}/share/fzf/completion.bash
      fi
    '';
  };

  # Direnv
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # FZF
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

  # Neovim
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

  # Tmux
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

  # i3status configuration
  programs.i3status = {
    enable = true;
    general = {
      colors = true;
      interval = 5;
    };

    modules = {
      ipv6.enable = false;
      "wireless _first_".enable = false;
      "battery all".enable = false;

      "ethernet _first_" = {
        position = 1;
        settings = {
          format_up = "E: %ip (%speed)";
          format_down = "E: down";
        };
      };

      "disk /" = {
        position = 2;
        settings = {
          format = "/ %avail";
        };
      };

      "load" = {
        position = 3;
        settings = {
          format = "%1min";
        };
      };

      "memory" = {
        position = 4;
        settings = {
          format = "%used / %total";
          threshold_degraded = "1G";
          format_degraded = "MEMORY < %available";
        };
      };

      "tztime local" = {
        position = 5;
        settings = {
          format = "%Y-%m-%d %H:%M:%S";
        };
      };
    };
  };
}
