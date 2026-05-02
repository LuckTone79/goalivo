const { OpenAI } = require('openai');
const Anthropic = require('@anthropic-ai/sdk');

const DEFAULT_SYSTEM_PROMPT = [
  'You are Goalivo, a friendly Korean goal-achievement assistant.',
  'Return only the requested JSON when the user asks for JSON.',
  'For research reports, be practical, light, upbeat, and never invent URLs.'
].join(' ');
const DEFAULT_OPENAI_MODEL = 'gpt-4o';
const DEFAULT_OPENAI_WEB_MODEL = 'gpt-4o';
const DEFAULT_ANTHROPIC_MODEL = 'claude-sonnet-4-20250514';

function uniqModels(list = []) {
  const out = [];
  for (const item of list) {
    const model = String(item || '').trim();
    if (!model || out.includes(model)) continue;
    out.push(model);
  }
  return out;
}

function toErrorMessage(error) {
  if (!error) return 'Unknown AI API error';
  if (typeof error === 'string') return error;
  return error.message || JSON.stringify(error);
}

function isModelRoutingError(error) {
  const msg = toErrorMessage(error).toLowerCase();
  return msg.includes('not_found')
    || msg.includes('not found')
    || msg.includes('unknown model')
    || msg.includes('does not exist')
    || msg.includes('invalid model')
    || msg.includes('model');
}

async function runOpenAi(openai, modelName, safeSystemPrompt, prompt) {
  const response = await openai.chat.completions.create({
    model: modelName,
    messages: [
      { role: 'system', content: safeSystemPrompt },
      { role: 'user', content: prompt }
    ],
    temperature: 0.6
  });
  return response.choices?.[0]?.message?.content || '';
}

function extractResponsesText(response) {
  if (response.output_text) return response.output_text;
  const parts = [];
  for (const item of response.output || []) {
    for (const content of item.content || []) {
      if (content.type === 'output_text' && content.text) parts.push(content.text);
      if (content.type === 'text' && content.text) parts.push(content.text);
    }
  }
  return parts.join('\n');
}

async function runOpenAiWithWebSearch(openai, modelName, safeSystemPrompt, prompt) {
  const response = await openai.responses.create({
    model: modelName,
    instructions: safeSystemPrompt,
    input: prompt,
    tools: [{ type: 'web_search_preview' }],
    temperature: 0.4
  });
  return extractResponsesText(response);
}

async function runAnthropic(anthropic, modelName, safeSystemPrompt, prompt) {
  const response = await anthropic.messages.create({
    model: modelName,
    system: safeSystemPrompt,
    max_tokens: 3500,
    messages: [{ role: 'user', content: prompt }]
  });
  return response.content?.[0]?.text || '';
}

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Credentials', true);
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { model, prompt, systemPrompt, webSearch } = req.body || {};
  const safeSystemPrompt = systemPrompt || DEFAULT_SYSTEM_PROMPT;

  if (!prompt || typeof prompt !== 'string') {
    return res.status(400).json({ error: 'prompt is required' });
  }

  try {
    let result = '';

    if (model === 'openai') {
      if (!process.env.OPENAI_API_KEY) {
        return res.status(500).json({ error: 'OPENAI_API_KEY is missing on server' });
      }

      const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
      const candidates = uniqModels(webSearch
        ? [process.env.OPENAI_WEB_MODEL, process.env.OPENAI_MODEL, DEFAULT_OPENAI_WEB_MODEL, 'gpt-4.1-mini']
        : [process.env.OPENAI_MODEL, DEFAULT_OPENAI_MODEL, 'gpt-4.1-mini']);

      let lastErr = null;
      for (const modelName of candidates) {
        try {
          result = webSearch
            ? await runOpenAiWithWebSearch(openai, modelName, safeSystemPrompt, prompt)
            : await runOpenAi(openai, modelName, safeSystemPrompt, prompt);
          break;
        } catch (err) {
          lastErr = err;
          if (!isModelRoutingError(err)) break;
        }
      }

      if (!result && webSearch) {
        result = await runOpenAi(openai, process.env.OPENAI_MODEL || DEFAULT_OPENAI_MODEL, safeSystemPrompt, prompt);
      }
      if (!result && lastErr) throw lastErr;
    } else if (model === 'claude') {
      if (!process.env.ANTHROPIC_API_KEY) {
        return res.status(500).json({ error: 'ANTHROPIC_API_KEY is missing on server' });
      }

      const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
      const candidates = uniqModels([
        process.env.ANTHROPIC_MODEL,
        DEFAULT_ANTHROPIC_MODEL,
        'claude-3-5-sonnet-latest'
      ]);

      let lastErr = null;
      for (const modelName of candidates) {
        try {
          result = await runAnthropic(anthropic, modelName, safeSystemPrompt, prompt);
          break;
        } catch (err) {
          lastErr = err;
          if (!isModelRoutingError(err)) break;
        }
      }
      if (!result && lastErr) throw lastErr;
    } else {
      return res.status(400).json({ error: 'unsupported model' });
    }

    return res.status(200).json({ result });
  } catch (error) {
    const message = toErrorMessage(error);
    console.error('AI API Error:', message);
    return res.status(500).json({ error: message });
  }
};
