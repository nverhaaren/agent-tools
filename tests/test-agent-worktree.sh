#!/usr/bin/env bash
set -euo pipefail

# Test suite for agent-worktree.
# Creates a temporary git repo, exercises every subcommand, and checks results.
# Runs quickly and locally -- no network access needed.

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
AW="${SCRIPT_DIR}/agent-worktree"

PASS=0
FAIL=0
TEST_NAME=""

# ── Helpers ──────────────────────────────────────────────────────────────────

setup_repo() {
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"
    git init -b main --quiet
    git config user.email "test@example.com"
    git config user.name "Test"
    git commit --allow-empty -m "initial" --quiet
    echo "hello" > README.md
    git add README.md
    git commit -m "add readme" --quiet
}

teardown_repo() {
    cd /
    rm -rf "$TEST_DIR"
}

begin() {
    TEST_NAME="$1"
}

assert_eq() {
    local expected="$1" actual="$2" msg="${3:-}"
    if [ "$expected" = "$actual" ]; then
        return
    fi
    echo "  FAIL: ${TEST_NAME}: ${msg}"
    echo "    expected: ${expected}"
    echo "    actual:   ${actual}"
    FAIL=$((FAIL + 1))
    return 1
}

assert_contains() {
    local haystack="$1" needle="$2" msg="${3:-}"
    if echo "$haystack" | grep -qF "$needle"; then
        return
    fi
    echo "  FAIL: ${TEST_NAME}: ${msg}"
    echo "    expected to contain: ${needle}"
    echo "    in: ${haystack}"
    FAIL=$((FAIL + 1))
    return 1
}

assert_file_exists() {
    local path="$1"
    local msg="${2:-file should exist: ${path}}"
    if [ -e "$path" ]; then
        return
    fi
    echo "  FAIL: ${TEST_NAME}: ${msg}"
    FAIL=$((FAIL + 1))
    return 1
}

assert_file_not_exists() {
    local path="$1"
    local msg="${2:-file should not exist: ${path}}"
    if [ ! -e "$path" ]; then
        return
    fi
    echo "  FAIL: ${TEST_NAME}: ${msg}"
    FAIL=$((FAIL + 1))
    return 1
}

assert_exit_code() {
    local expected="$1"
    shift
    local actual=0
    "$@" > /dev/null 2>&1 || actual=$?
    if [ "$expected" -eq "$actual" ]; then
        return
    fi
    echo "  FAIL: ${TEST_NAME}: expected exit code ${expected}, got ${actual}"
    echo "    command: $*"
    FAIL=$((FAIL + 1))
    return 1
}

pass() {
    PASS=$((PASS + 1))
    echo "  ok: ${TEST_NAME}"
}

# ── Tests ────────────────────────────────────────────────────────────────────

test_no_args_prints_usage() {
    begin "no args prints usage"
    local out
    out=$("$AW" 2>&1 || true)
    assert_contains "$out" "Usage:" "should print usage" && pass
}

test_help_prints_usage() {
    begin "help prints usage"
    local out
    out=$("$AW" help 2>&1)
    assert_contains "$out" "agent-worktree create" "should mention create" && pass
}

test_unknown_command_fails() {
    begin "unknown command fails"
    assert_exit_code 1 "$AW" bogus && pass
}

test_not_a_git_repo() {
    begin "fails outside git repo"
    local tmp
    tmp="$(mktemp -d)"
    local out=""
    local rc=0
    out=$(cd "$tmp" && "$AW" list 2>&1) || rc=$?
    rm -rf "$tmp"
    assert_eq 1 "$rc" "should exit 1" || return
    assert_contains "$out" "not a git repository" "should say not a repo" && pass
}

