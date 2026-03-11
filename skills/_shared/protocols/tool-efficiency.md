# Tool Efficiency Protocol

**Every skill MUST follow these tool usage rules to minimize token consumption and maximize speed.**

## Rule 1: Parallel Tool Calls

When multiple inputs are independent, issue ALL reads/globs/greps in a single message. Never read files one by one when they can be read simultaneously.

**WRONG:**
```
Read("file1.md")
# wait for result
Read("file2.md")
# wait for result
Read("file3.md")
```

**RIGHT:**
```
# All three in one message:
Read("file1.md")
Read("file2.md")
Read("file3.md")
```

## Rule 2: Use Discovery Tools Before Full Reads

For code analysis, use `Glob` to discover files and `Grep` to find specific symbols before reading full files. Only use full `Read` for files you've confirmed are relevant.

| Need | Tool | Token Cost |
|------|------|-----------|
| Find files by name/pattern | `Glob("**/*.ts")` | Low (~100-300 tokens) |
| Find symbols across codebase | `Grep(pattern="className", glob="*.ts")` | Low (~200-500 tokens) |
| Specific function in known file | `Read(file, offset=N, limit=M)` | Medium (~200-1000 tokens) |
| Full file content | `Read(file)` | High (~500-5000 tokens) |

## Rule 3: Use the Right Tool for the Job

| Task | Use This | NOT This |
|------|----------|----------|
| Find files by name/pattern | `Glob` | `find` via Bash |
| Search file contents | `Grep` | `grep`/`rg` via Bash |
| Read a file | `Read` | `cat`/`head`/`tail` via Bash |
| Modify existing file | `Edit` | `sed`/`awk` via Bash |
| Create new file | `Write` | `echo`/heredoc via Bash |
| Run system commands | `Bash` | — |

## Rule 4: Batch Operations

When creating multiple files, use parallel Write/Edit calls where possible. When reading a directory of related files, use Glob first to discover files, then parallel Read.

## Rule 5: Parallel Failure Resilience (Claude Code 2.1.72+)

As of Claude Code 2.1.72, failed Read/WebFetch/Glob calls no longer cancel their sibling tool calls — only Bash errors cascade. This means parallel discovery operations are safe:

```
# Safe — if file2.md doesn't exist, file1.md and file3.md still return:
Read("file1.md")
Read("file2.md")  # 404 → returns error, siblings unaffected
Read("file3.md")
```

This removes a class of failure modes from Rule 1 parallel reads. You no longer need defensive file-exists checks before parallel Read batches.

## Rule 6: Config-Aware Paths

Always check `.production-grade.yaml` for path overrides before using hardcoded paths. This allows the plugin to work with existing project structures.

```
# Read config, then parse the YAML text for path overrides
config_text = Read(".production-grade.yaml")
# Look for paths.api_contracts in the YAML — fall back to defaults if not found
# Default: api_path = "api/openapi/*.yaml"
# Default: arch_path = "docs/architecture/"
```
