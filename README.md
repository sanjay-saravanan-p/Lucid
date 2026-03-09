# Lucid

An intelligence layer grounding autonomous agents in verified, real-time knowledge at scale.

## what it does

lucid gives ai agents access to real-time, verified information instead of relying on potentially outdated training data. it provides tools for documentation lookup, package version checking, fact verification, and api reference fetching.

## install

### claude code plugin

```
/plugin marketplace add get-Lucid/Lucid
/plugin marketplace install lucid@get-Lucid/Lucid
```
### openclaw skills

```
/skills install @lucid/real-time-docs
/skills install @lucid/latest-packages
/skills install @lucid/fact-grounding
/skills install @lucid/live-api-reference
/skills install @lucid/codebase-freshness
```
## setup

1. get an api key at [getlucid.xyz/app](https://getlucid.xyz/app)
2. set your key:

```bash
export LUCID_API_KEY=lk_your_key_here
```
## tools

| tool | description |
|------|-------------|
| `lucid_search_docs` | search real-time documentation for any language or framework |
| `lucid_check_package` | check latest versions, changelogs, and compatibility |
| `lucid_verify_fact` | verify technical claims against real-time sources |
| `lucid_fetch_api_ref` | fetch latest api reference with type signatures |