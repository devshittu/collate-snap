

# Manual Installation to `~/.local/bin`

If you prefer not to use the snap and want to install `collate.sh` directly in `~/.local/bin`, follow these steps. This is simpler and avoids snap confinement.

1. **Copy `collate.sh` to `~/.local/bin`**:
   - Your `~/.zshrc` already includes `~/.local/bin` in your `PATH` (line 157). Copy the script:

     ```bash
     mkdir -p ~/.local/bin
     cp collate.sh ~/.local/bin/collate
     chmod +x ~/.local/bin/collate
     ```

2. **Create `col8` Alias**:
   - Since your `snapcraft.yaml` defines `col8` as an alias, replicate this by creating a symlink:

     ```bash
     ln -s ~/.local/bin/collate ~/.local/bin/col8
     ```

   - Alternatively, add an alias in `~/.zshrc`:

     ```bash
     echo 'alias col8="collate"' >> ~/.zshrc
     source ~/.zshrc
     ```

3. **Handle Configuration File**:
   - Your `snapcraft.yaml` places `config.yaml` in `/etc/collate/config.yaml`. For user-space installation, place it in a user-writable directory (e.g., `~/.collate`):

     ```bash
     mkdir -p ~/.collate
     cp config.yaml ~/.collate/config.yaml
     ```

   - Modify `collate.sh` to look for `~/.collate/config.yaml` instead of `/etc/collate/config.yaml`. Open `collate.sh`:

     ```bash
     nano collate.sh
     ```

   - Replace any reference to `/etc/collate/config.yaml` with `$HOME/.collate/config.yaml`. For example, change:

     ```bash
     CONFIG_FILE="/etc/collate/config.yaml"
     ```

     to:

     ```bash
     CONFIG_FILE="$HOME/.collate/config.yaml"
     ```

4. **Handle Icon (Optional)**:
   - The `snap/gui/icon.png` is used for the snap’s GUI. If your script doesn’t need it, skip this. Otherwise, place it in a user directory (e.g., `~/.collate/icon.png`) and update `collate.sh` to reference it if necessary.

5. **Verify Dependencies**:
   - Your `snapcraft.yaml` lists `bash`, `coreutils`, `findutils`, `sed`, and `grep` as dependencies. These are standard on Ubuntu 24.04. Confirm they’re installed:

     ```bash
     dpkg -l | grep -E 'bash|coreutils|findutils|sed|grep'
     ```

   - If any are missing, install them:

     ```bash
     sudo apt install bash coreutils findutils sed grep
     ```

6. **Test Commands**:
   - Verify `collate` and `col8` work:

     ```bash
     collate --help
     col8 --help
     ```

   - Test in a different project directory to confirm global access:

     ```bash
     cd ~/some-other-project
     collate --help
     ```

#### Step 3: Ensure Global Access

Your `~/.zshrc` already includes `~/.local/bin` in the `PATH`, so `collate` and `col8` should be accessible everywhere. Double-check:

1. **Verify PATH**:
   - Confirm `~/.local/bin` is in your `PATH`:

     ```bash
     echo $PATH
     ```

   - You should see `/home/mshittu/.local/bin` in the output.

2. **Reload Shell**:
   - If you made changes to `~/.zshrc`, reload it:

     ```bash
     source ~/.zshrc
     ```

#### Step 4: Test in a Project

- Navigate to a project directory and test `collate`:

  ```bash
  cd ~/some-project
  collate --some-option
  col8 --some-option
  ```

- Ensure it reads `~/.collate/config.yaml` (or your project-specific `.collate/config.yaml`) as expected.

#### Step 5: Cleanup (Optional)

- If you used the snap method but prefer the manual method, remove the snap:

  ```bash
  sudo snap remove collate
  ```

- If you decide to publish to the Snap Store later, you can follow the previous guide’s publishing steps.

---

### Updated `collate.sh` Example (If Needed)

If `collate.sh` needs adjustments for user-space usage, here’s an example of how it might look to support `~/.collate/config.yaml`:

```x-shellscript
#!/bin/bash

# Collate: Combine files recursively into a single output file
CONFIG_FILE="$HOME/.collate/config.yaml"

# Check if config file exists
if [ -f "$CONFIG_FILE" ]; then
  echo "Using config: $CONFIG_FILE"
  # Add logic to read config (e.g., parse YAML with grep/sed)
else
  echo "Config file not found at $CONFIG_FILE, using defaults"
fi

# Example logic (replace with your actual script)
echo "Running Collate utility..."
# Add your file combination logic here
```

- Save this to `~/.local/bin/collate` and ensure it’s executable:

  ```bash
  chmod +x ~/.local/bin/collate
  ```

---

### Notes

- **Snap vs. Manual Installation**:
  - **Snap**: Easier to manage dependencies and confinement, but requires snapd and may involve stricter permissions. Suitable if you want a packaged solution.
  - **Manual**: Simpler for user-space usage, avoids snapd, but requires manual dependency management and config path updates.
- **Alias `col8`**: The symlink (`ln -s`) or `~/.zshrc` alias ensures `col8` works as expected.
- **Config Path**: Using `~/.collate/config.yaml` avoids permission issues with `/etc/collate/config.yaml` in strict confinement or user-space setups.
- **Dependencies**: Your script’s dependencies (`bash`, `coreutils`, etc.) are standard, so no additional setup is needed unless `collate.sh` requires other tools.

---

### Troubleshooting

- **Command Not Found**:
  - If `collate` or `col8` aren’t found, verify `~/.local/bin` is in `PATH`:

    ```bash
    echo $PATH
    ```

  - Ensure the files are executable:

    ```bash
    ls -l ~/.local/bin/collate ~/.local/bin/col8
    ```

- **Script Errors**:
  - If `collate` fails, check for errors in `collate.sh` or missing dependencies. Share the error output.
- **Config Issues**:
  - If `collate` can’t find `~/.collate/config.yaml`, verify the path in `collate.sh` and the file’s existence:

    ```bash
    ls -l ~/.collate/config.yaml
    ```

- **Snap Issues**:
  - If the snap installation fails, share the error from:

    ```bash
    sudo snap install --dangerous collate_0.1.0_amd64.snap
    ```

---

### Summary of Commands

```bash
# Option 1: Install snap locally
sudo snap install --dangerous collate_0.1.0_amd64.snap
collate --help
col8 --help

# Option 2: Manual installation
mkdir -p ~/.local/bin
cp collate.sh ~/.local/bin/collate
chmod +x ~/.local/bin/collate
ln -s ~/.local/bin/collate ~/.local/bin/col8
mkdir -p ~/.collate
cp config.yaml ~/.collate/config.yaml
nano ~/.local/bin/collate  # Update CONFIG_FILE to $HOME/.collate/config.yaml
collate --help
col8 --help

# Verify PATH
echo $PATH
source ~/.zshrc
```

---

### Next Steps

- Choose **Option 1 (snap)** or **Option 2 (manual)** based on your preference.
- Test `collate` and `col8` in a project directory.
- If you encounter errors, share:
  - Error messages from running `collate` or `col8`.
  - Output of `ls -l ~/.local/bin/collate ~/.local/bin/col8` (if using manual).
  - Contents of `collate.sh` (redact sensitive parts) if it fails.
- If you later decide to publish to the Snap Store, let me know, and I can revisit the LXD networking issue or publishing steps.

Let me know how it goes or if you need help with specific errors!
