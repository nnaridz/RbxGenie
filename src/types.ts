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
    reject: (reason: any) => void;
    timer: NodeJS.Timeout;
    _dispatched?: boolean;
}

export interface PollResponse {
    id: string;
    tool: string;
    args: Record<string, unknown>;
}
