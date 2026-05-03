#!/usr/bin/env bash
set -euo pipefail

: "${GRAKER_DEBUG_ENDPOINT:?Set GRAKER_DEBUG_ENDPOINT to a /v1/responses or /chat/completions endpoint}"
: "${GRAKER_DEBUG_MODEL:?Set GRAKER_DEBUG_MODEL to the model name}"
: "${GRAKER_DEBUG_API_KEY:?Set GRAKER_DEBUG_API_KEY to the provider API key}"

SUPPORT_DIR="${HOME}/Library/Application Support/Graker"
SETTINGS_FILE="${SUPPORT_DIR}/settings.json"
PROMPTS_FILE="${SUPPORT_DIR}/prompts.json"
KEYCHAIN_REF="keychain://provider/custom"

mkdir -p "$SUPPORT_DIR"

security add-generic-password \
  -U \
  -s "Graker" \
  -a "$KEYCHAIN_REF" \
  -w "$GRAKER_DEBUG_API_KEY" >/dev/null

SETTINGS_FILE="$SETTINGS_FILE" \
PROMPTS_FILE="$PROMPTS_FILE" \
GRAKER_DEBUG_ENDPOINT="$GRAKER_DEBUG_ENDPOINT" \
GRAKER_DEBUG_MODEL="$GRAKER_DEBUG_MODEL" \
node <<'NODE'
const fs = require('fs');

const settingsFile = process.env.SETTINGS_FILE;
const promptsFile = process.env.PROMPTS_FILE;
const endpoint = process.env.GRAKER_DEBUG_ENDPOINT;
const model = process.env.GRAKER_DEBUG_MODEL;

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

const providers = [
  ['openAI', 'OpenAI', 'https://api.openai.com/v1', 'gpt-4o-mini'],
  ['deepSeek', 'DeepSeek', 'https://api.deepseek.com/v1', 'deepseek-v4-flash'],
  ['mimo', 'Xiaomi MiMo', 'https://api.mimo-v2.com/v1', 'mimo-v2.5'],
  ['kimi', 'Moonshot Kimi', 'https://api.moonshot.cn/v1', 'kimi-latest'],
  ['miniMax', 'MiniMax', 'https://api.minimax.chat/v1', 'abab6.5s-chat'],
  ['doubao', 'Doubao', 'https://ark.cn-beijing.volces.com/api/v3', 'doubao-1-5-pro'],
  ['custom', 'OpenAI Third Party', endpoint, model],
].map(([kind, displayName, baseURL, defaultModel]) => ({
  id: kind,
  kind,
  displayName,
  apiKeyReference: `keychain://provider/${kind}`,
  baseURL,
  model: defaultModel,
  temperature: 0.2,
  isActive: kind === 'custom',
}));

let settings;
if (fs.existsSync(settingsFile)) {
  settings = JSON.parse(fs.readFileSync(settingsFile, 'utf8'));
} else {
  settings = {
    general: {
      launchAtLogin: false,
      hotKey: { displayText: '⌥G', keyCode: 5, modifierFlags: 2048 },
      automaticallyChecksForUpdates: false,
      networkTimeoutSeconds: 30,
    },
    providers,
    display: { positionStrategy: 'followMouse', theme: 'system' },
    obsidian: {
      targetMarkdownPath: null,
      writeTemplate: { markdown: '\n---\n\n**{{timestamp}}**\n\n{{corrected}}\n\n**Changes:**\n{{changes_block}}\n\n> {{translation_zh}}\n\n**Good to know**\n\n{{good_to_know}}\n' },
      timeZoneIdentifier: null,
    },
  };
}

const promptTemplate = settings.prompts || defaultPrompt;

settings.providers = providers.map((provider) => {
  const existing = (settings.providers || []).find((item) => item.kind === provider.kind || item.id === provider.id);
  return {
    ...provider,
    ...(existing || {}),
    displayName: provider.kind === 'custom' ? 'OpenAI Third Party' : (existing?.displayName || provider.displayName),
    baseURL: provider.kind === 'custom' ? endpoint : (existing?.baseURL || provider.baseURL),
    model: provider.kind === 'custom' ? model : (existing?.model || provider.model),
    apiKeyReference: provider.apiKeyReference,
    isActive: provider.kind === 'custom',
    apiKeyPlaintextForTesting: undefined,
  };
});

settings.general = {
  launchAtLogin: false,
  hotKey: { displayText: '⌥G', keyCode: 5, modifierFlags: 2048 },
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

echo "Configured Graker Custom provider at ${SETTINGS_FILE}"
