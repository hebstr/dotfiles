# sshd on ju-TP, key-only, for LAN access from ju-TP2

*2026-09-18T22:34:57Z by Showboat 0.6.1*
<!-- showboat-id: d14b2f12-28de-4baf-aeab-25929aead3e6 -->

Step 1 of `.claude/DESIGN-SSH.md`, done 2026-09-19. The steps below need `sudo` and live outside stow (`/etc`), so they are recorded as tilde fences and never re-run by `verify`.

Install the server. Ubuntu 24.04 socket-activates it: `ssh.socket` is enabled and listening, `ssh.service` stays disabled and starts per connection.

~~~text
sudo apt install -y openssh-server
~~~

Observed: `openssh-server 1:9.6p1-3ubuntu13.19`.

Key-only drop-in. `sshd` keeps the first value read per keyword and drop-ins load in lexical order, hence the `10-` prefix (no `50-cloud-init.conf` exists here, the prefix is defensive).

~~~text
sudo install -m 644 -o root -g root 10-key-only.conf /etc/ssh/sshd_config.d/10-key-only.conf
~~~

Content of `/etc/ssh/sshd_config.d/10-key-only.conf`:

~~~text
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
AllowUsers julien
~~~

`sudo sshd -t` fails with `Missing privilege separation directory: /run/sshd` until a first connection has started `ssh.service`, whose `RuntimeDirectory=sshd` creates it. Not a config error; `sudo install -d -m 0755 /run/sshd` lets the check run.

No firewall rule. `systemctl is-active ufw` answers `active`, but that is the unit that loads rules at boot: `sudo ufw status verbose` reads `Status: inactive` (checked 2026-09-19), so no host firewall filters anything on `ju-TP`. The two `ufw limit` rules planned for port 22 were never applied, and none is needed while `ufw` stays off. Exposure is limited instead by the socket filter recorded at the end of this trace.

Client key: `ju-TP2`'s dedicated `~/.ssh/id_ed25519_lan.pub`, appended to `~/.ssh/authorized_keys` (mode `600`).

Replayable checks: listener, the single authorized key, password auth refused, host key fingerprint to compare against the first connection from `ju-TP2`.

```bash
ss -ltnH '( sport = :22 )' | awk '{print $4}'
```

```output
0.0.0.0:22
[::]:22
```

```bash
ssh-keygen -lf ~/.ssh/authorized_keys
```

```output
256 SHA256:3Z+RfsOTXDuUeZVmDohl+9o7eFJBbI9cRnbXBf4AyYo julien@ju-TP2 lan (ED25519)
```

```bash
ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o PreferredAuthentications=password,keyboard-interactive localhost true 2>&1 | tr -d '\r' | sed 's/^[^:]*: //'
```

```output
Permission denied (publickey).
```

```bash
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

```output
256 SHA256:064LEYERgabbG6y0EPopEkbaT/D+UkLt8K9i188RG6Q root@ju-TP (ED25519)
```

Criterion met 2026-09-19: from `ju-TP2`, `ssh -i ~/.ssh/id_ed25519_lan -o IdentitiesOnly=yes -o BatchMode=yes julien@10.132.165.188 ...` runs non-interactively.

Socket filter, 2026-09-19 (decision in `.claude/DESIGN-SSH.md`, section on `ssh.socket`). With `ufw` inactive, `sshd` answered on every network the laptop joins; a systemd drop-in on the socket drops packets from any address outside the private ranges and loopback before `sshd` is spawned. `sudo` steps, never re-run by `verify`:

~~~text
sudo install -d -m 0755 /etc/systemd/system/ssh.socket.d
sudo install -m 644 -o root -g root 10-lan-only.conf /etc/systemd/system/ssh.socket.d/10-lan-only.conf
sudo systemctl daemon-reload
sudo systemctl restart ssh.socket
~~~

Measured first with a test version that left `localhost` out of the allow list: `ssh 127.0.0.1` and `ssh ::1` got `Connection timed out`, not `Permission denied`, while `ju-TP2` still logged in over the LAN. The filter set on the socket unit therefore reaches the connections the socket-activated `sshd` accepts (`Accept=no`). The final version below adds `localhost` back.

`sshd` must stay socket-activated: a permanent `ssh.service` without `ssh.socket` would drop the filter silently.

```bash
cat /etc/systemd/system/ssh.socket.d/10-lan-only.conf
```

```output
[Socket]
IPAddressDeny=any
IPAddressAllow=10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 localhost
```

```bash
systemctl show ssh.socket -p IPAddressAllow --value | tr ' ' '\n' | sort
```

```output
10.0.0.0/8
::1/128
127.0.0.0/8
172.16.0.0/12
192.168.0.0/16
```
