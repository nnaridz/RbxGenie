export interface ToolRequest {
    id: string;
    tool: string;
    args: Record<string, unknown>;
}

export interface ToolResult {
    id: string;
    result?: unknown;
    error?: string;
}

export interface PendingCommand {
    id: string;
    tool: string;
    args: Record<string, unknown>;
    resolve: (value: unknown) => void;
    reject: (reason: string) => void;
    timer: NodeJS.Timeout;
}

export interface PollResponse {
    id: string;
    tool: string;
    args: Record<string, unknown>;
}
