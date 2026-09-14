VT7 OpenSSH S00 preflight

Test-VT7OpenSsh.ps1 is an MIT-licensed endpoint-independent diagnostic for the
S00 architecture gate. It executes an explicitly selected ssh.exe with raw
redirected standard streams and an isolated client configuration. The preflight
records executable identity and signature, inventories algorithms, verifies
stdout/stderr routing, and cancels a connection to a disposable stalled
loopback peer.

The preflight does not establish an SSH session and does not select a shipping
dependency. It cannot close the trust, authentication, remote byte, PTY size,
live window-change, or final-drain requirements. Those require an exact pinned
client and a controlled SSH endpoint.

No password, private key, agent socket, user SSH configuration or user
known-host file is read by the preflight cases. Explicit command-line settings
control the tested values, and the effective configuration is retained for
review. The diagnostic does not install a service, change the firewall, or
modify machine settings.
