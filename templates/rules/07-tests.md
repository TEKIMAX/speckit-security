## 7. Unit test rules

**SHOULD** add tests incrementally; **MUST** add tests when fixing bugs.

### Philosophy

We don't aim for 100% coverage. We aim for:

- Every **bug fix** lands with a regression test that would have caught it
- Every **new feature** lands with at least one pass case and one failure case
- Every **new helper** lands with a test for each distinct input shape

Coverage grows organically from real use, not from chasing a number.

### Writing a test

Every test file **MUST**:

1. Be runnable standalone (no complex setup required)
2. Create its own isolated fixture (temp directory, in-memory DB, etc.)
3. Clean up on exit
4. Exit 0 on pass, non-zero on fail
5. Print a human-readable summary

### Running tests

Tests **MUST** be runnable by a human in one command with no extra tooling:

```bash
bash tests/run.sh        # or: pnpm test / pytest / go test
```

The test output should be readable at 3 AM during an incident — tell
the human what's broken, not what the framework thinks happened.

### Documenting tests

Every test directory **MUST** have a `README.md` that explains:

- How to run the tests (copy-paste ready commands)
- What each test covers (one line per test)
- How to add a new test (pointer to the template)
- What the expected output looks like when everything passes

---
