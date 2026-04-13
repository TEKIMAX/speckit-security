### Model Configuration

- **Provider:**
- **Model:**
- **Version:** (pinned exact, no "latest")
- **Gateway:** AI gateway (required — every model call routes through it)
- **Temperature / top-p:**
- **Max tokens in / out:**

### Evaluation Baselines

| Metric | Threshold | Baseline | Measured |
|--------|-----------|----------|----------|
| Accuracy | ≥ 0.92 | | |
| p50 latency | < 1000 ms | | |
| p95 latency | < 2000 ms | | |
| Cost / req | < $0.01 | | |
| Jailbreak resistance | ≥ 0.98 | | |

### Rollback Plan

- **Trigger:** <metric> crosses <threshold>
- **Target version:** <prior pinned version>
- **Mechanism:** versioned runtime deploy with instant rollback
- **Time budget:** < 60 seconds
- **Owner:**
- **Verification:** how we confirm rollback succeeded
