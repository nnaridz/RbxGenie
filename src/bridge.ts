import { PendingCommand, PollResponse } from "./types";

const queue: PendingCommand[] = [];
const COMMAND_TIMEOUT_MS = 120_000;

export function enqueue(
    id: string,
    tool: string,
    args: Record<string, unknown>
): Promise<unknown> {
    return new Promise((resolve, reject) => {
        const timer = setTimeout(() => {
            const idx = queue.findIndex((c) => c.id === id);
            if (idx !== -1) queue.splice(idx, 1);
            reject(`Command ${id} timed out after ${COMMAND_TIMEOUT_MS}ms`);
        }, COMMAND_TIMEOUT_MS);

        queue.push({ id, tool, args, resolve, reject, timer });
    });
}

export function dequeue(): PollResponse | null {
    const cmd = queue.find((c) => !c._dispatched);
    if (!cmd) return null;
    (cmd as PendingCommand & { _dispatched: boolean })._dispatched = true;
    return { id: cmd.id, tool: cmd.tool, args: cmd.args };
}

export function resolveCommand(id: string, result: unknown): boolean {
    const idx = queue.findIndex((c) => c.id === id);
    if (idx === -1) return false;
    const cmd = queue.splice(idx, 1)[0];
    clearTimeout(cmd.timer);
    cmd.resolve(result);
    return true;
}

export function rejectCommand(id: string, error: string): boolean {
    const idx = queue.findIndex((c) => c.id === id);
    if (idx === -1) return false;
    const cmd = queue.splice(idx, 1)[0];
    clearTimeout(cmd.timer);
    cmd.reject(error);
    return true;
}
