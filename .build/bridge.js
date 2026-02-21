"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.queueEvents = void 0;
exports.enqueue = enqueue;
exports.dequeue = dequeue;
exports.resolveCommand = resolveCommand;
exports.rejectCommand = rejectCommand;
const events_1 = require("events");
const queue = [];
const COMMAND_TIMEOUT_MS = 120000;
exports.queueEvents = new events_1.EventEmitter();
function enqueue(id, tool, args) {
    return new Promise((resolve, reject) => {
        const timer = setTimeout(() => {
            const idx = queue.findIndex((c) => c.id === id);
            if (idx !== -1)
                queue.splice(idx, 1);
            reject({
                error: `Command ${id} timed out after ${COMMAND_TIMEOUT_MS}ms`,
                timeout: true,
                timeoutMs: COMMAND_TIMEOUT_MS,
            });
        }, COMMAND_TIMEOUT_MS);
        queue.push({ id, tool, args, resolve, reject, timer });
        exports.queueEvents.emit("enqueued");
    });
}
function dequeue() {
    const cmd = queue.find((c) => !c._dispatched);
    if (!cmd)
        return null;
    cmd._dispatched = true;
    return { id: cmd.id, tool: cmd.tool, args: cmd.args };
}
function resolveCommand(id, result) {
    const idx = queue.findIndex((c) => c.id === id);
    if (idx === -1)
        return false;
    const cmd = queue.splice(idx, 1)[0];
    clearTimeout(cmd.timer);
    cmd.resolve(result);
    return true;
}
function rejectCommand(id, error) {
    const idx = queue.findIndex((c) => c.id === id);
    if (idx === -1)
        return false;
    const cmd = queue.splice(idx, 1)[0];
    clearTimeout(cmd.timer);
    cmd.reject(error);
    return true;
}
