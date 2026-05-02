const { OpenAI, toFile } = require('openai');

const MODEL_CHAIN = ['gpt-image-1', 'dall-e-3', 'dall-e-2'];

function toErrorMessage(error) {
  if (!error) return 'Unknown image API error';
  if (typeof error === 'string') return error;
  return error.message || JSON.stringify(error);
}

function isRetryableError(error) {
  const msg = toErrorMessage(error).toLowerCase();
  return msg.includes('billing')
    || msg.includes('hard limit')
    || msg.includes('quota')
    || msg.includes('rate limit')
    || msg.includes('insufficient')
    || msg.includes('exceeded')
    || msg.includes('not_found')
    || msg.includes('not found')
    || msg.includes('does not exist')
    || msg.includes('invalid model')
    || msg.includes('unsupported')
    || msg.includes('unknown parameter');
}

function parseDataUrl(dataUrl = '') {
  const raw = String(dataUrl || '').trim();
  const match = raw.match(/^data:(image\/[a-zA-Z0-9.+-]+);base64,(.+)$/);
  if (!match) return null;
  return {
    mimeType: match[1],
    buffer: Buffer.from(match[2], 'base64')
  };
}

function getValidSize(model, requestedSize) {
  if (model === 'dall-e-2') return '1024x1024';
  if (model === 'dall-e-3') {
    const allowed = ['1024x1024', '1792x1024', '1024x1792'];
    return allowed.includes(requestedSize) ? requestedSize : '1024x1024';
  }
  return requestedSize || '1024x1024';
}

function getValidQuality(model, requestedQuality) {
  if (model === 'dall-e-2') return undefined;
  if (model === 'dall-e-3') return requestedQuality === 'hd' ? 'hd' : 'standard';
  return requestedQuality || 'medium';
}

function supportsEdit(model) {
  return model === 'gpt-image-1' || model === 'dall-e-2';
}

async function tryGenerate(openai, model, prompt, size, quality) {
  const params = {
    model,
    prompt,
    n: 1,
    size: getValidSize(model, size)
  };
  // gpt-image-1 returns b64_json by default; dall-e models need it explicitly
  if (model !== 'gpt-image-1') params.response_format = 'b64_json';
  const q = getValidQuality(model, quality);
  if (q) params.quality = q;
  return await openai.images.generate(params);
}

async function tryEditWithReference(openai, model, parsedReference, prompt, size, quality) {
  const referenceFile = await toFile(parsedReference.buffer, 'vision-reference.png', {
    type: parsedReference.mimeType || 'image/png'
  });
  const params = {
    model,
    prompt,
    size: getValidSize(model, size)
  };
  if (model !== 'gpt-image-1') params.response_format = 'b64_json';
  const q = getValidQuality(model, quality);
  if (q) params.quality = q;

  if (model === 'gpt-image-1') {
    params.image = [referenceFile];
  } else {
    params.image = referenceFile;
  }
  return await openai.images.edit(params);
}

function extractBase64(response) {
  const item = response?.data?.[0];
  if (!item) return null;
  if (item.b64_json) return { base64: item.b64_json, revisedPrompt: item.revised_prompt || '' };
  return null;
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

  if (!process.env.OPENAI_API_KEY) {
    return res.status(500).json({ error: 'OPENAI_API_KEY is missing on server' });
  }

  const {
    prompt,
    referenceImageDataUrl = '',
    quality = 'medium',
    size = '1024x1024'
  } = req.body || {};

  if (!prompt || typeof prompt !== 'string') {
    return res.status(400).json({ error: 'prompt is required' });
  }

  const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
  const parsedReference = referenceImageDataUrl ? parseDataUrl(referenceImageDataUrl) : null;
  const hasReference = !!parsedReference;

  const envModel = process.env.OPENAI_IMAGE_MODEL || '';
  const candidates = envModel
    ? [envModel, ...MODEL_CHAIN.filter(m => m !== envModel)]
    : [...MODEL_CHAIN];

  let lastErr = null;
  let usedModel = '';

  for (const model of candidates) {
    try {
      let response;

      if (hasReference && supportsEdit(model)) {
        response = await tryEditWithReference(openai, model, parsedReference, prompt, size, quality);
      } else {
        response = await tryGenerate(openai, model, prompt, size, quality);
      }

      const result = extractBase64(response);
      if (result) {
        usedModel = model;
        return res.status(200).json({
          dataUrl: `data:image/png;base64,${result.base64}`,
          revisedPrompt: result.revisedPrompt,
          model: usedModel,
          referenceUsed: hasReference && supportsEdit(model)
        });
      }
    } catch (err) {
      lastErr = err;
      console.error(`Image API [${model}] error:`, toErrorMessage(err));
      if (!isRetryableError(err)) break;
    }
  }

  const message = toErrorMessage(lastErr);
  const isBilling = message.toLowerCase().includes('billing') || message.toLowerCase().includes('limit');
  return res.status(isBilling ? 402 : 500).json({
    error: isBilling
      ? 'OpenAI API 결제 한도에 도달했습니다. OpenAI 대시보드에서 결제 한도를 확인해주세요.'
      : message
  });
};
