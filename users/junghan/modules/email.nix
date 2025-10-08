# Email configuration (mu4e + mbsync)
# Based on ElleNajit's setup
{ config, lib, pkgs, ... }:

{
  # mbsync configuration for Gmail
  home.file.".mbsyncrc".text = ''
    # ACCOUNT INFORMATION
    IMAPAccount gmail
    Host imap.gmail.com
    User junghanacs@gmail.com
    PassCmd "pass show personal/email/junghanacs-gmail/app-password"
    AuthMechs LOGIN
    SSLType IMAPS
    CertificateFile ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt

    # REMOTE STORAGE
    IMAPStore gmail-remote
    Account gmail

    # LOCAL STORAGE
    MaildirStore gmail-local
    Path ~/Maildir/
    Inbox ~/Maildir/INBOX

    # CHANNELS
    Channel gmail-inbox
    Far :gmail-remote:
    Near :gmail-local:
    Patterns "INBOX"
    Create Both
    Expunge Both
    SyncState *
    MaxMessages 1000
    MaxSize 200k
    ExpireUnread yes

    Channel gmail-trash
    Far :gmail-remote:"[Gmail]/Bin"
    Near :gmail-local:"[Gmail].Bin"
    Create Both
    Expunge Both
    SyncState *
    MaxMessages 100
    MaxSize 200k
    ExpireUnread yes

    Channel gmail-sent
    Far :gmail-remote:"[Gmail]/Sent Mail"
    Near :gmail-local:"[Gmail].Sent Mail"
    Create Both
    Expunge Both
    SyncState *
    MaxMessages 100
    MaxSize 200k
    ExpireUnread yes

    # GROUPS
    Group gmail
    Channel gmail-inbox
    Channel gmail-trash
    Channel gmail-sent
  '';

  # Create Maildir directories on activation
  home.activation.createMailDirs = lib.hm.dag.entryAfter ["writeBoundary"] ''
    $DRY_RUN_CMD mkdir -p ${config.home.homeDirectory}/Maildir/{INBOX,cur,new,tmp}
    $DRY_RUN_CMD mkdir -p ${config.home.homeDirectory}/Maildir/[Gmail].{Bin,Sent\ Mail}/{cur,new,tmp}
  '';
}
