import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js'
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js'
import { z } from 'zod'

const API_URL = process.env.LUCID_API_URL || 'https://getlucid.xyz/api/v1'
const API_KEY = process.env.LUCID_API_KEY || ''

const server = new McpServer({
  name: 'lucid',
  version: '0.1.0',
})

async function main() {
  const transport = new StdioServerTransport()
  await server.connect(transport)
}

main().catch(console.error)
