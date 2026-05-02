const { OpenAI, toFile } = require('openai');

const DEFAULT_IMAGE_MODEL = 'gpt-image-1';

function toErrorMessage(error) {
  if (!error) return 'Unknown image API error';
  if (typeof error === 'string') return error;
  return error.message || JSON.stringify(error);
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

  const model = process.env.OPENAI_IMAGE_MODEL || DEFAULT_IMAGE_MODEL;
  const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

  try {
    const parsedReference = referenceImageDataUrl ? parseDataUrl(referenceImageDataUrl) : null;
    let response;

    if (parsedReference) {
      const referenceFile = await toFile(parsedReference.buffer, 'vision-reference.png', {
        type: parsedReference.mimeType || 'image/png'
      });
      response = await openai.images.edit({
        model,
        image: [referenceFile],
        prompt,
        size,
        quality
      });
    } else {
      response = await openai.images.generate({
        model,
        prompt,
        size,
        quality
      });
    }

    const imageBase64 = response?.data?.[0]?.b64_json;
    if (!imageBase64) {
      return res.status(500).json({ error: 'Image API returned no image payload' });
    }

    return res.status(200).json({
      dataUrl: `data:image/png;base64,${imageBase64}`,
      revisedPrompt: response?.data?.[0]?.revised_prompt || '',
      model
    });
  } catch (error) {
    const message = toErrorMessage(error);
    console.error('Image API Error:', message);
    return res.status(500).json({ error: message });
  }
};
