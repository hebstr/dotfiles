# sshd in WSL on ju-TP2, port 2222, reached from ju-TP

*2026-09-18T23:39:44Z by Showboat 0.6.1*
<!-- showboat-id: bdc49780-7b47-4d64-a232-7dbb0817d207 -->

Step 4 of `.claude/DESIGN-SSH.md`, 2026-09-19. The changes ran on `ju-TP2` (WSL and its Windows host) and are reported by that machine's session; the commands are tilde fences so `verify` on `ju-TP` never runs them.

Server in WSL. Mirrored networking shares the port space with Windows, hence port 2222. `/etc/ssh/sshd_config.d/10-key-only.conf`, the only file in that directory:

~~~text
Port 2222
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
AllowUsers julien
~~~

`ssh.socket` enabled, listening on `0.0.0.0:2222` and `[::]:2222`, nothing on 22. Same trap as on `ju-TP`: a manual `sshd -t` fails with `Missing privilege separation directory: /run/sshd` until a first connection starts `ssh.service` (`RuntimeDirectory=sshd`); `sudo install -d -m 0755 /run/sshd` lets the check run.

Inbound through the Hyper-V firewall, which is required: WSL's Hyper-V policy is `DefaultInboundAction Block`. Measured against a temporary listener on 2222: without the rule the connection from `ju-TP` timed out and nothing reached WSL, with it the listener logged `accepted from 10.132.165.188`. Rule, from an elevated PowerShell on Windows (command rebuilt on `ju-TP` from the parameters `ju-TP2` reported, not copied from the run; the live rule, read back over `ssh ju-TP2` through `powershell.exe` on 2026-09-19, matches it field by field):

~~~text
New-NetFirewallHyperVRule -Name WSL-SSH-2222 -DisplayName WSL-SSH-2222 -Direction Inbound -Action Allow -Protocol TCP -LocalPorts 2222 -RemoteAddresses 10.0.0.0/8,172.16.0.0/12,192.168.0.0/16 -VMCreatorId '{40E0AC32-46A5-438A-A0B2-2B479E8F2E90}'
~~~

A reset of the Hyper-V firewall removes it and cuts access. Incident: the first creation, passed through `Start-Process` without quoting, produced a rule open to `Any` for about two minutes before being replaced; pass elevated commands with `-EncodedCommand` instead.

Client key: `ju-TP`'s dedicated `~/.ssh/id_ed25519_lan` (generated 2026-09-19, no passphrase, comment `julien@ju-TP lan`), public half as the single line of `ju-TP2`'s `~/.ssh/authorized_keys` (`600`, `~/.ssh` `700`). Host key `SHA256:nG11xJ2swjWjuiphyuaqDrSWXeu/qr/MwAUCxDXJIdg`, read on `ju-TP2` from the key file and matched on `ju-TP` by `ssh-keyscan` before the first connection, then by the `known_hosts` entry the first `ssh ju-TP2` recorded under `HostKeyAlias ju-TP2`.

Replayable from `ju-TP`, WSL on `ju-TP2` running: alias login, password refused, host key fingerprint.

```bash
ssh ju-TP2 hostname </dev/null 2>&1 | tr -d '\r'
```

```output
ju-TP2
```

```bash
ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o PubkeyAuthentication=no -p 2222 ju-TP2.local true 2>&1 | tr -d '\r' | sed 's/^[^:]*: //'
```

```output
Permission denied (publickey).
```

```bash
ssh-keyscan -t ed25519 -p 2222 ju-TP2.local 2>/dev/null | ssh-keygen -lf - | cut -d' ' -f2
```

```output
SHA256:nG11xJ2swjWjuiphyuaqDrSWXeu/qr/MwAUCxDXJIdg
```

Keep-alive, 2026-09-19, reported by `ju-TP2`'s session. Scheduled task `WSL-KeepAlive`, registered from an elevated PowerShell through `-EncodedCommand`:

~~~text
Action     C:\WINDOWS\System32\wsl.exe -d Ubuntu-24.04 --exec sleep infinity
Trigger    MSFT_TaskBootTrigger (at startup), Enabled
Principal  julien, LogonType S4U, RunLevel Limited (no stored password)
Settings   ExecutionTimeLimit PT0S, DisallowStartIfOnBatteries False, StopIfGoingOnBatteries False,
           StartWhenAvailable True, RestartCount 3, RestartInterval PT1M
~~~

Started by hand (`Start-ScheduledTask`) with a Windows session open: `State Running`, `LastTaskResult 267009` (`0x41301`, still running), `sleep infinity` running in WSL as `julien` with no terminal open. This proves S4U can launch `wsl.exe`, not yet that the boot trigger fires before any logon.

Reboot test, 2026-09-19: full Windows restart with no WSL terminal and no Claude Code opened. The Windows session opens automatically on this machine, so the test cannot tell the boot trigger from a logon; it does prove WSL comes back unattended. Observed from `ju-TP` over `ssh ju-TP2`: WSL kernel up at 02:01:10, `sleep infinity` as `julien` from 02:01:15, the SSH login as the only session.

```bash
ssh ju-TP2 'pgrep -u julien -fx "sleep infinity" >/dev/null && echo keep-alive running' </dev/null 2>&1 | tr -d '\r'
```

```output
keep-alive running
```
