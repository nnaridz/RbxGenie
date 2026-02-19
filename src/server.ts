import express from "express";
import { v4 as uuidv4 } from "uuid";
import { enqueue, dequeue, resolveCommand, rejectCommand } from "./bridge";

const app = express();
app.use(express.json({ limit: "10mb" }));

const PORT = process.env.PORT ? parseInt(process.env.PORT) : 7766;
const LONG_POLL_TIMEOUT_MS = 15_000;

// AI agent calls any registered tool
app.post("/tool/:name", async (req, res) => {
    const tool = req.params.name;
    const args = req.body ?? {};
    const id = uuidv4();

    try {
        const result = await enqueue(id, tool, args);
        res.json({ ok: true, id, result });
    } catch (err) {
        res.status(500).json({ ok: false, id, error: String(err) });
    }
});

// Plugin long-polls for the next queued command
app.get("/poll", (req, res) => {
    const respond = () => {
        const cmd = dequeue();
        if (cmd) {
            res.json({ hasCommand: true, ...cmd });
            return true;
        }
        return false;
    };

    if (respond()) return;

    const deadline = Date.now() + LONG_POLL_TIMEOUT_MS;

    const interval = setInterval(() => {
        if (respond()) {
            clearInterval(interval);
        } else if (Date.now() >= deadline) {
            clearInterval(interval);
            res.json({ hasCommand: false });
        }
    }, 50);

    req.on("close", () => clearInterval(interval));
});

// Plugin posts result after executing a command
app.post("/result", (req, res) => {
    const { id, result, error } = req.body as {
        id: string;
        result?: unknown;
        error?: string;
    };

    if (!id) {
        res.status(400).json({ ok: false, error: "Missing id" });
        return;
    }

    if (error) {
        rejectCommand(id, error);
    } else {
        resolveCommand(id, result);
    }

    res.json({ ok: true });
});

// Health check
app.get("/health", (_req, res) => {
    res.json({ ok: true, service: "RbxGenie", port: PORT });
});

app.listen(PORT, "127.0.0.1", () => {
    console.log(`[RbxGenie] Daemon listening on http://127.0.0.1:${PORT}`);
});
