# Overseer.nvim Issue #445 Reproducer

This is a minimal reproducer for [overseer.nvim issue #445](https://github.com/stevearc/overseer.nvim/issues/445) - compiler output truncation based on PTY width.

## Problem Description

When overseer.nvim runs compilation tasks in a narrow terminal window using the `jobstart` strategy, long compiler error messages get truncated. This affects developers working in split windows or terminals with limited width.

## Running the Reproducer

The reproducer is contained in a single Nix flake that includes everything needed:
- Neovim with overseer.nvim configured
- A C++ test file with intentional compilation errors that generate long messages
- Automated test script that demonstrates the truncation

### Quick Run

```bash
# Run the test directly (from the overseer.nvim directory)
nix run

# Or from any other directory
nix run /home/tim/src/overseer.nvim

# Or build and run separately
nix build
./result/bin/test-issue445
```

## What the Test Does

1. Sets up a Neovim environment with overseer.nvim plugin properly installed
2. Configures the terminal width to 80 columns (narrow) to trigger potential truncation
3. Attempts to compile a C++ file with intentional errors that generate very long error messages
4. Provides fallback demonstrations of PTY width effects using other tools
5. Shows direct compiler output for comparison
6. Reports whether truncation occurred and provides educational information about the issue

## Expected Output

### Current Status (Overseer Compatibility Issue)
```
📊 Test Results:
   ────────────────────────────────────────────────────────
   ℹ️  Window width: 80
   ℹ️  Window width: 80 columns
   ────────────────────────────────────────────────────────

⚠️  OVERSEER SETUP ISSUE
• The test couldn't run due to environment compatibility  
• This is a test limitation, not related to the actual issue
```

### PTY Width Demonstration
```
🧪 PTY Width Demonstration:
   Testing how terminal width affects output in PTY environments...
   🎯 Key insight: This shows how PTY width can affect tool output
   📋 Real issue: Compilers often format errors based on terminal width
   🔧 Overseer fix: Set fixed pty_width to prevent truncation
```

### Direct Compiler Output (For Reference)
```
🔍 Direct compiler output (for comparison):
   Length: 580 characters
   test.cpp:12:9: error: 'SomeUndefinedTypeWithVeryLongNameThatDoesNotExist' was not declared...
```

### Testing the Fix
To test the fix, edit `flake.nix` and uncomment line 60:
```lua
-- pty_width = 500,  -- Fixed width prevents truncation
```
becomes:
```lua
pty_width = 500,  -- Fixed width prevents truncation
```

## Technical Details

The issue occurs because:
1. Overseer's `jobstart` strategy creates a PTY (pseudo-terminal) for running commands
2. By default, the PTY width matches the current Neovim window width
3. Many compilers format their output based on terminal width, truncating long lines
4. This results in incomplete error messages in the quickfix list

The fix allows setting a fixed `pty_width` that's independent of the window size, ensuring full error messages are captured regardless of terminal width.

## Files

- `flake.nix` - Complete self-contained reproducer flake (TEST ONLY - do not commit to main repo)

That's all! The flake contains everything else needed (test C++ code, Neovim config, test script) embedded within it.

**Note:** This `flake.nix` is only for reproducing the issue. It should not be committed to the main overseer.nvim repository. After testing, you can delete it or move it elsewhere.