# setup_guix.nu
# Author: D.A.Pelasgus
#!/usr/bin/env nu.
    
# Set LANG environment variable
echo "Setting LANG to en_US.utf8"
$env.GITHUB_ENV | save --append $env.GITHUB_ENV "LANG=en_US.utf8"

# Download the GNU Guix tarball
echo "Downloading GNU Guix tarball"
wget https://ci.guix.gnu.org/search/latest/archive?query=spec:tarball+status:success+system:x86_64-linux+guix-binary.tar.xz -O guix-binary-nightly.x86_64-linux.tar.xz --no-verbose

# Extract and install Guix
echo "Installing GNU Guix"
sudo tar --extract --file "guix-binary-nightly.x86_64-linux.tar.xz" -C / --no-overwrite-dir
sudo groupadd --system guixbuild

for i in (seq 1 10) {
    let user_name = $"guixbuilder$(printf '%02d' $i)"
    sudo useradd -g guixbuild -G guixbuild -d /var/empty -s (which nologin) -c $"Guix build user $i" --system $user_name
}

let guix_path = "/var/guix/profiles/per-user/root/current-guix"
sudo cp $"${guix_path}/lib/systemd/system/gnu-store.mount" /etc/systemd/system/
sudo cp $"${guix_path}/lib/systemd/system/guix-daemon.service" /etc/systemd/system/
sudo chmod 664 /etc/systemd/system/gnu-store.mount /etc/systemd/system/guix-daemon.service
sudo systemctl daemon-reload
sudo systemctl enable --now gnu-store.mount guix-daemon.service

echo $"$guix_path/bin" | save --append $env.GITHUB_PATH

# Authorize the build farm
echo "Authorizing the build farm"
for file in (ls /var/guix/profiles/per-user/root/current-guix/share/guix/*.pub) {
    sudo "/var/guix/profiles/per-user/root/current-guix/bin/guix" archive --authorize < $file.path
}

# Generate Guix keys
echo "Generating Guix keys"
sudo "/var/guix/profiles/per-user/root/current-guix/bin/guix" archive --generate-key

# Create channel file
echo "Creating Guix channel file"
let channels_content = $input.channels
open $env.RUNNER_TEMP/channels.scm --raw --out (nu -c echo $"${channels_content}")

# Update Guix if requested
if $input.pullAfterInstall == "true" {
    echo "Updating Guix"
    sudo "/var/guix/profiles/per-user/root/current-guix/bin/guix" pull --fallback -C $"$env.RUNNER_TEMP/channels.scm"
}

# Describe channels and export to GitHub output
echo "Describing Guix channels"
"/var/guix/profiles/per-user/root/current-guix/bin/guix" describe -f channels | str replace '\n' ' ' | echo | append "channels=" | save --append $env.GITHUB_OUTPUT

