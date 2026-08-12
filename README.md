# 🧰 repos-of/repos-of

## First repos-of/walrus-man class

```text
relation: repos-of/walrus-man
ghorg: repos-of
repo: repos-of
repo-symbol: 🧰
remote-status: created
remote-url: https://github.com/repos-of/repos-of
checkout-status: verification-clone
local-checkout-path: pending-designated-worktree
published-artifact: none
default-branch: main
initial-commit: 1d56f8c
review-branch: review/repository-stewardship-contract
review-commit: 0693f95
pull-request: https://github.com/repos-of/repos-of/pull/1
requested-reviewer: ottopoet-thesean
reviewer-access: collaborator-invitation-pending
```

This is the first abstract repository class in the `repos-of/walrus-man` relation. It defines what it means for an agent to own a repository and how that ownership is tracked:

- resolve the authenticated GitHub organization and repository identity;
- establish and record a thread-owned local checkout beneath this nested AS
  casting, separately from a transient verification clone;
- record remote, branch, worktree, and provenance state locally;
- distinguish source-repository ownership (`🧰`) from published repository output (`📦`).

The authenticated remote check and this temporary verification clone's
configured `origin` agree on `https://github.com/repos-of/repos-of`. A durable
thread-owned checkout has not yet been designated, so `local-checkout-path` is
intentionally `pending-designated-worktree`. A local checkout with a stale or
unrelated remote is a distinct failure mode from an absent checkout and from a
temporary verification clone.

`🧰` means this record describes the source repository. `published-artifact`
must remain `none` unless a concrete published output (for example an npm
package/version or release tag) is recorded with its own evidence; a source
repository and its published output are separate facts.
