#!/usr/bin/env bash
set -euo pipefail

: "${SAYFLOW_DEBUG_ENDPOINT:?Set SAYFLOW_DEBUG_ENDPOINT to a /v1/responses or /chat/completions endpoint}"
: "${SAYFLOW_DEBUG_MODEL:?Set SAYFLOW_DEBUG_MODEL to the model name}"
: "${SAYFLOW_DEBUG_API_KEY:?Set SAYFLOW_DEBUG_API_KEY to the provider API key}"

SUPPORT_DIR="${HOME}/Library/Application Support/SayFlow"
SETTINGS_FILE="${SUPPORT_DIR}/settings.json"
PROMPTS_FILE="${SUPPORT_DIR}/prompts.json"
ENV_FILE="${SUPPORT_DIR}/provider.env"
API_KEY_REFERENCE="env://SAYFLOW_CUSTOM_API_KEY"

mkdir -p "$SUPPORT_DIR"

SETTINGS_FILE="$SETTINGS_FILE" \
PROMPTS_FILE="$PROMPTS_FILE" \
ENV_FILE="$ENV_FILE" \
SAYFLOW_DEBUG_ENDPOINT="$SAYFLOW_DEBUG_ENDPOINT" \
SAYFLOW_DEBUG_MODEL="$SAYFLOW_DEBUG_MODEL" \
SAYFLOW_DEBUG_API_KEY="$SAYFLOW_DEBUG_API_KEY" \
API_KEY_REFERENCE="$API_KEY_REFERENCE" \
node <<'NODE'
const fs = require('fs');

const settingsFile = process.env.SETTINGS_FILE;
const promptsFile = process.env.PROMPTS_FILE;
const envFile = process.env.ENV_FILE;
const endpoint = process.env.SAYFLOW_DEBUG_ENDPOINT;
const model = process.env.SAYFLOW_DEBUG_MODEL;
const apiKey = process.env.SAYFLOW_DEBUG_API_KEY;
const apiKeyReference = process.env.API_KEY_REFERENCE;

const defaultPrompt = {
  system: `你是一名面向中国英语学习者的语法批改老师。给定一段英文，你需要：
1. 修正其中的语法、拼写、固定搭配错误
2. 给出每处改动的对照（原始片段、改后片段、中文解释）
3. 提供修改后句子的中文翻译
4. 给一段口语化、带鼓励的学习贴士（good_to_know）

严格按以下 JSON 格式输出，不要任何额外说明或 markdown 代码块：
{
  "corrected": "修改后的完整英文句子",
  "changes": [{"old": "原片段", "new": "新片段", "explain": "中文解释"}],
  "translation_zh": "修改后句子的中文",
  "good_to_know": "口语化的学习贴士，2-4 句"
}`,
  user: '{{text}}'
};

function parseEnv(raw) {
  const values = new Map();
  for (const line of raw.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const normalized = trimmed.startsWith('export ') ? trimmed.slice('export '.length) : trimmed;
    const index = normalized.indexOf('=');
    if (index === -1) continue;
    values.set(normalized.slice(0, index).trim(), normalized.slice(index + 1).trim());
  }
  return values;
}

function renderEnv(raw, key, value) {
  const lines = [];
  let didUpdate = false;
  for (const line of raw.split(/\r?\n/)) {
    const normalized = line.trim().startsWith('export ') ? line.trim().slice('export '.length) : line.trim();
    const index = normalized.indexOf('=');
    const lineKey = index === -1 ? '' : normalized.slice(0, index).trim();
    if (lineKey === key) {
      didUpdate = true;
      lines.push(`${key}=${value}`);
    } else if (line) {
      lines.push(line);
    }
  }
  if (!didUpdate) {
    lines.push(`${key}=${value}`);
  }
  return `${lines.join('\n')}\n`;
}

const existingEnv = fs.existsSync(envFile) ? fs.readFileSync(envFile, 'utf8') : '';
fs.writeFileSync(envFile, renderEnv(existingEnv, 'SAYFLOW_CUSTOM_API_KEY', apiKey));
fs.chmodSync(envFile, 0o600);

const provider = {
  id: 'custom',
  kind: 'custom',
  displayName: 'Custom',
  apiKeyReference,
  baseURL: endpoint,
  model,
  temperature: 0.2,
  isActive: true,
};

let settings;
if (fs.existsSync(settingsFile)) {
  settings = JSON.parse(fs.readFileSync(settingsFile, 'utf8'));
} else {
  settings = {
    general: {
      launchAtLogin: false,
      hotKey: { displayText: '⌃⌘S', keyCode: 1, modifierFlags: 4352 },
      automaticallyChecksForUpdates: false,
      networkTimeoutSeconds: 30,
    },
    providers: [provider],
    display: { positionStrategy: 'followMouse', theme: 'system' },
    obsidian: {
      targetMarkdownPath: null,
      writeTemplate: { markdown: '\n---\n\n**{{timestamp}}**\n\n{{corrected}}\n\n**Changes:**\n{{changes_block}}\n\n> {{translation_zh}}\n\n**Good to know**\n\n{{good_to_know}}\n' },
      timeZoneIdentifier: null,
    },
  };
}

const promptTemplate = settings.prompts || defaultPrompt;

settings.providers = [provider].map((provider) => {
  const existing = (settings.providers || []).find((item) => item.kind === provider.kind || item.id === provider.id);
  return {
    ...provider,
    ...(existing || {}),
    displayName: 'Custom',
    baseURL: endpoint,
    model,
    apiKeyReference,
    isActive: true,
    apiKeyPlaintextForTesting: undefined,
  };
});

settings.general = {
  launchAtLogin: false,
  hotKey: { displayText: '⌃⌘S', keyCode: 1, modifierFlags: 4352 },
  automaticallyChecksForUpdates: false,
  networkTimeoutSeconds: 30,
  ...(settings.general || {}),
};
settings.display = settings.display || { positionStrategy: 'followMouse', theme: 'system' };
settings.obsidian = settings.obsidian || {
  targetMarkdownPath: null,
  writeTemplate: { markdown: '\n---\n\n**{{timestamp}}**\n\n{{corrected}}\n\n**Changes:**\n{{changes_block}}\n\n> {{translation_zh}}\n\n**Good to know**\n\n{{good_to_know}}\n' },
  timeZoneIdentifier: null,
};
delete settings.prompts;

if (!fs.existsSync(promptsFile)) {
  fs.writeFileSync(promptsFile, JSON.stringify(promptTemplate, null, 2) + '\n');
}

fs.writeFileSync(settingsFile, JSON.stringify(settings, null, 2) + '\n');
NODE

echo "Configured SayFlow Custom provider locally at ${SETTINGS_FILE}"
