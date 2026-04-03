---
name: documentation-git
description: Enforces API documentation using language-standard comments for public interfaces and generates Conventional Commits style messages when asked, clearly summarizing changes. Use when creating or modifying public classes/functions or when the user requests commit messages.
---

# Documentation & Git

## Instructions

When creating or modifying:

- Public classes, interfaces, or types
- Public or externally used functions/methods
- API surfaces consumed by other modules/services

you must:

1. Add or update **standard documentation comments** (JSDoc, XML docs, Dart doc comments, etc.).
2. Clearly document **parameters**, **return values**, and any important **side effects or invariants**.

When the user asks to **write a git commit message**, you must:

1. Use the **Conventional Commits** format.
2. Provide a concise but clear summary of the change.

---

## 1. Documentation Rules

### When to Document

Always add or update documentation comments for:

- Public classes/components
- Public methods/functions
- Public interfaces/DTOs/config objects
- Utility functions that are reused across modules

Internal/private helpers can have lighter comments, but still document **non-obvious behavior** or **important constraints**.

### How to Document

Use the **idiomatic comment style of the language**:

- JavaScript/TypeScript: **JSDoc**
- C#: **XML documentation comments**
- Dart: `///` doc comments
- Java/Kotlin: `/** ... */` style doc comments
- Python: docstrings

Each documented API should include, where applicable:

- **High-level description**: What this class/function represents or does.
- **Parameters**: Name, type (if not obvious), and meaning.
- **Return value**: Type (if needed) and what it represents.
- **Errors/Exceptions**: When and what can be thrown/returned on error.
- **Side effects**: External I/O, mutations, resource acquisition.

Example structure (language-agnostic):

```markdown
Summary:
- What this does.

Parameters:
- param1: what it represents, constraints, units.
- param2: optional/required, allowed values.

Returns:
- What is returned and how callers should use it.
```

Prefer clarity and conciseness over verbosity.

---

## 2. Git Commit Message Rules (Conventional Commits)

When asked to write or suggest a commit message, always follow **Conventional Commits**:

### Format

```text
<type>[optional scope]: <short summary>

[optional body]

[optional footer(s)]
```

### Common Types

- `feat`: 새로운 기능 추가
- `fix`: 버그 수정
- `docs`: 문서 관련 변경 (README, 주석 대규모 업데이트 등)
- `refactor`: 기능 변화 없이 내부 구조 개선
- `perf`: 성능 개선
- `test`: 테스트 코드 추가/수정
- `chore`: 빌드, 설정, 기타 잡다한 작업
- `style`: 포맷팅, 세미콜론, 린트 수정 등

### Required Behavior

When generating a commit message:

1. **Choose the most appropriate type** based on the main purpose of the change.
2. Write a **short, imperative summary** in the subject line:
   - 영어 사용을 기본으로 하고, 필요한 경우 한글 설명은 body에 추가 가능.
3. Optionally include a body with:
   - More detailed explanation or rationale
   - Breaking change notes
   - Links to issues/tickets

Examples:

```text
feat(auth): add JWT-based login endpoint

fix(user-profile): handle missing avatar url

docs(api): document pagination parameters on /users endpoint

refactor(core): extract validation logic into shared module
```

If the user provides a diff or description, base the message on:

- **What** changed (at a high level).
- **Why** it changed (motivation, bug, requirement).
- **Scope** (module, feature, component).

---

## When to Apply This Skill

Use these documentation & git rules when:

- The user:
  - Requests code for new public APIs, classes, or methods.
  - Asks to “문서화해줘”, “주석 달아줘”, or similar.
  - Asks for help writing a git commit message.
- You:
  - Introduce or significantly change externally used functions/classes.
  - Produce code that will be part of a reusable library or shared module.

In these scenarios, **never**:

- Omit documentation for public APIs.
- Return a commit message that does not follow Conventional Commits.
- Use vague commit summaries that don’t describe the main change.

---

## Summary Checklist

Before finalizing:

- [ ] All new or changed public classes/functions have clear, standard documentation comments.
- [ ] Parameters, return values, and important side effects are described.
- [ ] Any requested commit message follows Conventional Commits.
- [ ] The commit summary clearly conveys the primary change and scope.

