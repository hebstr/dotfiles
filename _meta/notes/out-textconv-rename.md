# Rename out-textconv to out-textconv.py

*2026-09-12T19:42:03Z by Showboat 0.6.1*
<!-- showboat-id: cde6cff0-7ba2-49d3-aa22-c4a46d346b80 -->

The textconv driver gains a .py extension so pyrefly check and Positron treat it as Python; both skip an extensionless file whatever its shebang. The script moves inside the bin stow package, then the package is restowed so ~/.local/bin carries the new link and loses the old one.

```bash
mv ~/dotfiles/bin/.local/bin/out-textconv ~/dotfiles/bin/.local/bin/out-textconv.py && ls ~/dotfiles/bin/.local/bin/ | rg out-textconv
```

```output
out-textconv.py
```

```bash
cd ~/dotfiles && stow -R bin && ls -la ~/.local/bin/ | rg out-textconv
```

```output
lrwxrwxrwx 1 julien julien       45 Sep 12 21:42 out-textconv.py -> ../../dotfiles/bin/.local/bin/out-textconv.py
```

Verify git resolves the driver to the renamed program.

```bash
git config --get diff.out-textconv.textconv && command -v out-textconv.py && ! command -v out-textconv
```

```output
out-textconv.py
/home/julien/.local/bin/out-textconv.py
```

The program then moves out of bin, where it was the only script with an extension and the only one nobody types, into the git stow package beside the config that calls it: stow git alone becomes the whole setup. Both packages are restowed so bin loses its link and ~/.config/git gains one.

```bash
mkdir -p ~/dotfiles/git/.config/git && mv ~/dotfiles/bin/.local/bin/out-textconv.py ~/dotfiles/git/.config/git/out-textconv.py && ls ~/dotfiles/git/.config/git/
```

```output
ignore
out-textconv.py
```

```bash
cd ~/dotfiles && stow -R bin git && ls -la ~/.config/git/ | rg out-textconv && ! ls ~/.local/bin/out-textconv.py 2>/dev/null
```

```output
lrwxrwxrwx  1 julien julien   46 Sep 12 21:58 out-textconv.py -> ../../dotfiles/git/.config/git/out-textconv.py
```

Verify git reads the driver by path from the config.

```bash
git config --get diff.out-textconv.textconv && ls -L ~/.config/git/out-textconv.py
```

```output
~/.config/git/out-textconv.py
/home/julien/.config/git/out-textconv.py
```
