# setup_guix.nu

# Check for required dependencies
if not (which wget) {
    echo "wget is required but not installed. Please install it first."
    exit 1
}

if not (which tar) {
    echo "tar is required but not installed. Please install it first."
    exit 1
}

if not (which gpg) {
    echo "gpg is required but not installed. Please install it first."
    exit 1
}

# Check if a specific version was passed as an argument
if ($args | empty?) {
    echo "No version specified. Fetching the latest version of GNU Guix..."

    # Fetch the latest version information from the GNU FTP server
    let latest_version_info = (wget -qO- "https://ftp.gnu.org/gnu/guix/" | from html | select href | where href =~ /guix-binary-[0-9]+\.[0-9]+\.[0-9]+/ | get href | split column '/' | last | regex replace 'guix-binary-([0-9\.]+)\.x86_64-linux\.tar\.xz' '$1')
    
    let version = ($latest_version_info | sort-by { $it } -r | first)
    echo $"Latest version detected: ($version)"
} else {
    # Use the specified version
    let version = ($args | first)
    echo $"Using specified version: ($version)"
}

# Define URLs for the tarball and its signature
let base_url = "https://ftp.gnu.org/gnu/guix"
let tarball = $"guix-binary-($version).x86_64-linux.tar.xz"
let signature = $"guix-binary-($version).x86_64-linux.tar.xz.sig"

# Create a temporary directory for the installation process
let tmp_dir = "/tmp/guix_install"
mkdir -p $tmp_dir
cd $tmp_dir

# Download the tarball and its signature
echo "Downloading GNU Guix binary..."
wget $"($base_url)/$tarball"
wget $"($base_url)/$signature"

# Verify the tarball using GPG
echo "Verifying the tarball with GPG..."
if not (gpg --verify $signature $tarball) {
    echo "Verification failed! The tarball may be compromised."
    exit 1
}

# Extract the tarball
echo "Extracting the tarball..."
tar -xf $tarball

# Install GNU Guix
echo "Installing GNU Guix..."
cd $"guix-binary-$version.x86_64-linux"
sudo ./install.sh

# Add Guix to the PATH
echo 'export PATH="/usr/local/var/guix/profiles/per-user/root/guix-profile/bin:$PATH"' | sudo tee -a /etc/profile > /dev/null
echo 'export GUIX_LOCPATH="/usr/local/var/guix/profiles/per-user/root/guix-profile/lib/locale"' | sudo tee -a /etc/profile > /dev/null

# Source the profile for the current session
source /etc/profile

# Clean up
echo "Cleaning up..."
cd /
rm -rf $tmp_dir

echo "GNU Guix installation is complete!"