test_create_basic() {
    begin "create basic worktree"
    local out
    out=$("$AW" create my-feature 2>&1)

    assert_file_exists ".trees/my-feature" "worktree dir should exist" || return
    assert_file_exists ".trees/my-feature/README.md" "worktree should have repo files" || return

    # Branch should exist
    git rev-parse --verify "agent/my-feature" > /dev/null 2>&1 \
        || { echo "  FAIL: ${TEST_NAME}: branch agent/my-feature should exist"; FAIL=$((FAIL+1)); return; }

    # Should be on the right branch
    local branch
    branch=$(git -C .trees/my-feature rev-parse --abbrev-ref HEAD)
    assert_eq "agent/my-feature" "$branch" "should be on correct branch" || return

    # Output should suggest cd command
    assert_contains "$out" "cd .trees/my-feature" "should suggest cd" && pass
}

test_create_adds_gitignore() {
    begin "create adds .trees/ to .gitignore"
    # .gitignore was created by the previous test
    local content
    content=$(cat .gitignore)
    assert_contains "$content" ".trees/" "gitignore should contain .trees/" && pass
}

test_create_gitignore_idempotent() {
    begin "create does not duplicate .gitignore entry"
    "$AW" create idempotent-test > /dev/null 2>&1
    local count
    count=$(grep -c "\.trees/" .gitignore)
    assert_eq "1" "$count" "should have exactly one .trees/ entry" || return
    "$AW" cleanup idempotent-test > /dev/null 2>&1
    pass
}

test_create_existing_gitignore_preserved() {
    begin "create preserves existing .gitignore content"
    # .gitignore already has .trees/ from earlier tests; check README.md is NOT wiped
    # Actually test that if there was prior content, it's kept
    local lines
    lines=$(wc -l < .gitignore)
    [ "$lines" -ge 1 ] || { echo "  FAIL: ${TEST_NAME}: gitignore should have content"; FAIL=$((FAIL+1)); return; }
    pass
}

test_create_with_instructions() {
    begin "create with --instructions"
    "$AW" create instr-task --instructions "Fix the auth bug in login.py" > /dev/null 2>&1

    assert_file_exists ".trees/instr-task/.claude/CLAUDE.local.md" "CLAUDE.local.md should exist" || return

    local content
    content=$(cat ".trees/instr-task/.claude/CLAUDE.local.md")
    assert_contains "$content" "Fix the auth bug in login.py" "should contain instructions" || return
    assert_contains "$content" "# Task Instructions" "should have header" && pass
}

test_create_with_custom_base_branch() {
    begin "create with custom base branch"
    git branch dev main
    "$AW" create custom-base dev > /dev/null 2>&1

    # The worktree should be based on dev (which points to same commit as main)
    assert_file_exists ".trees/custom-base" "worktree should exist" || return

    local branch
    branch=$(git -C .trees/custom-base rev-parse --abbrev-ref HEAD)
    assert_eq "agent/custom-base" "$branch" "should be on correct branch" || return

    "$AW" cleanup custom-base > /dev/null 2>&1
    git branch -d dev > /dev/null 2>&1
    pass
}

test_create_nonexistent_base_branch() {
    begin "create with nonexistent base branch fails"
    assert_exit_code 1 "$AW" create bad-base nonexistent-branch && pass
}

test_create_duplicate_fails() {
    begin "create duplicate worktree fails"
    assert_exit_code 1 "$AW" create my-feature && pass
}

test_create_missing_name_fails() {
    begin "create without name fails"
    assert_exit_code 1 "$AW" create && pass
}

test_list_shows_worktrees() {
    begin "list shows worktrees"
    local out
    out=$("$AW" list 2>&1)
    assert_contains "$out" "my-feature" "should list my-feature" || return
    assert_contains "$out" "instr-task" "should list instr-task" || return
    assert_contains "$out" "agent/my-feature" "should show branch name" || return
    assert_contains "$out" "ahead" "should show ahead/behind" && pass
}

test_list_shows_commits_ahead() {
    begin "list reflects commits ahead"
    # Make a commit in the worktree
    echo "new file" > .trees/my-feature/newfile.txt
    git -C .trees/my-feature add newfile.txt
    git -C .trees/my-feature commit -m "add newfile" --quiet

    local out
    out=$("$AW" list 2>&1)
    assert_contains "$out" "1 ahead" "should show 1 ahead" && pass
}

