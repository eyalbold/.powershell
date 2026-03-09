# PowerShell Profile

Personal PowerShell profile and modules for Windows, with productivity utilities, git helpers, WSL integration, and more.

## Structure

```
PowerShell/
├── Microsoft.PowerShell_profile.ps1   # Main profile loaded on every session
├── secret.ps1                          # Private config/credentials (not tracked)
└── Modules/
    └── Microsoft.PowerToys.Configure/ # DSC module for PowerToys configuration
```

## Aliases

| Alias  | Maps To              | Description                                  |
|--------|----------------------|----------------------------------------------|
| `ss`   | `Select-String`      | Grep-like string search                      |
| `grep` | `Select-String`      | Grep-like string search                      |
| `z`    | `Get-Help`           | Quick help lookup                            |
| `m`    | `Get-Member`         | Inspect object members                       |
| `cd`   | `MyCD`               | Custom cd that records history               |
| `q`    | `CdLast`             | Jump to a previously visited directory       |
| `gitp` | `GitPullKeepLocal`   | Git pull keeping local changes               |

## Key Bindings (PSReadLine)

| Key       | Action                                                        |
|-----------|---------------------------------------------------------------|
| `Alt+q`   | Jump to a previously visited directory (fuzzy via fzf)       |
| `Alt+e`   | Insert a command previously run in the **current** directory  |
| `Alt+h`   | Fuzzy-search the full global command history                  |

## Functions

### Navigation & History

| Function       | Description                                                                 |
|----------------|-----------------------------------------------------------------------------|
| `MyCD`         | Wraps `Set-Location`, records every navigation in PSReadLine history        |
| `CdLast`       | Pick a previously visited directory via fzf and jump to it                  |
| `StupidHist`   | Returns list of previously visited directories from history                  |
| `SimpHist`     | Fuzzy-search full command history (returns selected entry)                   |
| `SimpHistEx`   | Like `SimpHist` but immediately executes the selected command                |
| `GrepOnCurDir` | Fuzzy-select a command previously run in the current directory               |

### File & Search

| Function        | Description                                                               |
|-----------------|---------------------------------------------------------------------------|
| `Find`          | Unix-like `find`: filter by name, type, path; supports `-exec` callbacks  |
| `FindFileRg`    | Recursively find files and search their contents with ripgrep              |
| `FindGitFile`   | Show full git log for a file, following renames (`git log --follow`)       |
| `Which`         | Locate the full path of an executable (like Unix `which`)                  |
| `Get-MD5`       | Compute MD5 hash of a string or file                                       |

### Git Utilities

| Function                        | Description                                                        |
|---------------------------------|--------------------------------------------------------------------|
| `Checkout-FileWithDifferentName`| Checkout a file from a branch and save it under a new name        |
| `GetGitStash`                   | List current git stashes                                           |
| `CheckCommit`                   | Inspect a commit by number or line                                 |
| `RemoveCommit`                  | Remove a specific commit                                           |
| `ExtractFromLastStash`          | Pull a single file out of the last stash                           |
| `Checkout-FileFromStash`        | Checkout a file from a named stash                                 |
| `StashAll`                      | Stash all changes with a name                                      |
| `FilesInCommit`                 | List files changed in a specific commit                            |

### Process & Window Management

| Function            | Description                                                             |
|---------------------|-------------------------------------------------------------------------|
| `Show-Window`       | Bring a process window to the foreground (restore if minimized)        |
| `Get-LockingProcess`| Find processes locking a file (uses Sysinternals `handle.exe`)         |
| `KillByName`        | Kill all processes matching a name pattern                              |

### WSL Integration

| Function        | Description                                       |
|-----------------|---------------------------------------------------|
| `TranslatePath` | Convert a WSL/Linux path to a Windows path        |
| `RunBash`       | Execute a command in WSL with bash profile loaded |
| `RestartWsl`    | Restart the WSL service (`LxssManager`)           |

### Hyper-V / VM

| Function                    | Description                                              |
|-----------------------------|----------------------------------------------------------|
| `ConVM`                     | Open a PSSession to the local `win10` Hyper-V VM        |
| `copy-foldertovirtualmachine`| Copy a folder's contents into a Hyper-V VM             |
| `NewVMDrive`                | Create a new VM drive                                    |

### Neovim

| Function     | Description                                            |
|--------------|--------------------------------------------------------|
| `ClearShada` | Clear neovim shada files and restart neovim-qt         |
| `UpdateVim`  | Download and install a neovim release from GitHub      |

### Data & Utilities

| Function                   | Description                                                               |
|----------------------------|---------------------------------------------------------------------------|
| `IIF`                      | Inline ternary: `IIF $cond $true $false`                                  |
| `ConvertPSObjectToHashtable`| Recursively convert a PSObject/JSON result to a hashtable                |
| `Get-Histogram`            | Generate a histogram (with optional ASCII visualization) from pipeline data|
| `Select-Zip` / `Tuple-Zip` | Zip two collections together element-by-element                           |
| `Ext2`                     | Run a script block in a new PowerShell window                             |
| `DebugIt`                  | Debug helper                                                              |
| `Add-ToPath`               | Permanently add a directory to the system PATH                            |
| `Format-ErrorWithStackTrace`| Format an error record with enhanced stack trace and source lines        |

### Dynamic Parameter Helpers

| Function          | Description                                                              |
|-------------------|--------------------------------------------------------------------------|
| `AddWrapper`      | Build a `DynamicParam` dictionary forwarding params from another function|
| `GetRestOfParams` | Filter a bound-params hashtable to only those accepted by a target function|
| `Let` / `Get`     | Wrapper functions using dynamic parameter forwarding                     |

## Modules

### Microsoft.PowerToys.Configure

A PowerShell DSC module for configuring PowerToys settings declaratively. Covers:

- **AdvancedPaste** – AI paste, clipboard preview, shortcuts
- **Awake** – keep-awake modes (Passive, Indefinite, Timed, Expirable)
- **ColorPicker** – activation actions, click behavior
- **Hosts** – hosts file editor settings
- **PowerAccent** – accent character activation key
- And many more PowerToys modules

## Dependencies

- [fzf](https://github.com/junegunn/fzf) — fuzzy finder (used by history/navigation functions)
- [ripgrep (`rg`)](https://github.com/BurntSushi/ripgrep) — fast file content search
- [Sysinternals handle.exe](https://learn.microsoft.com/en-us/sysinternals/downloads/handle) — for `Get-LockingProcess`
- [neovim-qt](https://github.com/equalsraf/neovim-qt) — for Neovim-related functions
- WSL (Ubuntu) — for WSL integration functions
