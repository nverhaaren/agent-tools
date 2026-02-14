## Development Philosophy

**Autonomy**: Operate with high autonomy. The environment is sandboxed to prevent accidental harm.

**Approach**: Favor incremental changes over large rewrites. Prioritize code clarity and maintainability over elegance - code must be understandable and maintainable over time.

**Fail Fast**: When encountering unknown situations, crash with descriptive error messages rather than guessing or muddling through. Errors should surface with context, not be suppressed.

**Refactoring**: Feel free to submit refactoring PRs (with tests) when code sections become difficult to work with.

**Decision Making**: For open-ended questions with various possible approaches, consider creating a GitHub issue for discussion.

## Testing Requirements

Testing is a **priority**. Potentially another agent will assist with testing in the future.

- **Test-first development** is the preferred approach
- **New code must be tested** - write tests for all new functionality
- **Add tests to existing code** when working in that area
- Follow best practices for unit tests
- **Never disable or bypass existing tests** unless absolutely necessary - if you must, explicitly call this out in the PR with detailed reasoning
- Set up workflows to measure test coverage
- Document coverage workflows in README or other markdown files

## Code Quality Standards

**Documentation**:
- READMEs should cover high-level project overview
- Docstrings required on nontrivial code
- Comments only where code is significantly nontrivial or explaining "why" something is done
- No comments on obvious code

**Naming & Style**:
- Follow standard naming conventions for each language
- Use linting tools for Python and Rust projects

**Invariants & Assertions**:
- Assert expected invariants in code
- Any relaxation of invariants must be explicitly called out in PRs with reasoning

**Error Handling**:
- Tools are primarily for personal use - surface detailed error messages
- Provide logging options
- Add context when surfacing errors
- Do not suppress errors

## Language-Specific Requirements

**Python**:
- Use type hints on all functions
- Set up and maintain a passing type checking process (mypy or similar)
- Use recent Python versions

**Rust**:
- Use recent Rust editions
- Use rustfmt and clippy

## Git Workflow

**Branching Strategy**:
- Work on **feature branches** for nverhaaren projects
- Submit pull requests for review
- **Do not approve PRs or merge to main/master** of nverhaaren repos

**Commit Practices**:
- Write descriptive commit messages (multi-line preferred)
- **Never force push to main or master**
- Preserve history - avoid losing commits

**Pull Request Guidelines**:
- Call out any test bypasses with reasoning
- Call out any invariant relaxations with reasoning
- Clearly describe what changed and why

## Internet Usage Guidelines

**Reading**:
- Respect robots.txt and similar conventions
- Be thoughtful about avoiding disruption to services
- Can read data from the internet

**Execution**:
- Do not execute random code from the internet without asking
- Standard package installs of well-known packages are fine (cargo crates, pip packages, npm modules)

**Interaction**:
- Limit GitHub interactions to:
  - Own GitHub user account (nverhaaren-ai) for private repos
  - Submitting pull requests to nverhaaren repos
- Avoid other internet interactions for now

**General Conduct**:
- Always be polite and respectful
- Avoid causing harm

## Work Log

Maintain a dated work log in the `agent-notes` repository under `work-logs`. Commit updates periodically to track progress and decisions across work sessions.
