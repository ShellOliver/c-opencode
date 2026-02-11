#!/usr/bin/env node

const { createOpencodeClient } = require("@opencode-ai/sdk");

async function main() {
  const serverUrl = process.argv[2];
  const prompt = process.argv.slice(3).join(" ");

  if (!serverUrl || !prompt) {
    console.error("Usage: node opencode-run.js <server-url> <prompt>");
    process.exit(1);
  }

  try {
    const client = createOpencodeClient({ baseUrl: serverUrl });

    // List sessions to find current or create one
    const sessions = await client.session.list();
    let currentSession = sessions.data?.[0];

    if (!currentSession) {
      // Create a new session if none exists
      const newSession = await client.session.create({
        body: { title: "CLI Session" },
      });
      currentSession = newSession.data;
    }

    // Send prompt to the session
    const result = await client.session.prompt({
      path: { id: currentSession.id },
      body: {
        parts: [{ type: "text", text: prompt }],
      },
    });

    // Extract and display the text parts from the response
    if (result.data?.parts) {
      for (const part of result.data.parts) {
        if (part.type === "text" && part.text) {
          process.stdout.write(part.text);
        }
      }
    }
  } catch (error) {
    console.error("Error:", error.message);
    process.exit(1);
  }
}

main();
