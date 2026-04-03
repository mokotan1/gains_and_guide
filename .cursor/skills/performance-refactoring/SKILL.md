---
name: performance-refactoring
description: Guides performance-aware refactoring with time/space complexity analysis, readability improvements (early return, reduced nesting), and resource cleanup to prevent memory leaks. Use when optimizing code, reviewing loops or data structures, or refactoring for maintainability and efficiency.
---

# Performance & Refactoring

## Instructions

When the user asks for refactoring, optimization, or performance review:

1. **Consider time and space complexity** of the current and proposed solution.
2. **Improve readability** by reducing nesting and using early returns.
3. **Ensure resource cleanup** to avoid memory leaks (listeners, streams, DB connections, etc.).

Always balance **성능(Performance)**, **가독성(Readability)**, and **유지보수성(Maintainability)**.

---

## 1. Time & Space Complexity

When reviewing or writing code that uses loops, recursion, or data structures:

- Explicitly think about:
  - Time complexity \(O(1), O(n), O(n \log n), O(n^2)\) …
  - Space complexity (extra memory allocations, intermediate copies, caches)
- Avoid:
  - Unnecessary nested loops when a better data structure (e.g. `Map`, `Set`, `Dictionary`) can reduce complexity.
  - Repeated computations inside loops that can be hoisted or cached.
  - Redundant traversals of the same collection.

**Required behavior:**

- Briefly state the **current complexity** and the **improved complexity** (if optimization is proposed).
- Prefer simpler algorithms with clearly acceptable complexity over micro-optimizations that hurt readability.

Example checklist:

- [ ] Are there nested loops that can be flattened or replaced by a hash-based lookup?
- [ ] Are we doing expensive operations (I/O, DB, network, regex) inside tight loops?
- [ ] Can we short‑circuit early when a result is already determined?

---

## 2. Readability & Structure (Early Return, Reduced Nesting)

To improve maintainability:

- Prefer **early returns** to avoid deep `if`/`else` pyramids.
- Extract complex conditions or branches into **small, focused functions**.
- Limit the depth of nested conditionals and loops.

**Patterns to enforce:**

- Replace:
  - Deeply nested `if` chains
  - Large functions doing multiple responsibilities
- With:
  - Guard clauses (early return on invalid/edge conditions)
  - Smaller helper functions with clear names

When refactoring, always:

- Preserve behavior first, then clean up structure.
- Keep changes logically grouped so they’re easy to review.

---

## 3. Memory Leaks & Resource Cleanup

Whenever dealing with:

- Event listeners (UI events, DOM events, streams)
- Subscriptions (Rx, streams, observers)
- File handles, sockets, database connections, transactions

You must:

- Ensure there is a **clear lifecycle**:
  - Where the resource is acquired/registered
  - Where and when it is **disposed/unsubscribed/closed**
- Avoid:
  - Anonymous listeners that cannot be easily removed
  - Long‑lived references that prevent garbage collection

**Required behavior:**

- When adding listeners, subscriptions, or external resources, always show:
  - The corresponding cleanup logic.
  - How it is triggered (component unmount, scope end, error path, etc.).

Checklist:

- [ ] Every listener/subscription has a corresponding remove/unsubscribe.
- [ ] Every external resource (file, DB, socket) is closed in both success and error paths.
- [ ] Long‑lived caches or static collections are bounded or periodically cleared if needed.

---

## When to Apply This Skill

Use these performance/refactoring rules when:

- The user asks to:
  - “최적화해줘”, “성능 개선해줘”, “리팩토링해줘”
  - Improve or clean up existing code
  - Handle large datasets, heavy loops, or hot paths
- You are:
  - Reviewing loops, recursion, or data structure choices
  - Touching code that manages listeners, streams, or DB connections

In these scenarios, **never**:

- Propose a refactor without considering its effect on complexity.
- Make code harder to read for minor micro‑optimizations.
- Introduce resources without showing how they are released.

---

## Summary Checklist

Before finalizing a performance/refactoring answer, verify:

- [ ] Time/space complexity has been considered and, if improved, briefly explained.
- [ ] Code readability is improved (less nesting, clear early returns, smaller functions where appropriate).
- [ ] All listeners/subscriptions/resources include explicit cleanup logic.
- [ ] The solution balances performance with maintainability and clarity.

