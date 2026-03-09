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
  if (!API_KEY) throw new Error('LUCID_API_KEY not set')
  const url = new URL(endpoint, API_URL)
  Object.entries(params).forEach(([k, v]) => url.searchParams.set(k, v))
  const res = await fetch(url.toString(), {
    headers: { Authorization: Bearer ${API_KEY} },
  })
  if (!res.ok) throw new Error(Lucid API error: ${res.status})
  return res.json()
}

async function main() {
  const transport = new StdioServerTransport()
  await server.connect(transport)
}

main().catch(console.error)
