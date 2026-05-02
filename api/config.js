module.exports = async function handler(req, res) {
    // CORS 처리
    res.setHeader('Access-Control-Allow-Credentials', true);
    res.setHeader('Access-Control-Allow-Origin', '*');

    if (req.method === 'OPTIONS') {
        res.status(200).end();
        return;
    }

    // Supabase의 Public Key와 URL만 안전하게 클라이언트로 전달합니다.
    // 이 외의 Secret Key나 AI API Key는 클라이언트로 전달하면 안 됩니다.
    return res.status(200).json({
        supabaseUrl: process.env.SUPABASE_URL || "",
        supabaseAnonKey: process.env.SUPABASE_ANON_KEY || ""
    });
};
