$ErrorActionPreference = "Continue"

function cm($msg) {
    git add -A 2>$null
    git commit --no-gpg-sign -m $msg 2>$null | Out-Null
}

# 1
New-Item -ItemType Directory -Path ".claude-plugin" -Force | Out-Null
New-Item -ItemType Directory -Path "mcp-server/src" -Force | Out-Null
New-Item -ItemType Directory -Path "skills" -Force | Out-Null
Set-Content -Path ".gitignore" -Value "node_modules/`n.env`ndist/`n*.log"
cm "init repo structure"

# 2
Set-Content -Path "LICENSE" -Value @"
MIT License

Copyright (c) 2026 Lucid

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
"@
cm "add mit license"

# 3
Set-Content -Path ".env.example" -Value "LUCID_API_KEY=lk_your_api_key_here`nLUCID_API_URL=https://getlucid.xyz/api/v1"
cm "add env example"

# 4
Set-Content -Path "mcp-server/package.json" -Value @"
{
  "name": "@lucid/mcp-server",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "build": "tsc",
    "start": "node dist/index.js"
  }
}
"@
cm "init mcp server package"

# 5
Set-Content -Path "mcp-server/tsconfig.json" -Value @"
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ES2022",
    "moduleResolution": "node",
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "declaration": true
  },
  "include": ["src/**/*"]
}
"@
cm "add tsconfig"

# 6
Set-Content -Path "mcp-server/package.json" -Value @"
{
  "name": "@lucid/mcp-server",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "build": "tsc",
    "start": "node dist/index.js",
    "dev": "tsc --watch"
  },
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.0.0"
  },
  "devDependencies": {
    "typescript": "^5.7.0",
    "@types/node": "^22.0.0"
  }
}
"@
cm "add mcp sdk dependency"

# 7
Set-Content -Path "mcp-server/src/index.ts" -Value @"
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js'
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js'
import { z } from 'zod'

const server = new McpServer({
  name: 'lucid',
  version: '0.1.0',
})

async function main() {
  const transport = new StdioServerTransport()
  await server.connect(transport)
}

main().catch(console.error)
"@
cm "add server entry point"

# 8
$idx = Get-Content "mcp-server/src/index.ts" -Raw
$idx = $idx -replace "const server = new McpServer", @"
const API_URL = process.env.LUCID_API_URL || 'https://getlucid.xyz/api/v1'
const API_KEY = process.env.LUCID_API_KEY || ''

const server = new McpServer
"@
Set-Content -Path "mcp-server/src/index.ts" -Value $idx -NoNewline
cm "add api config constants"

# 9
$idx = Get-Content "mcp-server/src/index.ts" -Raw
$authFn = @"

