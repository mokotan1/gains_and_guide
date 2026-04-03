---
name: debugging-problem-solving
description: Enforces root cause analysis, step-by-step reasoning, and multiple-solution trade-off evaluation when debugging errors or solving technical problems. Use when error messages, stack traces, performance issues, or unexpected behavior are involved.
---

# Debugging & Problem Solving

## Instructions

When the user reports an error, bug, or unexpected behavior:

1. **Do NOT jump to code edits immediately.**
2. **Analyze and explain the root cause first.**
3. **Lay out a step-by-step reasoning path.**
4. **Propose multiple solution options when feasible and compare their trade-offs.**

---

## Core Rules

### 1. Root Cause First

- Always start by answering: **"Why did this error happen?"**
- Use any provided error message, stack trace, logs, or symptoms to infer:
  - The failing component (function, module, service, external system)
  - The failure mode (null/undefined, out-of-bounds, timeout, race condition, etc.)
  - The triggering conditions (specific input, environment, configuration, deployment change)

**Required behavior:**

- Before proposing a fix, write a short **Root Cause Analysis** section:
  - What is failing
  - Why it fails
  - Under which conditions it fails
  - How this maps to the provided error/trace/logs

If the root cause is uncertain, clearly state the **most likely hypotheses** and the evidence for/against each.

---

### 2. Step-by-Step Reasoning

Before showing any code changes, always present a numbered reasoning flow:

1. Problem understanding (how to reproduce / what is observed)
2. Hypotheses for potential causes
3. Investigation and evidence for/against each hypothesis
4. Conclusion about the most likely root cause
5. Planned fix strategy

Only **after** this structured reasoning section, present the actual code or configuration changes.

---

### 3. Multiple Options with Trade-offs

When more than one solution is technically possible:

1. Present **at least two** viable options (if they exist).
2. For each option, describe:
   - Pros: benefits, simplicity, short-term impact
   - Cons: complexity, performance cost, maintainability, long-term risk
3. Make a **clear recommendation** and justify it.

If realistically only one solution is reasonable, explicitly state why alternatives are inferior or unsafe.

---

## When to Apply This Skill

Use these debugging/problem-solving rules when:

- The user shares error messages, stack traces, logs, failing test cases, performance regressions, or “동작이 이상하다”와 같은 모호한 증상.
- The task involves:
  - Bug fixing
  - Production incident analysis
  - Flaky tests
  - Regression after a change or deployment

In these scenarios, **never**:

- Skip root cause explanation.
- Provide only a code patch without a reasoning trail.
- Provide a single “magic” fix without discussing alternatives when they clearly exist.

---

## Summary Checklist

Before finalizing a debugging answer, verify:

- [ ] Root cause (or best hypothesis) is clearly explained in natural language.
- [ ] Step-by-step reasoning is written out in numbered form.
- [ ] At least two solution options are considered when feasible.
- [ ] Pros/cons of each option are explicitly compared.
- [ ] A clear recommendation is made and then supported by code or configuration changes.

