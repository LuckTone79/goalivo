module.exports = async function handler(req, res) {
    // CORS 처리
    res.setHeader('Access-Control-Allow-Credentials', true);
    res.setHeader('Access-Control-Allow-Origin', '*');

    if (req.method === 'OPTIONS') {
        res.status(200).end();
        return;
    }

    // wideget-core 표준 변수명(NEXT_PUBLIC_*)을 우선 사용하고,
    // 기존 배포와의 호환을 위해 레거시 변수명(SUPABASE_URL/ANON_KEY)으로 폴백합니다.
    // Public Key(anon)와 URL만 클라이언트로 전달합니다.
    // service_role key 등 비밀 키는 절대 클라이언트로 전달하지 않습니다.
    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || process.env.SUPABASE_URL || "";
    const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || process.env.SUPABASE_ANON_KEY || "";

    return res.status(200).json({
        supabaseUrl,
        supabaseAnonKey,
        appId: "goalivo"
    });
};
