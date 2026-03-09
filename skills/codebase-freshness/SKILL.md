---
name: codebase-freshness
version: 1.0.0
description: Ensure generated code uses current patterns and APIs
triggers:
  - write code
  - implement
  - create
  - build
  - generate
---

# Codebase Freshness

Before writing any substantial code, verify that the patterns and APIs you plan to use are current.

## When to activate

- Writing new components, functions, or modules
- Setting up project scaffolding
- Implementing integrations with external services
- Configuring build tools or deployment

## Required behavior

1. Before writing code, check the relevant docs with `lucid_search_docs`
2. Verify package versions with `lucid_check_package`
3. Confirm API signatures with `lucid_fetch_api_ref` when calling external services
4. Use modern patterns and avoid deprecated APIs
