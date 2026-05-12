## 4. File length and complexity

**SHOULD** keep files short and focused.

### Target sizes

| File type | Target | Hard ceiling |
|---|---|---|
| Script (bash, python, etc.) | < 200 lines | 400 lines |
| Source module | < 300 lines | 500 lines |
| Template / markdown | < 200 lines | 400 lines |
| Doc | < 500 lines | 1000 lines |
| Config file | < 150 lines | 300 lines |

A file that hits the hard ceiling **SHOULD** be split before the next
feature lands in it.

### Complexity signals

- A function > 50 lines → extract helpers
- A step-by-step doc > 20 steps → split into sub-docs with a table of contents
- A config file > 300 lines → split into topic-specific files

---
