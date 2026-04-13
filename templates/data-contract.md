## 2. Data Contract

### Sources

| Name | Origin | Trust | Schema | PII? |
|------|--------|-------|--------|------|
| | | | | |

### Schemas

All schemas live in `src/schemas/{{FEATURE_SLUG}}.ts` (Zod).

```ts
import { z } from "zod";

export const ExampleSchema = z.object({
  id: z.string().uuid(),
  email: z.string().email().brand<"Email">(),
  created_at: z.string().datetime(),
});

export type Example = z.infer<typeof ExampleSchema>;
```

### PII Handling

| Field | Strategy | Tool |
|-------|----------|------|
| | tokenize / field-encrypt / hash / omit | <configured provider> |

### Bias Audit

- Segments that must be represented:
- Known bias risks:
- Mitigation:

### Drift Monitoring

- Baseline:
- Threshold:
- Detection: real-time monitoring / scheduled eval

### Retention

- TTL:
- Deletion path:
- Regulatory basis: GDPR / CCPA / HIPAA / none