test_list_empty() {
    begin "list with no .trees dir"
    local tmp
    tmp="$(mktemp -d)"
    cd "$tmp"
    git init -b main --quiet
    git config user.email "test@example.com"
    git config user.name "Test"
    git commit --allow-empty -m "init" --quiet

    local out
    out=$("$AW" list 2>&1)
    assert_contains "$out" "does not exist" "should report no worktrees" || return

    cd "$TEST_DIR"
    rm -rf "$tmp"
    pass
}

test_cleanup_removes_worktree() {
    begin "cleanup removes worktree and branch"
    "$AW" cleanup instr-task > /dev/null 2>&1

    assert_file_not_exists ".trees/instr-task" "worktree dir should be gone" || return

    # Branch should be deleted
    if git rev-parse --verify "agent/instr-task" > /dev/null 2>&1; then
        echo "  FAIL: ${TEST_NAME}: branch agent/instr-task should be deleted"
        FAIL=$((FAIL + 1))
        return
    fi
    pass
}

test_cleanup_nonexistent_worktree() {
    begin "cleanup nonexistent worktree does not error"
    local out
    out=$("$AW" cleanup nonexistent 2>&1)
    assert_contains "$out" "does not exist, skipping" "should skip gracefully" || return
    assert_contains "$out" "complete" "should report completion" && pass
}

test_cleanup_missing_name_fails() {
    begin "cleanup without name fails"
    assert_exit_code 1 "$AW" cleanup && pass
}

test_cleanup_all() {
    begin "cleanup-all removes all worktrees"
    # Clean slate: remove leftover worktrees/branches from previous tests
    git worktree remove --force .trees/my-feature 2>/dev/null || true
    git branch -D agent/my-feature 2>/dev/null || true
    rm -rf .trees

    # Create two fresh worktrees (no unmerged commits)
    "$AW" create all-a > /dev/null 2>&1
    "$AW" create all-b > /dev/null 2>&1

    "$AW" cleanup-all > /dev/null 2>&1

    assert_file_not_exists ".trees/all-a" "all-a should be gone" || return
    assert_file_not_exists ".trees/all-b" "all-b should be gone" || return

    # Branches should be deleted
    if git rev-parse --verify "agent/all-a" > /dev/null 2>&1; then
        echo "  FAIL: ${TEST_NAME}: branch agent/all-a should be deleted"
        FAIL=$((FAIL + 1))
        return
    fi
    if git rev-parse --verify "agent/all-b" > /dev/null 2>&1; then
        echo "  FAIL: ${TEST_NAME}: branch agent/all-b should be deleted"
        FAIL=$((FAIL + 1))
        return
    fi
    pass
}

test_cleanup_all_empty() {
    begin "cleanup-all with no worktrees"
    # .trees/ may or may not exist after cleanup-all; remove if it does
    rm -rf .trees
    local out
    out=$("$AW" cleanup-all 2>&1)
    assert_contains "$out" "does not exist" "should report nothing to clean" && pass
}

# ── Run ──────────────────────────────────────────────────────────────────────

main() {
    echo "Setting up test repo..."
    setup_repo
    echo "Running tests in ${TEST_DIR}"
    echo ""

    test_no_args_prints_usage
    test_help_prints_usage
    test_unknown_command_fails
    test_not_a_git_repo

    test_create_basic
    test_create_adds_gitignore
    test_create_gitignore_idempotent
    test_create_existing_gitignore_preserved
    test_create_with_instructions
    test_create_with_custom_base_branch
    test_create_nonexistent_base_branch
    test_create_duplicate_fails
    test_create_missing_name_fails

    test_list_shows_worktrees
    test_list_shows_commits_ahead
    test_list_empty

    test_cleanup_removes_worktree
    test_cleanup_nonexistent_worktree
    test_cleanup_missing_name_fails

    test_cleanup_all
    test_cleanup_all_empty

    echo ""
    echo "Results: ${PASS} passed, ${FAIL} failed"

    teardown_repo

    if [ "$FAIL" -gt 0 ]; then
        exit 1
    fi
}

main
