#!/usr/bin/env node

const { createOpencodeClient } = require("@opencode-ai/sdk");

async function main() {
  const serverUrl = process.argv[2];

  if (!serverUrl) {
    console.error("Usage: node opencode-list-sessions.js <server-url>");
    process.exit(1);
  }

  try {
    const client = createOpencodeClient({ baseUrl: serverUrl });

    // List sessions
    const sessions = await client.session.list();

    if (!sessions.data || sessions.data.length === 0) {
      console.log("No sessions found");
      return;
    }

    console.log("Sessions:");
    console.log("");
    for (const session of sessions.data) {
      const createdAt = new Date(session.createdAt).toLocaleString();
      const updatedAt = new Date(session.updatedAt).toLocaleString();
      const isCurrent = session.isCurrent ? " [current]" : "";
      const title = session.title || "Untitled";
      console.log(`  ${session.id}${isCurrent}`);
      console.log(`    Title: ${title}`);
      console.log(`    Created: ${createdAt}`);
      console.log(`    Updated: ${updatedAt}`);
      console.log("");
    }
  } catch (error) {
    console.error("Error:", error.message);
    process.exit(1);
  }
}

main();
