#!/usr/bin/env bash

release_dir="/srv/app/releases/$(date +%Y%m%d%H%M%S)"
tmp_dir=$(mktemp -d)

git clone --depth 1 "https://example.invalid/app.git" "$tmp_dir"
mkdir -p "$release_dir"
cp -r "$tmp_dir"/* "$release_dir"
ln -sfn "$release_dir" /srv/app/current
systemctl restart app
rm -rf "$tmp_dir"
echo "deployed $release_dir"
