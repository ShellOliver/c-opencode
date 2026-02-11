#!/usr/bin/env node

const { createOpencodeClient } = require('@opencode-ai/sdk')

const SERVER_URL = process.argv[2]
const COMMAND = process.argv[3]

if (!SERVER_URL) {
    console.error('Error: Server URL is required')
    process.exit(1)
}

const client = createOpencodeClient({ 
    baseUrl: SERVER_URL
})

async function runCommand() {
    const prompt = process.argv.slice(4).join(' ')
    
    if (!prompt) {
        console.error('Error: Prompt is required for run command')
        process.exit(1)
    }
    
    try {
        const session = await client.session.create({ body: { title: 'CLI Session' } })
        console.log(`Session created: ${session.id}`)
        
        const response = await client.session.prompt({ 
            path: { id: session.id }, 
            body: { parts: [{ type: 'text', text: prompt }] } 
        })
        
        if (response.text) {
            console.log(response.text)
        }
        
        process.exit(0)
    } catch (error) {
        console.error('Error:', error.message)
        process.exit(1)
    }
}

async function listSessionsCommand() {
    try {
        const sessions = await client.session.list()
        
        if (!sessions || sessions.length === 0) {
            console.log('No sessions found')
            return
        }
        
        console.log('Sessions:')
        sessions.forEach(s => {
            console.log(`  ${s.id}: ${s.title || 'Untitled'}`)
        })
        
        process.exit(0)
    } catch (error) {
        console.error('Error:', error.message)
        process.exit(1)
    }
}

async function main() {
    switch (COMMAND) {
        case 'run':
            await runCommand()
            break
        case 'list-sessions':
            await listSessionsCommand()
            break
        default:
            console.error(`Unknown command: ${COMMAND}`)
            console.error('Usage: opencode-client.js <server-url> <command> [args]')
            console.error('Commands: run, list-sessions')
            process.exit(1)
    }
}

main()