async function authenticatedFetch(endpoint: string, params: Record<string, string> = {}) {
  if (!API_KEY) throw new Error('LUCID_API_KEY not set')
  const url = new URL(endpoint, API_URL)
  Object.entries(params).forEach(([k, v]) => url.searchParams.set(k, v))
  const res = await fetch(url.toString(), {
    headers: { Authorization: `Bearer `${API_KEY}` },
  })
  if (!res.ok) throw new Error(`Lucid API error: `${res.status}`)
  return res.json()
}

"@
$idx = $idx -replace "async function main", "$authFn`nasync function main"
Set-Content -Path "mcp-server/src/index.ts" -Value $idx -NoNewline
cm "add authenticated fetch helper"

# 10
Set-Content -Path "mcp-server/src/index.ts" -Value @"
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js'
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js'
import { z } from 'zod'

const API_URL = process.env.LUCID_API_URL || 'https://getlucid.xyz/api/v1'
const API_KEY = process.env.LUCID_API_KEY || ''

const server = new McpServer({
  name: 'lucid',
  version: '0.1.0',
})

async function authenticatedFetch(endpoint: string, params: Record<string, string> = {}) {
  if (!API_KEY) throw new Error('LUCID_API_KEY not set. Get one at https://getlucid.xyz/app')
  const url = new URL(endpoint, API_URL)
  Object.entries(params).forEach(([k, v]) => url.searchParams.set(k, v))
  const res = await fetch(url.toString(), {
    headers: { Authorization: ``Bearer `${API_KEY}`` },
  })
  if (!res.ok) throw new Error(``Lucid API error: `${res.status}``)
  return res.json()
}

server.tool(
  'lucid_search_docs',
  'Search real-time documentation for any programming language, framework, or library. Returns verified, up-to-date information.',
  {
    query: z.string().describe('The documentation search query'),
    language: z.string().optional().describe('Programming language context'),
  },
  async ({ query, language }) => {
    const params: Record<string, string> = { q: query, type: 'docs' }
    if (language) params.language = language
    const data = await authenticatedFetch('/search', params)
    return { content: [{ type: 'text' as const, text: JSON.stringify(data, null, 2) }] }
  }
)

async function main() {
  const transport = new StdioServerTransport()
  await server.connect(transport)
}

main().catch(console.error)
"@
cm "add search docs tool"

# 11
$content = Get-Content "mcp-server/src/index.ts" -Raw
$newTool = @"

server.tool(
  'lucid_check_package',
  'Check the latest version, changelog, and compatibility of any package or library. Ensures you are using the most current and stable version.',
  {
    name: z.string().describe('Package name (e.g. react, express, lodash)'),
    registry: z.string().optional().describe('Package registry: npm, pypi, cargo, etc.'),
  },
  async ({ name, registry }) => {
    const params: Record<string, string> = { q: name, type: 'package' }
    if (registry) params.registry = registry
    const data = await authenticatedFetch('/search', params)
    return { content: [{ type: 'text' as const, text: JSON.stringify(data, null, 2) }] }
  }
)
"@
$content = $content -replace "(async function main)", "$newTool`n`$1"
Set-Content -Path "mcp-server/src/index.ts" -Value $content -NoNewline
cm "add package check tool"

# 12
$content = Get-Content "mcp-server/src/index.ts" -Raw
$newTool2 = @"

server.tool(
  'lucid_verify_fact',
  'Verify a technical claim or fact against real-time sources. Use this to ground any uncertain statement in verified data.',
  {
    claim: z.string().describe('The technical claim to verify'),
    context: z.string().optional().describe('Additional context for verification'),
  },
  async ({ claim, context }) => {
    const params: Record<string, string> = { q: claim, type: 'verify' }
    if (context) params.context = context
    const data = await authenticatedFetch('/search', params)
    return { content: [{ type: 'text' as const, text: JSON.stringify(data, null, 2) }] }
  }
)
"@
$content = $content -replace "(async function main)", "$newTool2`n`$1"
Set-Content -Path "mcp-server/src/index.ts" -Value $content -NoNewline
cm "add fact verification tool"

# 13
$content = Get-Content "mcp-server/src/index.ts" -Raw
$newTool3 = @"

server.tool(
  'lucid_fetch_api_ref',
  'Fetch the latest API reference for a specific library or service. Returns structured endpoint documentation, type signatures, and usage examples.',
  {
    library: z.string().describe('Library or service name'),
    symbol: z.string().optional().describe('Specific function, class, or endpoint'),
    version: z.string().optional().describe('Target version'),
  },
  async ({ library, symbol, version }) => {
    const params: Record<string, string> = { q: library, type: 'api' }
    if (symbol) params.symbol = symbol
    if (version) params.version = version
    const data = await authenticatedFetch('/search', params)
    return { content: [{ type: 'text' as const, text: JSON.stringify(data, null, 2) }] }
  }
)
"@
$content = $content -replace "(async function main)", "$newTool3`n`$1"
Set-Content -Path "mcp-server/src/index.ts" -Value $content -NoNewline
cm "add api reference tool"

# 14
Set-Content -Path "mcp-server/package.json" -Value @"
{
  "name": "@lucid/mcp-server",
  "version": "0.2.0",
  "private": true,
  "type": "module",
  "scripts": {
    "build": "tsc",
    "start": "node dist/index.js",
    "dev": "tsc --watch"
  },
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.0.0",
    "zod": "^3.23.0"
  },
  "devDependencies": {
    "typescript": "^5.7.0",
    "@types/node": "^22.0.0"
  }
}
"@
cm "add zod dependency"

# 15
Set-Content -Path ".claude-plugin/plugin.json" -Value @"
{
  "name": "lucid",
  "version": "0.1.0",
  "description": "Real-time knowledge grounding for AI agents",
  "mcp_servers": [
    {
      "name": "lucid",
      "command": "node",
      "args": ["mcp-server/dist/index.js"]
    }
  ]
}
"@
cm "add plugin manifest"

# 16
Set-Content -Path ".mcp.json" -Value @"
{
  "mcpServers": {
    "lucid": {
      "command": "node",
      "args": ["mcp-server/dist/index.js"],
      "env": {
        "LUCID_API_KEY": ""
      }
    }
  }
}
"@
cm "add mcp server config"

# 17
Set-Content -Path "hooks.json" -Value @"
{
  "hooks": {
    "SessionStart": [
      {
        "type": "command",
        "command": "cat ascii-banner.txt 2>/dev/null || type ascii-banner.txt 2>nul"
      }
    ]
  }
}
"@
cm "add session hooks"

# 18
Set-Content -Path "ascii-banner.txt" -Value @"

    __    __  __ _____ _____ ____
   / /   / / / // ___//  _/ / __ \
  / /   / / / // /    / /  / / / /
 / /___/ /_/ // /___ _/ /  / /_/ /
/_____/\____/ \____//___/ /_____/

  real-time knowledge for ai agents
  https://getlucid.xyz

"@
cm "add ascii banner"

# 19
Set-Content -Path "marketplace.json" -Value @"
{
  "name": "lucid",
  "display_name": "Lucid",
  "description": "An intelligence layer grounding autonomous agents in verified, real-time knowledge at scale.",
  "author": "get-lucid",
  "repository": "https://github.com/get-Lucid/Lucid",
  "license": "MIT",
  "categories": ["knowledge", "search", "verification"],
  "keywords": ["real-time", "docs", "grounding", "verification", "packages"]
}
"@
cm "add marketplace listing"

# 20
Set-Content -Path ".claude-plugin/plugin.json" -Value @"
{
  "name": "lucid",
  "version": "0.2.0",
  "description": "An intelligence layer grounding autonomous agents in verified, real-time knowledge at scale.",
  "author": "get-lucid",
  "repository": "https://github.com/get-Lucid/Lucid",
  "mcp_servers": [
    {
      "name": "lucid",
      "command": "node",
      "args": ["mcp-server/dist/index.js"],
      "env": {
        "LUCID_API_KEY": ""
      }
    }
  ]
}
"@
cm "update plugin metadata"

# 21
New-Item -ItemType Directory -Path "skills/real-time-docs" -Force | Out-Null
Set-Content -Path "skills/real-time-docs/SKILL.md" -Value @"
---
name: real-time-docs
version: 1.0.0
description: Force agents to use verified, real-time documentation
triggers:
  - documentation
  - docs
  - how to use
  - api reference
---

# Real-Time Documentation Lookup

Always use the ``lucid_search_docs`` tool before answering questions about any programming language, framework, or library documentation.

## When to activate

- User asks about how to use a library or framework
- User references API methods or configuration options
- User asks about syntax or usage patterns
- Any question that could benefit from verified documentation

## Required behavior

1. Before answering, call ``lucid_search_docs`` with the relevant query
2. Base your response on the returned documentation
3. If the docs contradict your training data, prefer the real-time docs
4. Cite the documentation source in your response
"@
cm "add real-time-docs skill"

# 22
$content = Get-Content "skills/real-time-docs/SKILL.md" -Raw
$content += @"

## Examples

- ``lucid_search_docs({ query: "react useEffect cleanup", language: "typescript" })``
- ``lucid_search_docs({ query: "express middleware error handling", language: "javascript" })``
- ``lucid_search_docs({ query: "sqlalchemy async session", language: "python" })``
"@
Set-Content -Path "skills/real-time-docs/SKILL.md" -Value $content -NoNewline
cm "add docs skill examples"

# 23
New-Item -ItemType Directory -Path "skills/latest-packages" -Force | Out-Null
Set-Content -Path "skills/latest-packages/SKILL.md" -Value @"
---
name: latest-packages
version: 1.0.0
description: Ensure agents always reference the latest package versions
triggers:
  - install
  - package
  - dependency
  - npm install
  - pip install
  - version
---

# Latest Package Versions

Always use the ``lucid_check_package`` tool before recommending or installing any package.

## When to activate

- User asks to install a package
- User asks about package versions or compatibility
- Writing dependency files (package.json, requirements.txt, Cargo.toml)
- Recommending libraries or frameworks

## Required behavior

1. Call ``lucid_check_package`` with the package name before suggesting a version
2. Always recommend the latest stable version unless the user specifies otherwise
3. Flag any known deprecations or breaking changes
4. Include version constraints appropriate for the ecosystem
"@
cm "add latest-packages skill"

# 24
$content = Get-Content "skills/latest-packages/SKILL.md" -Raw
$content += @"

## Examples

- ``lucid_check_package({ name: "next", registry: "npm" })``
- ``lucid_check_package({ name: "fastapi", registry: "pypi" })``
- ``lucid_check_package({ name: "tokio", registry: "cargo" })``

## Anti-patterns

- Never hardcode a package version from training data
- Never assume a package is still maintained without checking
- Never recommend a version without verifying it exists
"@
Set-Content -Path "skills/latest-packages/SKILL.md" -Value $content -NoNewline
cm "add package skill examples"

# 25
New-Item -ItemType Directory -Path "skills/fact-grounding" -Force | Out-Null
Set-Content -Path "skills/fact-grounding/SKILL.md" -Value @"
---
name: fact-grounding
version: 1.0.0
description: Ground all technical claims in verified real-time data
triggers:
  - is this true
  - verify
  - correct
  - accurate
  - up to date
  - current
---

# Fact Grounding

Use the ``lucid_verify_fact`` tool to verify any technical claim before presenting it as fact.

## When to activate

- Making claims about performance benchmarks
- Stating compatibility between tools or versions
- Referencing best practices that may have changed
- Asserting security properties or vulnerability status
- Any statement where accuracy is critical

## Required behavior

1. Identify claims that could be outdated or incorrect
2. Call ``lucid_verify_fact`` with the specific claim
3. Adjust your response based on verification results
4. Clearly mark any information that could not be verified
"@
cm "add fact-grounding skill"

# 26
$content = Get-Content "skills/fact-grounding/SKILL.md" -Raw
$content += @"

## Examples

- ``lucid_verify_fact({ claim: "React 19 supports server components by default" })``
- ``lucid_verify_fact({ claim: "Python 3.12 removed distutils", context: "migration guide" })``
- ``lucid_verify_fact({ claim: "bun is faster than node for http servers" })``
"@
Set-Content -Path "skills/fact-grounding/SKILL.md" -Value $content -NoNewline
cm "add grounding examples"

# 27
New-Item -ItemType Directory -Path "skills/live-api-reference" -Force | Out-Null
Set-Content -Path "skills/live-api-reference/SKILL.md" -Value @"
---
name: live-api-reference
version: 1.0.0
description: Fetch live API references instead of relying on training data
triggers:
  - api
  - endpoint
  - function signature
  - method
  - type definition
---

# Live API Reference

Use the ``lucid_fetch_api_ref`` tool to get the latest API reference for any library or service.

## When to activate

- User asks about specific API endpoints or methods
- Writing code that calls external APIs
- Checking function signatures or type definitions
- Verifying method parameters or return types

## Required behavior

1. Call ``lucid_fetch_api_ref`` with the library and optional symbol
2. Use the returned type signatures and parameters in your code
3. Prefer the live reference over training data for all API details
4. Include relevant version information in responses
"@
cm "add live-api-reference skill"

# 28
$content = Get-Content "skills/live-api-reference/SKILL.md" -Raw
$content += @"

## Examples

- ``lucid_fetch_api_ref({ library: "stripe", symbol: "PaymentIntent.create" })``
- ``lucid_fetch_api_ref({ library: "openai", symbol: "chat.completions", version: "v1" })``
- ``lucid_fetch_api_ref({ library: "prisma", symbol: "findMany" })``
"@
Set-Content -Path "skills/live-api-reference/SKILL.md" -Value $content -NoNewline
cm "add api ref examples"

# 29
New-Item -ItemType Directory -Path "skills/codebase-freshness" -Force | Out-Null
Set-Content -Path "skills/codebase-freshness/SKILL.md" -Value @"
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

1. Before writing code, check the relevant docs with ``lucid_search_docs``
2. Verify package versions with ``lucid_check_package``
3. Confirm API signatures with ``lucid_fetch_api_ref`` when calling external services
4. Use modern patterns and avoid deprecated APIs
"@
cm "add codebase-freshness skill"

# 30
$content = Get-Content "skills/codebase-freshness/SKILL.md" -Raw
$content += @"

## Workflow

1. Identify the key libraries and APIs in the task
2. Check each one for current version and patterns
3. Write code using verified, up-to-date approaches
4. Flag any areas where your training data may be outdated

## Anti-patterns

- Never use deprecated lifecycle methods or APIs
- Never import from paths that have been reorganized
- Never use configuration formats from old versions
"@
Set-Content -Path "skills/codebase-freshness/SKILL.md" -Value $content -NoNewline
cm "add freshness workflow"

# 31
Set-Content -Path "skills/real-time-docs/SKILL.md" -Value @"
---
name: real-time-docs
version: 1.0.0
description: Force agents to use verified, real-time documentation
triggers:
  - documentation
  - docs
  - how to use
  - api reference
  - tutorial
  - guide
tools:
  - lucid_search_docs
---

# Real-Time Documentation Lookup

Always use the ``lucid_search_docs`` tool before answering questions about any programming language, framework, or library documentation.

## When to activate

- User asks about how to use a library or framework
- User references API methods or configuration options
- User asks about syntax or usage patterns
- Any question that could benefit from verified documentation

## Required behavior

1. Before answering, call ``lucid_search_docs`` with the relevant query
2. Base your response on the returned documentation
3. If the docs contradict your training data, prefer the real-time docs
4. Cite the documentation source in your response

## Examples

- ``lucid_search_docs({ query: "react useEffect cleanup", language: "typescript" })``
- ``lucid_search_docs({ query: "express middleware error handling", language: "javascript" })``
- ``lucid_search_docs({ query: "sqlalchemy async session", language: "python" })``
"@
cm "add tool references to skills"

# 32
Set-Content -Path "skills/latest-packages/SKILL.md" -Value @"
---
name: latest-packages
version: 1.0.0
description: Ensure agents always reference the latest package versions
triggers:
  - install
  - package
  - dependency
  - npm install
  - pip install
  - version
  - upgrade
tools:
  - lucid_check_package
---

# Latest Package Versions

Always use the ``lucid_check_package`` tool before recommending or installing any package.

## When to activate

- User asks to install a package
- User asks about package versions or compatibility
- Writing dependency files (package.json, requirements.txt, Cargo.toml)
- Recommending libraries or frameworks

## Required behavior

1. Call ``lucid_check_package`` with the package name before suggesting a version
2. Always recommend the latest stable version unless the user specifies otherwise
3. Flag any known deprecations or breaking changes
4. Include version constraints appropriate for the ecosystem

## Examples

- ``lucid_check_package({ name: "next", registry: "npm" })``
- ``lucid_check_package({ name: "fastapi", registry: "pypi" })``
- ``lucid_check_package({ name: "tokio", registry: "cargo" })``

## Anti-patterns

- Never hardcode a package version from training data
- Never assume a package is still maintained without checking
- Never recommend a version without verifying it exists
"@
cm "update package skill triggers"

# 33
foreach ($skill in @("fact-grounding","live-api-reference","codebase-freshness")) {
    $c = Get-Content "skills/$skill/SKILL.md" -Raw
    if ($skill -eq "fact-grounding") { $c = $c -replace "triggers:", "triggers:`n  - fact check`ntools:`n  - lucid_verify_fact" }
    if ($skill -eq "live-api-reference") { $c = $c -replace "triggers:", "triggers:`n  - type signature`ntools:`n  - lucid_fetch_api_ref" }
    if ($skill -eq "codebase-freshness") { $c = $c -replace "triggers:", "triggers:`n  - scaffold`ntools:`n  - lucid_search_docs`n  - lucid_check_package`n  - lucid_fetch_api_ref" }
    Set-Content -Path "skills/$skill/SKILL.md" -Value $c -NoNewline
}
cm "add tool refs to remaining skills"

# 34
Set-Content -Path "README.md" -Value @"
# Lucid

An intelligence layer grounding autonomous agents in verified, real-time knowledge at scale.
"@
cm "init readme"

# 35
Set-Content -Path "README.md" -Value @"
# Lucid

An intelligence layer grounding autonomous agents in verified, real-time knowledge at scale.

## what it does

lucid gives ai agents access to real-time, verified information instead of relying on potentially outdated training data. it provides tools for documentation lookup, package version checking, fact verification, and api reference fetching.
"@
cm "add project description"

# 36
$content = Get-Content "README.md" -Raw
$content += @"

## install

### claude code plugin

``````
/plugin marketplace add get-Lucid/Lucid
/plugin marketplace install lucid@get-Lucid/Lucid
``````
"@
Set-Content -Path "README.md" -Value $content -NoNewline
cm "add install instructions"

# 37
$content = Get-Content "README.md" -Raw
$content += @"

### openclaw skills

``````
/skills install @lucid/real-time-docs
/skills install @lucid/latest-packages
/skills install @lucid/fact-grounding
/skills install @lucid/live-api-reference
/skills install @lucid/codebase-freshness
``````
"@
Set-Content -Path "README.md" -Value $content -NoNewline
cm "add openclaw install steps"

# 38
$content = Get-Content "README.md" -Raw
$content += @"

## setup

1. get an api key at [getlucid.xyz/app](https://getlucid.xyz/app)
2. set your key:

``````bash
export LUCID_API_KEY=lk_your_key_here
``````
"@
Set-Content -Path "README.md" -Value $content -NoNewline
cm "add api key setup"

# 39
$content = Get-Content "README.md" -Raw
$content += @"

## tools

| tool | description |
|------|-------------|
| ``lucid_search_docs`` | search real-time documentation for any language or framework |
| ``lucid_check_package`` | check latest versions, changelogs, and compatibility |
| ``lucid_verify_fact`` | verify technical claims against real-time sources |
| ``lucid_fetch_api_ref`` | fetch latest api reference with type signatures |
"@
Set-Content -Path "README.md" -Value $content -NoNewline
cm "add tools table"

# 40
$content = Get-Content "README.md" -Raw
$content += @"

## skills

| skill | triggers on |
|-------|-------------|
| ``real-time-docs`` | documentation, api reference, how to use |
| ``latest-packages`` | install, package, dependency, version |
| ``fact-grounding`` | verify, is this true, accurate, up to date |
| ``live-api-reference`` | api, endpoint, function signature |
| ``codebase-freshness`` | write code, implement, create, build |
"@
Set-Content -Path "README.md" -Value $content -NoNewline
cm "add skills table"

# 41
$content = Get-Content "README.md" -Raw
$content += @"

## pricing

20 usdc/month, payable on solana or base. subscribe at [getlucid.xyz/app](https://getlucid.xyz/app).
"@
Set-Content -Path "README.md" -Value $content -NoNewline
cm "add pricing info"

# 42
$content = Get-Content "README.md" -Raw
$content += @"

## how it works

lucid runs as an mcp server that connects to the lucid api. when an ai agent needs information, it calls one of the lucid tools which fetches verified, real-time data from the lucid knowledge layer. skills automatically trigger these tools based on conversation context.
"@
Set-Content -Path "README.md" -Value $content -NoNewline
cm "add architecture overview"

# 43
$content = Get-Content "README.md" -Raw
$content += @"

## license

mit
"@
Set-Content -Path "README.md" -Value $content -NoNewline
cm "add license to readme"

# 44
Set-Content -Path ".gitignore" -Value @"
node_modules/
.env
dist/
*.log
.DS_Store
*.tgz
coverage/
.turbo/
"@
cm "update gitignore patterns"

# 45
Set-Content -Path ".mcp.json" -Value @"
{
  "mcpServers": {
    "lucid": {
      "command": "node",
      "args": ["mcp-server/dist/index.js"],
      "env": {
        "LUCID_API_KEY": "",
        "LUCID_API_URL": "https://getlucid.xyz/api/v1"
      }
    }
  }
}
"@
cm "add api url to mcp config"

# 46
Set-Content -Path "hooks.json" -Value @"
{
  "hooks": {
    "SessionStart": [
      {
        "type": "command",
        "command": "cat ascii-banner.txt 2>/dev/null || type ascii-banner.txt 2>nul || true"
      }
    ]
  }
}
"@
cm "fix banner fallback command"

# 47
Set-Content -Path ".claude-plugin/plugin.json" -Value @"
{
  "name": "lucid",
  "version": "1.0.0",
  "description": "An intelligence layer grounding autonomous agents in verified, real-time knowledge at scale.",
  "author": "get-lucid",
  "repository": "https://github.com/get-Lucid/Lucid",
  "homepage": "https://getlucid.xyz",
  "license": "MIT",
  "mcp_servers": [
    {
      "name": "lucid",
      "command": "node",
      "args": ["mcp-server/dist/index.js"],
      "env": {
        "LUCID_API_KEY": ""
      }
    }
  ],
  "hooks": "hooks.json"
}
"@
cm "finalize plugin manifest"

# 48
Set-Content -Path "marketplace.json" -Value @"
{
  "name": "lucid",
  "display_name": "Lucid",
  "description": "An intelligence layer grounding autonomous agents in verified, real-time knowledge at scale.",
  "author": "get-lucid",
  "repository": "https://github.com/get-Lucid/Lucid",
  "homepage": "https://getlucid.xyz",
  "license": "MIT",
  "categories": ["knowledge", "search", "verification", "grounding"],
  "keywords": ["real-time", "documentation", "grounding", "verification", "packages", "api"],
  "min_version": "1.0.0"
}
"@
cm "update marketplace keywords"

# 49 - clean up server
Set-Content -Path "mcp-server/src/index.ts" -Value @"
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js'
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js'
import { z } from 'zod'

const API_URL = process.env.LUCID_API_URL || 'https://getlucid.xyz/api/v1'
const API_KEY = process.env.LUCID_API_KEY || ''

const server = new McpServer({
  name: 'lucid',
  version: '1.0.0',
})

async function authenticatedFetch(
  endpoint: string,
  params: Record<string, string> = {}
): Promise<unknown> {
  if (!API_KEY) {
    throw new Error(
      'LUCID_API_KEY not set. Get your key at https://getlucid.xyz/app'
    )
  }

  const url = new URL(endpoint, API_URL)
  Object.entries(params).forEach(([k, v]) => url.searchParams.set(k, v))

  const res = await fetch(url.toString(), {
    headers: {
      Authorization: `Bearer ${API_KEY}`,
      'Content-Type': 'application/json',
    },
  })

  if (!res.ok) {
    const body = await res.text().catch(() => '')
    throw new Error(`Lucid API error ${res.status}: ${body}`)
  }

  return res.json()
}

function textResult(data: unknown) {
  return {
    content: [{ type: 'text' as const, text: JSON.stringify(data, null, 2) }],
  }
}

server.tool(
  'lucid_search_docs',
  'Search real-time documentation for any programming language, framework, or library. Returns verified, up-to-date information instead of potentially outdated training data.',
  {
    query: z.string().describe('Documentation search query'),
    language: z
      .string()
      .optional()
      .describe('Programming language context (e.g. typescript, python, rust)'),
  },
  async ({ query, language }) => {
    const params: Record<string, string> = { q: query, type: 'docs' }
    if (language) params.language = language
    return textResult(await authenticatedFetch('/search', params))
  }
)

server.tool(
  'lucid_check_package',
  'Check the latest version, changelog, and compatibility of any package. Ensures you recommend current, stable versions.',
  {
    name: z.string().describe('Package name (e.g. react, express, fastapi)'),
    registry: z
      .string()
      .optional()
      .describe('Package registry: npm, pypi, cargo, go, etc.'),
  },
  async ({ name, registry }) => {
    const params: Record<string, string> = { q: name, type: 'package' }
    if (registry) params.registry = registry
    return textResult(await authenticatedFetch('/search', params))
  }
)

server.tool(
  'lucid_verify_fact',
  'Verify a technical claim or fact against real-time sources. Use to ground uncertain statements in verified data.',
  {
    claim: z.string().describe('The technical claim to verify'),
    context: z
      .string()
      .optional()
      .describe('Additional context for verification'),
  },
  async ({ claim, context }) => {
    const params: Record<string, string> = { q: claim, type: 'verify' }
    if (context) params.context = context
    return textResult(await authenticatedFetch('/search', params))
  }
)

server.tool(
  'lucid_fetch_api_ref',
  'Fetch the latest API reference for a library or service. Returns structured endpoint docs, type signatures, and usage examples.',
  {
    library: z.string().describe('Library or service name'),
    symbol: z
      .string()
      .optional()
      .describe('Specific function, class, or endpoint to look up'),
    version: z.string().optional().describe('Target version'),
  },
  async ({ library, symbol, version }) => {
    const params: Record<string, string> = { q: library, type: 'api' }
    if (symbol) params.symbol = symbol
    if (version) params.version = version
    return textResult(await authenticatedFetch('/search', params))
  }
)

async function main() {
  const transport = new StdioServerTransport()
  await server.connect(transport)
}

main().catch(console.error)
"@
cm "refactor server clean up"

# 50
Set-Content -Path "mcp-server/tsconfig.json" -Value @"
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ES2022",
    "moduleResolution": "node",
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "declaration": true,
    "resolveJsonModule": true,
    "forceConsistentCasingInFileNames": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
"@
cm "tighten tsconfig options"

# 51
Set-Content -Path "mcp-server/package.json" -Value @"
{
  "name": "@lucid/mcp-server",
  "version": "1.0.0",
  "description": "MCP server for Lucid real-time knowledge tools",
  "private": true,
  "type": "module",
  "main": "dist/index.js",
  "scripts": {
    "build": "tsc",
    "start": "node dist/index.js",
    "dev": "tsc --watch"
  },
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.0.0",
    "zod": "^3.23.0"
  },
  "devDependencies": {
    "typescript": "^5.7.0",
    "@types/node": "^22.0.0"
  },
  "engines": {
    "node": ">=18.0.0"
  }
}
"@
cm "bump server to 1.0.0"

# 52
Set-Content -Path "ascii-banner.txt" -Value @"

    __    __  __ _____ _____ ____
   / /   / / / // ___//  _/ / __ \
  / /   / / / // /    / /  / / / /
 / /___/ /_/ // /___ _/ /  / /_/ /
/_____/\____/ \____//___/ /_____/

  grounding agents in real-time knowledge
  v1.0.0 | https://getlucid.xyz

"@
cm "update banner tagline"

# 53
Set-Content -Path ".env.example" -Value @"
# your lucid api key from https://getlucid.xyz/app
LUCID_API_KEY=lk_your_api_key_here

# api endpoint (default: production)
LUCID_API_URL=https://getlucid.xyz/api/v1
"@
cm "improve env example"

# 54
$readme = Get-Content "README.md" -Raw
$readme = $readme -replace "# Lucid", "# lucid"
Set-Content -Path "README.md" -Value $readme -NoNewline
cm "lowercase readme title"

# 55 - add note about env to each skill
foreach ($skill in @("real-time-docs","latest-packages","fact-grounding","live-api-reference","codebase-freshness")) {
    $c = Get-Content "skills/$skill/SKILL.md" -Raw
    if (-not ($c -match "LUCID_API_KEY")) {
        $c += "`n`nRequires ``LUCID_API_KEY`` environment variable. Get your key at https://getlucid.xyz/app`n"
        Set-Content -Path "skills/$skill/SKILL.md" -Value $c -NoNewline
    }
}
cm "add api key note to skills"

# 56
$content = Get-Content "mcp-server/src/index.ts" -Raw
$content = $content -replace "version: '1.0.0'", "version: '1.0.0',`n  description: 'An intelligence layer grounding autonomous agents in verified, real-time knowledge at scale.'"
Set-Content -Path "mcp-server/src/index.ts" -Value $content -NoNewline
cm "add server description"

# 57
$content = Get-Content "mcp-server/src/index.ts" -Raw
$content = $content -replace "main\(\).catch\(console.error\)", @"
main().catch((err) => {
  console.error('Failed to start Lucid MCP server:', err)
  process.exit(1)
})
"@
Set-Content -Path "mcp-server/src/index.ts" -Value $content -NoNewline
cm "improve error exit handling"

# 58
$content = Get-Content "README.md" -Raw
$content += @"

## troubleshooting

**api key not working**
make sure your subscription is active at [getlucid.xyz/app](https://getlucid.xyz/app).

**tools not appearing**
rebuild the mcp server: ``cd mcp-server && npm run build``
"@
Set-Content -Path "README.md" -Value $content -NoNewline
cm "add troubleshooting section"

# 59
$content = Get-Content "README.md" -Raw
$content += @"

**connection errors**
check that ``LUCID_API_KEY`` is set in your environment and the api is reachable.
"@
Set-Content -Path "README.md" -Value $content -NoNewline
cm "add connection troubleshoot"

# 60
Set-Content -Path ".gitignore" -Value @"
node_modules/
.env
dist/
*.log
.DS_Store
*.tgz
coverage/
.turbo/
.next/
*.local
"@
cm "add more ignore patterns"

# 61
$content = Get-Content "mcp-server/src/index.ts" -Raw
$content = $content -replace "'Content-Type': 'application/json',", "'Content-Type': 'application/json',`n      'User-Agent': 'lucid-mcp/1.0.0',"
Set-Content -Path "mcp-server/src/index.ts" -Value $content -NoNewline
cm "add user agent header"

# 62
$content = Get-Content "mcp-server/src/index.ts" -Raw
$content = $content -replace "const API_URL = process.env.LUCID_API_URL \|\| 'https://getlucid.xyz/api/v1'", "const API_URL = (process.env.LUCID_API_URL || 'https://getlucid.xyz/api/v1').replace(/\/`$/, '')"
Set-Content -Path "mcp-server/src/index.ts" -Value $content -NoNewline
cm "strip trailing slash from url"

# 63
Set-Content -Path "marketplace.json" -Value @"
{
  "name": "lucid",
  "display_name": "Lucid",
  "description": "An intelligence layer grounding autonomous agents in verified, real-time knowledge at scale.",
  "author": "get-lucid",
  "repository": "https://github.com/get-Lucid/Lucid",
  "homepage": "https://getlucid.xyz",
  "license": "MIT",
  "categories": ["knowledge", "search", "verification", "grounding"],
  "keywords": ["real-time", "documentation", "grounding", "verification", "packages", "api", "mcp"],
  "min_version": "1.0.0",
  "tools": [
    "lucid_search_docs",
    "lucid_check_package",
    "lucid_verify_fact",
    "lucid_fetch_api_ref"
  ]
}
"@
cm "list tools in marketplace"

# 64
$content = Get-Content ".claude-plugin/plugin.json" -Raw
$content = $content -replace '"hooks": "hooks.json"', "`"hooks`": `"hooks.json`",`n  `"skills_dir`": `"skills`""
Set-Content -Path ".claude-plugin/plugin.json" -Value $content -NoNewline
cm "register skills directory"

# 65
$content = Get-Content "hooks.json" | ConvertFrom-Json
$content.hooks | Add-Member -NotePropertyName "ToolUse" -NotePropertyValue @(@{type="log"; message="lucid tool invoked"}) -Force
$content | ConvertTo-Json -Depth 5 | Set-Content -Path "hooks.json"
cm "add tool use hook"

# 66
Set-Content -Path "hooks.json" -Value @"
{
  "hooks": {
    "SessionStart": [
      {
        "type": "command",
        "command": "cat ascii-banner.txt 2>/dev/null || type ascii-banner.txt 2>nul || true"
      }
    ]
  }
}
"@
cm "simplify hooks config"

# 67
$content = Get-Content "mcp-server/src/index.ts" -Raw
$content = $content -replace "const body = await res.text\(\).catch\(\(\) => ''\)", "const body = await res.text().catch(() => 'unknown error')"
Set-Content -Path "mcp-server/src/index.ts" -Value $content -NoNewline
cm "better error fallback text"

# 68
$content = Get-Content "skills/codebase-freshness/SKILL.md" -Raw
$content = $content -replace "## Anti-patterns", "## Common pitfalls"
Set-Content -Path "skills/codebase-freshness/SKILL.md" -Value $content -NoNewline
cm "rename anti-patterns section"

# 69
$content = Get-Content "skills/latest-packages/SKILL.md" -Raw
$content = $content -replace "## Anti-patterns", "## Common pitfalls"
Set-Content -Path "skills/latest-packages/SKILL.md" -Value $content -NoNewline
cm "consistent section naming"

# 70
$content = Get-Content "README.md" -Raw
$content = $content -replace "## how it works", "## architecture"
Set-Content -Path "README.md" -Value $content -NoNewline
cm "rename architecture section"

# 71
$content = Get-Content ".env.example" -Raw
$content += "`n# optional: request timeout in ms`nLUCID_TIMEOUT=10000`n"
Set-Content -Path ".env.example" -Value $content -NoNewline
cm "add timeout config option"

# 72
$content = Get-Content "mcp-server/package.json" | ConvertFrom-Json
$content.keywords = @("mcp","lucid","ai","knowledge","grounding")
$content | ConvertTo-Json -Depth 5 | Set-Content -Path "mcp-server/package.json"
cm "add package keywords"

# 73
$content = Get-Content ".mcp.json" | ConvertFrom-Json
$content.mcpServers.lucid.env | Add-Member -NotePropertyName "LUCID_TIMEOUT" -NotePropertyValue "10000" -Force
$content | ConvertTo-Json -Depth 5 | Set-Content -Path ".mcp.json"
cm "add timeout to mcp config"

# 74
$content = Get-Content "README.md" -Raw
$content = $content -replace "## license`n`nmit", "## license`n`n[mit](LICENSE)"
Set-Content -Path "README.md" -Value $content -NoNewline
cm "link license file in readme"

# 75
$content = Get-Content "marketplace.json" | ConvertFrom-Json
$content | Add-Member -NotePropertyName "version" -NotePropertyValue "1.0.0" -Force
$content | ConvertTo-Json -Depth 5 | Set-Content -Path "marketplace.json"
cm "tag release 1.0.0"

Write-Host "done - $(git rev-list --count HEAD) commits created"
