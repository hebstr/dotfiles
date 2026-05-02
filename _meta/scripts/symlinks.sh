#!/usr/bin/env bash
# R
RPROFILE="$HOME/dotfiles/_meta/templates/Rprofile.site"
sudo ln -sf "$RPROFILE" /opt/R/4.5.3/lib/R/etc/Rprofile.site
sudo ln -sf "$RPROFILE" /opt/R/4.6.0/lib/R/etc/Rprofile.site
