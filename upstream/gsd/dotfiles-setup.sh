#!/bin/bash
# Dotfiles Setup Script
# Run this to create and initialize your dotfiles repo

set -e

DOTFILES_DIR="$HOME/Documents/projects/dotfiles"

echo "Creating dotfiles repo at $DOTFILES_DIR..."

# Create the repo directory
mkdir -p "$DOTFILES_DIR"
cd "$DOTFILES_DIR"

# Initialize git
git init

# Copy current dotfiles (preserving originals as backup)
echo "Copying dotfiles..."

for file in .zshrc .tmux.conf .gitconfig .vimrc .bashrc; do
    if [ -f "$HOME/$file" ]; then
        cp "$HOME/$file" "$DOTFILES_DIR/$file"
        echo "  ✓ Copied $file"
    fi
done

# Copy directories
for dir in .claude .ssh/config; do
    if [ -e "$HOME/$dir" ]; then
        if [ -d "$HOME/$dir" ]; then
            cp -r "$HOME/$dir" "$DOTFILES_DIR/$(basename $dir)"
            echo "  ✓ Copied $dir/"
        else
            mkdir -p "$DOTFILES_DIR/$(dirname $dir)"
            cp "$HOME/$dir" "$DOTFILES_DIR/$dir"
            echo "  ✓ Copied $dir"
        fi
    fi
done

# Create .gitignore
cat > "$DOTFILES_DIR/.gitignore" << 'EOF'
# Secrets - never commit these
.ssh/id_*
.ssh/*.pem
.env
*_secret*
*_token*
*.key

# OS files
.DS_Store
*.swp
*.swo

# Claude sessions (can be large)
.claude/sessions/
.claude/statsig/
EOF

# Create install script for new machines
cat > "$DOTFILES_DIR/install.sh" << 'EOF'
#!/bin/bash
# Install dotfiles on a new machine
# Usage: ./install.sh

set -e

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Installing dotfiles from $DOTFILES_DIR..."

# Symlink each dotfile
for file in .zshrc .tmux.conf .gitconfig .vimrc .bashrc; do
    if [ -f "$DOTFILES_DIR/$file" ]; then
        if [ -f "$HOME/$file" ] && [ ! -L "$HOME/$file" ]; then
            echo "  Backing up existing $file to $file.backup"
            mv "$HOME/$file" "$HOME/$file.backup"
        fi
        ln -sf "$DOTFILES_DIR/$file" "$HOME/$file"
        echo "  ✓ Linked $file"
    fi
done

echo ""
echo "✓ Dotfiles installed!"
echo "  Restart your shell or run: source ~/.zshrc"
EOF

chmod +x "$DOTFILES_DIR/install.sh"

# Initial commit
git add -A
git commit -m "Initial dotfiles commit"

echo ""
echo "✓ Dotfiles repo created at $DOTFILES_DIR"
echo ""
echo "Next steps:"
echo "  1. cd $DOTFILES_DIR"
echo "  2. Review files and remove any secrets"
echo "  3. Create a GitHub repo and push:"
echo "     git remote add origin git@github.com:YOUR_USERNAME/dotfiles.git"
echo "     git push -u origin main"
echo ""
echo "To install on a new machine:"
echo "  git clone git@github.com:YOUR_USERNAME/dotfiles.git ~/Documents/projects/dotfiles"
echo "  cd ~/Documents/projects/dotfiles && ./install.sh"
