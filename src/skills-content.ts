import * as fs from "fs";
import * as path from "path";
import * as https from "https";

const SKILLS_URL = "https://raw.githubusercontent.com/nnaridz/RbxGenie/refs/heads/main/SKILLS.md";

export function downloadSkillsContent(dest: string): Promise<void> {
    return new Promise((resolve, reject) => {
        console.log("[RbxGenie] Downloading SKILLS.md from GitHub...");
        https.get(SKILLS_URL, (res) => {
            if (res.statusCode !== 200) {
                reject(new Error(`HTTP ${res.statusCode}`));
                return;
            }
            let data = "";
            res.on("data", (chunk) => (data += chunk));
            res.on("end", () => {
                fs.writeFileSync(dest, data, "utf-8");
                resolve();
            });
            res.on("error", reject);
        }).on("error", reject);
    });
}
