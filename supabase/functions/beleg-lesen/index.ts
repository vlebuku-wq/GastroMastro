// ============================================================
// Supabase Edge Function "beleg-lesen"
// Nimmt Text oder Bilder eines Belegs aus der App entgegen und lässt
// Claude die Artikel herauslesen. Der Claude-API-Schlüssel bleibt hier
// auf dem Server und gelangt nie in den Browser.
//
// Benötigte Secrets (Supabase → Edge Functions → Secrets):
//   ANTHROPIC_API_KEY   dein Schlüssel aus console.anthropic.com
//   ANTHROPIC_MODEL     optional, Standard: claude-sonnet-5-5
//                       (günstiger: claude-haiku-5-5)
// ============================================================
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });

const MAX_PROMPT_CHARS = 200_000;
const MAX_IMAGES = 5;
const MAX_IMAGE_B64 = 7_000_000; // ca. 5 MB pro Bild
const IMAGE_TYPES = new Set(["image/jpeg", "image/png", "image/webp", "image/gif"]);

const SYSTEM = [
  "Du liest Artikel aus Belegen, Listen und Fotos für eine Lagerverwaltung.",
  "Antworte ausschließlich mit dem angeforderten JSON, ohne weiteren Text.",
  "Erfinde keine Werte; Unbekanntes ist null.",
].join(" ");

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "Nur POST" }, 405);

  // 1) Angemeldeten Nutzer prüfen
  const authHeader = req.headers.get("Authorization") ?? "";
  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return json({ error: "Nicht angemeldet" }, 401);

  // 2) Nur Mitglieder eines Lagers dürfen die (kostenpflichtige) Erkennung nutzen
  const { count } = await supabase.from("mitglieder").select("lager_id", { count: "exact", head: true }).eq("user_id", user.id);
  if (!count) return json({ error: "Kein Lager" }, 403);

  // 3) Eingabe prüfen
  let body: { prompt?: unknown; images?: unknown };
  try { body = await req.json(); } catch { return json({ error: "Ungültige Anfrage" }, 400); }
  const prompt = typeof body.prompt === "string" ? body.prompt : "";
  if (!prompt.trim()) return json({ error: "Kein Inhalt" }, 400);
  if (prompt.length > MAX_PROMPT_CHARS) return json({ error: "Zu groß" }, 413);
  const images = Array.isArray(body.images) ? body.images : [];
  if (images.length > MAX_IMAGES) return json({ error: "Zu viele Bilder" }, 413);
  const imageBlocks = [];
  for (const img of images) {
    const t = (img as { media_type?: unknown })?.media_type;
    const d = (img as { data?: unknown })?.data;
    if (typeof t !== "string" || !IMAGE_TYPES.has(t) || typeof d !== "string" || !d) return json({ error: "Ungültiges Bild" }, 400);
    if (d.length > MAX_IMAGE_B64) return json({ error: "Bild zu groß" }, 413);
    imageBlocks.push({ type: "image", source: { type: "base64", media_type: t, data: d } });
  }

  // 4) Claude fragen
  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) return json({ error: "ANTHROPIC_API_KEY fehlt" }, 500);
  const model = Deno.env.get("ANTHROPIC_MODEL") || "claude-sonnet-5-5";

  const r = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: { "x-api-key": apiKey, "anthropic-version": "2023-06-01", "content-type": "application/json" },
    body: JSON.stringify({
      model,
      max_tokens: 8000,
      system: SYSTEM,
      messages: [{ role: "user", content: [...imageBlocks, { type: "text", text: prompt }] }],
    }),
  });
  if (!r.ok) {
    const detail = await r.text().catch(() => "");
    console.error("Anthropic-Fehler", r.status, detail.slice(0, 500));
    return json({ error: "Claude nicht erreichbar" }, r.status === 429 || r.status === 529 ? 429 : 502);
  }
  const out = await r.json();
  const text = (out.content ?? []).filter((b: { type: string }) => b.type === "text").map((b: { text: string }) => b.text).join("");
  return json({ text, truncated: out.stop_reason === "max_tokens" });
});
