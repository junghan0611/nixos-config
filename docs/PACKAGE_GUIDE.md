# Package Installation Guide

This guide explains how to add packages to this NixOS configuration, especially when requesting package installations from AI agents.

## Table of Contents

- [Package Locations](#package-locations)
- [Adding Packages from Stable Channel](#adding-packages-from-stable-channel)
- [Adding Packages from Unstable Channel](#adding-packages-from-unstable-channel)
- [System vs User Packages](#system-vs-user-packages)
- [Requesting Package Installation from AI Agents](#requesting-package-installation-from-ai-agents)

## Package Locations

### User Packages (Home Manager)
- **File**: `users/junghan/home-manager.nix`
- **Use for**: User-specific applications, CLI tools, development tools
- **Example**: bat, eza, fd, ripgrep, lazygit, etc.

### System Packages
- **File**: `machines/shared.nix`
- **Use for**: System-wide tools, services, libraries
- **Example**: vim, wget, curl, htop, gcc, etc.

## Adding Packages from Stable Channel

For packages from the stable nixpkgs (25.05), simply add them to the appropriate package list:

```nix
home.packages = with pkgs; [
  # CLI tools
  bat
  eza
  fd

  # Add new stable package here
  neofetch
];
```

## Adding Packages from Unstable Channel

For packages that need the latest versions, use the unstable channel via overlays:

### Step 1: Add to Overlay (flake.nix)

```nix
overlays = [
  (final: prev: {
    # Use unstable packages where needed
    ghostty = inputs.nixpkgs-unstable.legacyPackages.${prev.system}.ghostty;

    # Add your unstable package here
    your-package = inputs.nixpkgs-unstable.legacyPackages.${prev.system}.your-package;
  })
];
```

### Step 2: Add to Package List

Then add the package to your package list in `users/junghan/home-manager.nix` or `machines/shared.nix`:

```nix
home.packages = with pkgs; [
  # Your unstable package is now available
  your-package
];
```

## System vs User Packages

### Use User Packages (home-manager.nix) when:
- Package is user-specific (personal tools, preferences)
- Package doesn't require system-level permissions
- You want different users to have different versions
- Examples: terminal tools, editors, development tools

### Use System Packages (shared.nix) when:
- Package needs to be available system-wide
- Package requires system services or permissions
- Package is a fundamental system tool
- Examples: compilers, system utilities, network tools

## Requesting Package Installation from AI Agents

When asking an AI agent to install packages, provide clear information:

### Good Request Example

```
I need to add these packages from unstable channel:
- package-name-1
- package-name-2
- package-name-3

Please add them to my user packages in home-manager.
```

### Key Information to Provide

1. **Package names**: Exact names from nixpkgs
2. **Channel preference**: Stable (default) or unstable
3. **Location preference**: User packages or system packages
4. **Purpose** (optional): Helps the agent categorize correctly

### Verification

After installation, verify package names at:
- NixOS Search: https://search.nixos.org/packages
- Confirm channel: Check if package exists in stable or only in unstable

## Applying Changes

After packages are added to the configuration:

### For System Packages
```bash
sudo nixos-rebuild switch --flake .#<hostname>
```

### For User Packages Only
```bash
home-manager switch --flake .#<hostname>
```

### For Everything
```bash
sudo nixos-rebuild switch --flake .#<hostname>
# This rebuilds both system and home-manager
```

## Example: Recent AI CLI Tools Installation

On 2025-11-17, the following AI CLI tools were added from unstable:

1. Added to overlay in `flake.nix`:
```nix
# AI CLI tools from unstable
gemini-cli = inputs.nixpkgs-unstable.legacyPackages.${prev.system}.gemini-cli;
codex = inputs.nixpkgs-unstable.legacyPackages.${prev.system}.codex;
opencode = inputs.nixpkgs-unstable.legacyPackages.${prev.system}.opencode;
claude-code = inputs.nixpkgs-unstable.legacyPackages.${prev.system}.claude-code;
claude-code-monitor = inputs.nixpkgs-unstable.legacyPackages.${prev.system}.claude-code-monitor;
claude-code-acp = inputs.nixpkgs-unstable.legacyPackages.${prev.system}.claude-code-acp;
claude-code-router = inputs.nixpkgs-unstable.legacyPackages.${prev.system}.claude-code-router;
```

2. Added to user packages in `users/junghan/home-manager.nix`:
```nix
# AI CLI tools (from unstable)
gemini-cli
codex
opencode
claude-code
claude-code-monitor
claude-code-acp
claude-code-router
```

## Troubleshooting

### Package not found
- Verify package name at https://search.nixos.org/packages
- Check if package is only available in unstable channel
- Ensure overlay is properly configured

### Build errors
- Check if package requires specific system architecture
- Review package dependencies
- Try updating flake inputs: `nix flake update`

### Package outdated
- If using stable channel, consider switching to unstable for that package
- Update flake inputs: `nix flake update`

## Best Practices

1. **Use stable by default**: Only use unstable when you need latest features
2. **Document reasons**: Add comments explaining why unstable is needed
3. **Group related packages**: Keep packages organized by category
4. **Test after adding**: Always rebuild and test after adding packages
5. **Update CHANGELOG**: Document package additions for version tracking
