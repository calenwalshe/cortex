# Google — Gmail, Drive, Calendar, Sheets, Docs, Tasks, Stitch

Google Workspace skill powered by the `gws` CLI (googleworkspace/cli). Full OAuth2 access to Gmail, Drive, Calendar, Sheets, Docs, and Tasks. Plus Stitch SDK for UI generation.

## User-invocable

When the user types `/google`, run this skill.

Also trigger — WITHOUT requiring the slash command — when the user says any of:
- "read my email", "check my inbox", "what emails do I have", "show my latest emails", "search my email for" (→ Gmail read)
- "send an email", "email X", "send a message to", "compose an email" (→ Gmail send)
- "what's on my calendar", "my schedule", "upcoming meetings", "agenda" (→ Calendar)
- "read this Drive file", "open this Google Drive link", "upload to Drive", "list my Drive files" (→ Drive)
- "read this spreadsheet", "update this sheet", "add a row to", "get sheet data" (→ Sheets)
- "read this doc", "open this Google Doc", "get document content" (→ Docs)
- "my tasks", "add a task", "task list", "what's on my todo" (→ Tasks)
- "generate a UI", "build a component with Stitch", "use Stitch" (→ Stitch)

## Arguments

- `/google mail read [--count N] [--search <query>]` — read inbox or search emails
- `/google mail send --to <addr> --subject <subject> --body <body>` — send an email
- `/google calendar [--days N]` — show upcoming calendar events
- `/google drive list [--folder <id>]` — list Drive files
- `/google drive read <file-id-or-url>` — read a Drive file
- `/google drive upload <path> [--parent <folder-id>]` — upload a file to Drive
- `/google sheets read <spreadsheet-id> [--range <range>]` — read spreadsheet data
- `/google sheets append <spreadsheet-id> --values <csv>` — append row to sheet
- `/google docs read <doc-id>` — read a Google Doc
- `/google tasks list` — list tasks
- `/google tasks add <title>` — add a task
- `/google stitch <description>` — generate a UI component via Stitch SDK
- `--save <path>` — write output to file (optional; defaults to chat)

## Instructions

This skill uses the `gws` CLI binary. All Google Workspace operations go through `gws` with OAuth2 credentials stored at `~/.config/gws/`.

### Auth check

Before any `gws` command, verify auth is active:

```bash
gws auth status 2>&1 | head -3
```

If `auth_method` is `"none"`, tell the user: `Google Workspace auth not configured. Run: gws auth login -s drive,gmail,calendar,sheets,docs,tasks`

### Gmail — Read

```bash
# Most recent 10 messages
gws gmail messages list --params '{"userId":"me","maxResults":10}' --format json

# Search
gws gmail messages list --params '{"userId":"me","q":"from:boss@company.com","maxResults":10}' --format json

# Read a specific message (get full content)
gws gmail messages get --params '{"userId":"me","id":"MESSAGE_ID","format":"full"}' --format json
```

The list endpoint returns message IDs and thread IDs. To get content, call `messages get` for each message. For efficiency, batch the top 5-10 message IDs.

### Gmail — Send

```bash
gws gmail +send --to "recipient@example.com" --subject "Subject here" --body "Body text here"
```

**Rule:** Always confirm before sending. Show To, Subject, and first 100 chars of body. Ask "Send? (yes/no)".

### Calendar — Agenda

```bash
# Upcoming events (default view)
gws calendar +agenda --format json

# With timezone
gws calendar +agenda --timezone America/Toronto --format json

# Raw API for more control (next 7 days)
gws calendar events list --params '{"calendarId":"primary","timeMin":"2026-04-02T00:00:00Z","timeMax":"2026-04-09T00:00:00Z","singleEvents":true,"orderBy":"startTime"}' --format json
```

### Drive — List & Read

```bash
# List files in root
gws drive files list --format json

# List files in a folder
gws drive files list --params '{"q":"\"FOLDER_ID\" in parents"}' --format json

# Read/download a file (extract file ID from URL: /d/{FILE_ID}/)
gws drive files get --params '{"fileId":"FILE_ID","alt":"media"}' --format json

# Export Google Docs/Sheets as text
gws drive files export --params '{"fileId":"FILE_ID","mimeType":"text/plain"}'
```

### Drive — Upload

```bash
gws drive +upload ./path/to/file.pdf --parent FOLDER_ID
```

### Sheets — Read & Write

```bash
# Read a range
gws sheets spreadsheets.values get --params '{"spreadsheetId":"SHEET_ID","range":"Sheet1!A1:D10"}' --format json

# Append a row
gws sheets +append --spreadsheet SHEET_ID --values "Alice,95,2026-04-02"

# Read entire sheet
gws sheets spreadsheets.values get --params '{"spreadsheetId":"SHEET_ID","range":"Sheet1"}' --format json
```

### Docs — Read

```bash
# Get document content
gws docs documents get --params '{"documentId":"DOC_ID"}' --format json
```

The response contains structured document content (paragraphs, tables, lists). Extract `.body.content` for the text.

### Tasks — List & Add

```bash
# List task lists
gws tasks tasklists list --format json

# List tasks in default list
gws tasks tasks list --params '{"tasklist":"@default"}' --format json

# Add a task
gws tasks tasks insert --params '{"tasklist":"@default"}' --json '{"title":"Buy groceries"}' --format json
```

### Stitch SDK (UI generation)

Requires `STITCH_API_KEY` in environment. Separate from `gws` — uses the Stitch SDK directly.

```javascript
// stitch-gen.mjs (save and run with: node stitch-gen.mjs)
import { StitchToolClient } from '/home/agent/.nvm/versions/node/v20.20.0/lib/node_modules/@google/stitch-sdk/dist/src/index.js';
import { writeFileSync } from 'fs';

const client = new StitchToolClient({ apiKey: process.env.STITCH_API_KEY });

const projectRaw = await client.callTool('create_project', { title: 'my-project' });
const projectId = projectRaw.name?.replace('projects/', '') || projectRaw.projectId;

const genRaw = await client.callTool('generate_screen_from_text', {
  projectId,
  prompt: description
});

const designComponent = genRaw.outputComponents?.find(c => c.design?.screens?.length > 0);
const screenData = designComponent.design.screens[0];
const screenId = screenData.name?.split('/').pop() || screenData.screenId;

const screenRaw = await client.callTool('get_screen', {
  projectId, screenId,
  name: `projects/${projectId}/screens/${screenId}`
});
const htmlResponse = await fetch(screenRaw.htmlCode.downloadUrl);
const html = await htmlResponse.text();

console.log(html.slice(0, 500));
writeFileSync('stitch-output.html', html);
```

If `STITCH_API_KEY` is not set: `Error: STITCH_API_KEY not found in environment. Add to ~/agent-stack/.env.`

### --save flag

If `--save <path>` provided, write output to that path. Relative paths resolve from CWD.
If omitted, output goes to chat.

### Error handling

If `gws` returns a non-zero exit code, show the error message.
If auth is not configured: `Error: Google Workspace auth not active. Run: gws auth login -s drive,gmail,calendar,sheets,docs,tasks`
If Stitch key missing: `Error: STITCH_API_KEY not found in environment.`
No tracebacks.

## Rules

- Always check auth status before first `gws` call in a session.
- Always confirm before sending email: show To, Subject, and body preview.
- Use `--format json` for all `gws` commands to get structured output.
- For Drive files, extract file ID from URL pattern `/d/{FILE_ID}/`.
- For large result sets, use `--page-limit N` to avoid flooding output.
- Stitch is separate from `gws` — it uses its own SDK and API key.
- Never expose OAuth tokens or credentials in output.
