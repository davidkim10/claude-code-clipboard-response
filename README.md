# Claude Code Response Copier

A Claude Code hook that adds a `-copy` command to quickly copy Claude's responses to your clipboard. 

The command name `-copy` is now configurabled. Just set your `COMMAND_NAME` variable. Avoid prefixing with `\` as this may result to `unknown slash command` error in Claude code.

![Demo](img/demo.gif)

## Features

- **Quick Copy**: `-copy` copies the latest response
- **Numbered Access**: `-copy 3` copies a specific response
- **List Responses**: `-copy -ls` shows available responses with previews
- **Search Responses**: `-copy -f keyword` finds responses containing text
- **Regex Search**: `-copy -fr pattern` finds responses matching a regex pattern
- **Debug Mode**: `-copy -debug` shows response details with byte/char count
- **Timestamps**: Shows when each response was created
- **Cross-Platform**: Works on macOS, Linux, and Windows/WSL

## Installation

1. **Download the script:**

   ```bash
   curl -o copy-claude-response https://raw.githubusercontent.com/Twizzes/copy-claude-response/main/copy-claude-response
   chmod +x copy-claude-response
   ```

2. **Place it somewhere in your PATH** (or note the full path):

   ```bash
   mv copy-claude-response ~/.local/bin/
   ```

3. **Configure the hook** in your Claude Code settings (`~/.claude/settings.json`):

   ```json
   {
     "hooks": {
       "UserPromptSubmit": [
         {
           "hooks": [
             {
               "type": "command",
               "command": "/path/to/copy-claude-response"
             }
           ]
         }
       ]
     }
   }
   ```

## Usage

### Basic Commands

| Command | Description |
|---------|-------------|
| `-copy` | Copy the latest Claude response |
| `-copy 2` | Copy response #2 |
| `-copy -ls` | List last 10 responses with previews |
| `-copy -ls 5` | List last 5 responses |
| `-copy -f error` | Find responses containing "error" |
| `-copy -fr "error.*fix"` | Find responses matching regex pattern |
| `-copy -debug` | Show latest response with byte/char stats |
| `-copy -debug 3` | Show response #3 with stats |

### Examples

**Copy latest response:**

```
-copy
```

> Latest response copied!

**List recent responses:**

```
-copy -ls
```

```
Responses (1-3, showing 3):
    1 [  2m ago]: Here's the updated function with error handling...
    2 [ 15m ago]: I'll help you debug this issue. First, let's check...
    3 [  1h ago]: To implement this feature, we need to modify...
```

**Search for specific content:**

```
-copy -f git commit
```

```
Searching for "git commit":
    2 [ 15m ago]: I'll help you debug this issue. First, let's check...
    5 [  2h ago]: You can create a git commit using the following...
Found 2 matches
```

**Regex search:**

```
-copy -fr "TODO|FIXME"
```

```
Regex search for "TODO|FIXME":
    3 [ 10m ago]: // TODO: Add error handling here...
    7 [  1h ago]: // FIXME: This needs refactoring...
Found 2 matches
```

**Debug a response:**

```
-copy -debug
```

```
=== DEBUG ===
Here's the updated function with error handling...

Bytes: 1234
Chars: 1200
```

## How It Works

The script:

1. **Intercepts** `-copy` commands before Claude processes them
2. **Parses** the conversation transcript to extract Claude's responses
3. **Groups** multi-part responses by request ID for complete responses
4. **Copies** the selected response to your system clipboard
5. **Blocks** the command from reaching Claude to prevent confusion

## Platform Support

- **macOS**: Uses `pbcopy`
- **Linux**: Uses `xclip` (install with `sudo apt install xclip`)
- **Windows/WSL**: Uses `clip.exe` via PowerShell for proper UTF-8 handling

## Troubleshooting

**Hook not working?**

- Run `/hooks` in Claude Code to verify the hook is registered
- Check that the script path is correct and executable
- Use `claude --debug` to see hook execution details

**Clipboard not working?**

- **Linux**: Install xclip: `sudo apt install xclip`
- **WSL**: Ensure Windows clipboard integration is enabled

**No responses found?**

- The script only finds text responses from Claude
- Responses with only tool calls won't appear in the list

**Hook not triggering?**

- Avoid renaming your `COMMAND_NAME` with a `/` prefix. This may result in `unknown slash command {YOUR_COMMAND_NAME}`

## Limitations

- Only copies text responses from Claude (responses with only tool calls won't appear)
- The slash command WILL NOT AUTO-COMPLETE, this is because we are hooking UserPromptSubmission, which slash commands (that exist) do not trigger
- Requires `jq` for JSON parsing
- Platform-specific clipboard utilities must be installed

## Requirements

- Claude Code with hooks support
- Bash shell
- `jq` for JSON parsing
- Platform-specific clipboard utility (pbcopy/xclip/clip.exe)

## Testing

This project uses [Bats](https://github.com/bats-core/bats-core) (Bash Automated Testing System) for unit tests.

### Install Bats

```bash
# macOS
brew install bats-core

# Linux (Ubuntu/Debian)
sudo apt install bats

# Or install from source
git clone https://github.com/bats-core/bats-core.git
cd bats-core
./install.sh /usr/local
```

### Run Tests

```bash
# Run all tests
bats test/

# Run with verbose output
bats --verbose-run test/

# Run a specific test file
bats test/copy-claude-response.bats
```

### Test Coverage

The test suite covers:
- `generate_preview()` - Text truncation and preview generation
- `format_time_ago()` - Timestamp formatting
- Command regex matching (all `-copy` variants)
- Integration tests with mock transcripts
- Clipboard functionality (platform-specific)

## Contributing

Found a bug or have a feature request? Please open an issue or submit a pull request!

## License

Apache License 2.0 - feel free to modify and share!
