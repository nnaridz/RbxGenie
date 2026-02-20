import express from "express";
import { v4 as uuidv4 } from "uuid";
import { enqueue, dequeue, resolveCommand, rejectCommand, queueEvents } from "./bridge";

const app = express();
app.use(express.json({ limit: "10mb" }));

app.use((err: any, _req: express.Request, res: express.Response, next: express.NextFunction) => {
    if (err.type === "entity.parse.failed") {
        res.status(400).json({
            ok: false,
            error: `Invalid JSON body: ${err.message}`,
        });
        return;
    }
    next(err);
});

const PORT = process.env.PORT ? parseInt(process.env.PORT) : 7766;
const LONG_POLL_TIMEOUT_MS = 15_000;

app.post("/tool/:name", async (req, res) => {
    const tool = req.params.name;
    const args = req.body ?? {};
    const id = uuidv4();

    try {
        const result = await enqueue(id, tool, args);
        res.json({ ok: true, id, result });
    } catch (err: any) {
        const isTimeout = err && typeof err === "object" && err.timeout;
        res.status(500).json({
            ok: false,
            id,
            error: isTimeout ? err.error : String(err),
            timeout: isTimeout ? true : undefined,
            timeoutMs: isTimeout ? err.timeoutMs : undefined,
        });
    }
});

app.get("/poll", (req, res) => {
    const cmd = dequeue();
    if (cmd) {
        res.json({ hasCommand: true, ...cmd });
        return;
    }

    const deadline = Date.now() + LONG_POLL_TIMEOUT_MS;
    let resolved = false;

    const tryDequeue = () => {
        if (resolved) return;
        const cmd = dequeue();
        if (cmd) {
            resolved = true;
            queueEvents.removeListener("enqueued", tryDequeue);
            res.json({ hasCommand: true, ...cmd });
        }
    };

    queueEvents.on("enqueued", tryDequeue);

    const timer = setTimeout(() => {
        if (!resolved) {
            resolved = true;
            queueEvents.removeListener("enqueued", tryDequeue);
            res.json({ hasCommand: false });
        }
    }, LONG_POLL_TIMEOUT_MS);

    req.on("close", () => {
        resolved = true;
        clearTimeout(timer);
        queueEvents.removeListener("enqueued", tryDequeue);
    });
});

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

app.get("/health", (_req, res) => {
    res.json({ ok: true, service: "RbxGenie", port: PORT });
});

app.listen(PORT, "127.0.0.1", () => {
    console.log(`[RbxGenie] Daemon listening on http://127.0.0.1:${PORT}`);
});
