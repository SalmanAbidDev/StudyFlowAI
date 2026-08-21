// supabase/functions/ai/index.ts
//
// The one place that talks to Gemini.
//
// It lives here rather than in the app because an API key compiled into a
// Flutter binary is recoverable from the APK — earlier in this project we
// pulled the Supabase URL straight out of libapp.so with grep, and a Gemini
// key would come out the same way. The key is a Supabase secret; the app never
// sees it and only ever calls this function with the signed-in user's JWT.
//
// Everything reads through that JWT, so Row Level Security decides what a
// caller can see. The service-role key is deliberately NOT used: a bug here
// could otherwise hand one user another user's documents.

/// Which models to try, in order, and how many extra goes each one gets.
///
/// A 503 "this model is currently experiencing high demand" is the common
/// failure here, and it is about *that model*, not the request — so the
/// answer is to wait a moment and then to move down the list rather than
/// hammering the same busy model. Every model here supports both the
/// `url_context` tool and `response_schema`, which the link and generation
/// paths depend on.
const MODEL_CHAIN: { model: string; retries: number }[] = [
  { model: "gemini-3.7-flash", retries: 1 },
  { model: "gemini-3.6-flash", retries: 0 },
  { model: "gemini-2.5-flash", retries: 0 },
];

/// Statuses worth trying again. Everything else is a real problem with the
/// request and retrying it would just cost time and money.
const RETRYABLE = new Set([429, 500, 502, 503, 504]);

const geminiUrl = (model: string) =>
  `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

/// Gemini takes inline files as base64 inside the request, so the whole thing
/// has to fit in one payload. Well under the documented ceiling, because the
/// prompt and the response share the budget.
const MAX_INLINE_BYTES = 15 * 1024 * 1024;

/// How many questions Flow answers per person per day.
const CHAT_MESSAGES_PER_DAY = 5;

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

/// btoa() takes a binary string, and spreading a multi-megabyte array into
/// String.fromCharCode blows the argument limit — hence the chunking.
function toBase64(bytes: Uint8Array): string {
  let binary = "";
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunk));
  }
  return btoa(binary);
}

type Material = {
  id: string;
  title: string;
  storage_path: string | null;
  source_url: string | null;
  mime_type: string | null;
};

/// Mirrors `StudyMaterial.kind` in the app: mime type first, then extension,
/// then PDF. A link is unambiguous — it has no file at all.
function kindOf(m: Material): "pdf" | "image" | "text" | "link" {
  if (m.source_url && !m.storage_path) return "link";
  const mime = m.mime_type ?? "";
  if (mime.startsWith("image/")) return "image";
  if (mime === "text/plain" || mime === "text/markdown") return "text";
  if (mime === "application/pdf") return "pdf";
  const path = (m.storage_path ?? "").toLowerCase();
  if (/\.(png|jpe?g|webp|gif)$/.test(path)) return "image";
  if (/\.(txt|md)$/.test(path)) return "text";
  return "pdf";
}

/// Turns a material into the `parts` Gemini reads, plus any tools it needs.
///
/// This is the whole of "giving Flow the document": a link goes in as a URL
/// with the url_context tool so Gemini fetches the page itself, and everything
/// else goes in as bytes. Nothing here summarises or truncates the source —
/// the model gets what the user actually uploaded.
async function sourceParts(
  supabaseUrl: string,
  jwt: string,
  apikey: string,
  material: Material,
): Promise<{ parts: unknown[]; tools?: unknown[] }> {
  const kind = kindOf(material);

  if (kind === "link") {
    return {
      parts: [{
        text: `The study material is the web page at ${material.source_url}. ` +
          `Read that page and use only what it actually says.`,
      }],
      tools: [{ type: "url_context" }],
    };
  }

  if (!material.storage_path) {
    throw new Error("This material has no file attached to it.");
  }

  // Downloaded with the caller's own JWT, so storage RLS applies exactly as it
  // does in the app.
  const res = await fetch(
    `${supabaseUrl}/storage/v1/object/materials/${material.storage_path}`,
    { headers: { Authorization: `Bearer ${jwt}`, apikey } },
  );
  if (!res.ok) {
    throw new Error(`Could not read that file from storage (${res.status}).`);
  }
  const bytes = new Uint8Array(await res.arrayBuffer());

  if (kind === "text") {
    return { parts: [{ text: new TextDecoder().decode(bytes) }] };
  }

  if (bytes.length > MAX_INLINE_BYTES) {
    throw new Error(
      "That file is too large to send in one request. " +
        `Files up to ${Math.floor(MAX_INLINE_BYTES / 1024 / 1024)}MB work.`,
    );
  }

  return {
    parts: [{
      inline_data: {
        mime_type: material.mime_type ??
          (kind === "pdf" ? "application/pdf" : "image/jpeg"),
        data: toBase64(bytes),
      },
    }],
  };
}

async function callGemini(body: unknown): Promise<string> {
  const key = Deno.env.get("GEMINI_API_KEY");
  if (!key) {
    throw new Error(
      "GEMINI_API_KEY is not set on this function. Add it under " +
        "Edge Functions → Secrets in the Supabase dashboard.",
    );
  }

  for (const step of MODEL_CHAIN) {
    for (let attempt = 0; attempt <= step.retries; attempt++) {
      const res = await fetch(`${geminiUrl(step.model)}?key=${key}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });
      const text = await res.text();

      if (res.ok) {
        const data = JSON.parse(text);
        const parts = data?.candidates?.[0]?.content?.parts ?? [];
        const out = parts
          .map((p: { text?: string }) => p.text ?? "")
          .join("")
          .trim();
        if (out) {
          console.log(`served by ${step.model}`);
          return out;
        }
        // An empty candidate is usually a safety block or a truncation, and
        // another model will do the same thing — say so rather than retrying.
        const reason = data?.candidates?.[0]?.finishReason ?? "no reason given";
        throw new Error(`Gemini returned nothing (${reason}).`);
      }

      if (!RETRYABLE.has(res.status)) {
        // Surfaced rather than swallowed: a 400 from Gemini usually names the
        // exact field that is wrong, and hiding it behind "something went
        // wrong" makes it unfixable from the app.
        throw new Error(`Gemini refused the request (${res.status}): ${text}`);
      }

      console.log(`${step.model} unavailable (${res.status}), attempt ${attempt + 1}`);
      // A short wait before a second go at the same model; moving to the next
      // model happens immediately, because a busy model stays busy.
      if (attempt < step.retries) await sleep(900);
    }
  }

  throw new Error(
    "Gemini is busy right now — every model was over capacity. This is " +
      "usually brief, so try again in a moment.",
  );
}

const FLASHCARD_SCHEMA = {
  type: "ARRAY",
  items: {
    type: "OBJECT",
    properties: {
      question: { type: "STRING" },
      answer: { type: "STRING" },
      source: { type: "STRING" },
      difficulty: { type: "INTEGER" },
    },
    required: ["question", "answer", "source", "difficulty"],
  },
};

const QUIZ_SCHEMA = {
  type: "ARRAY",
  items: {
    type: "OBJECT",
    properties: {
      prompt: { type: "STRING" },
      explanation: { type: "STRING" },
      options: {
        type: "ARRAY",
        items: {
          type: "OBJECT",
          properties: {
            body: { type: "STRING" },
            correct: { type: "BOOLEAN" },
          },
          required: ["body", "correct"],
        },
      },
    },
    required: ["prompt", "explanation", "options"],
  },
};

const SUMMARY_SCHEMA = {
  type: "ARRAY",
  items: {
    type: "OBJECT",
    properties: {
      title: { type: "STRING" },
      bullets: { type: "ARRAY", items: { type: "STRING" } },
    },
    required: ["title", "bullets"],
  },
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const apikey = Deno.env.get("SUPABASE_ANON_KEY") ??
      Deno.env.get("SUPABASE_PUBLISHABLE_KEY")!;
    const auth = req.headers.get("Authorization") ?? "";
    const jwt = auth.replace(/^Bearer /i, "");
    if (!jwt) return json({ error: "Not signed in." }, 401);

    const body = await req.json();
    const action: string = body.action;

    /// Reads one row through the caller's JWT — RLS is what stops this being a
    /// way to read someone else's library by guessing an id.
    const asUser = async (path: string) => {
      const res = await fetch(`${supabaseUrl}/rest/v1/${path}`, {
        headers: {
          Authorization: `Bearer ${jwt}`,
          apikey,
          "Content-Type": "application/json",
        },
      });
      if (!res.ok) throw new Error(await res.text());
      return res.json();
    };

    const loadMaterial = async (id: string): Promise<Material> => {
      const rows = await asUser(
        `materials?id=eq.${id}&select=id,title,storage_path,source_url,mime_type`,
      );
      if (!rows.length) throw new Error("That material no longer exists.");
      return rows[0];
    };

    if (action === "generate_summary") {
      const material = await loadMaterial(body.materialId);
      const { parts, tools } = await sourceParts(
        supabaseUrl,
        jwt,
        apikey,
        material,
      );

      const instruction =
        `You summarise study material for a student revising it. The ` +
        `material is attached and is titled "${material.title}".\n\n` +
        `Break it into 3 to 6 sections, in the order the material covers ` +
        `them. Rules:\n` +
        `- A section title is a short noun phrase naming what that part is ` +
        `about. Not "Introduction" or "Section 1" unless the material really ` +
        `offers nothing better.\n` +
        `- 2 to 4 bullets per section. Each is one full sentence that states ` +
        `a fact from the material, not a topic label.\n` +
        `- Everything must come from the material. Do not add context, ` +
        `background or definitions it does not contain.\n` +
        `- Write for someone who has read it once and is coming back to it.\n` +
        `- If the material is too short for 3 sections, write fewer.`;

      const out = await callGemini({
        system_instruction: { parts: [{ text: instruction }] },
        contents: [{ role: "user", parts }],
        ...(tools ? { tools } : {}),
        generationConfig: {
          response_mime_type: "application/json",
          response_schema: SUMMARY_SCHEMA,
        },
      });

      return json({ items: JSON.parse(out) });
    }

    if (action === "generate_flashcards" || action === "generate_quiz") {
      const material = await loadMaterial(body.materialId);
      const { parts, tools } = await sourceParts(
        supabaseUrl,
        jwt,
        apikey,
        material,
      );
      const cards = action === "generate_flashcards";

      const instruction = cards
        ? `You write flashcards for a student revising the attached study ` +
          `material, titled "${material.title}".\n\n` +
          `Write exactly 4 cards. Rules:\n` +
          `- Every card must come from the material itself. Do not add facts ` +
          `that are not in it, and do not pad with general knowledge.\n` +
          `- The question is one sentence and asks for one idea.\n` +
          `- The answer is at most two sentences, in plain language.\n` +
          `- "source" says where in the material it came from — a section ` +
          `heading, or "p.4" for a page. If you cannot tell, use the ` +
          `material's title.\n` +
          `- Cover four different ideas. Do not ask the same thing twice.\n` +
          `- "difficulty" is 1 to 5 for how hard this card is for someone ` +
          `meeting the material for the first time. 1 is a definition or a ` +
          `fact stated plainly in the text; 5 needs several ideas combined, ` +
          `or a step that is easy to get backwards. Judge the card, not the ` +
          `subject, and do not rate everything 3.\n` +
          `- If the material is too short or too vague to make 4 real cards, ` +
          `make as many as it genuinely supports rather than inventing more.`
        : `You write quiz questions for a student revising the attached study ` +
          `material, titled "${material.title}".\n\n` +
          `Write exactly 4 multiple-choice questions. Rules:\n` +
          `- Every question must be answerable from the material alone.\n` +
          `- Exactly 4 options per question, and exactly one is correct.\n` +
          `- Wrong options must be plausible and about the same length as the ` +
          `right one. Never use "all of the above" or "none of the above".\n` +
          `- The explanation says why the right answer is right, in one or ` +
          `two sentences, referring to what the material actually says.\n` +
          `- Cover four different ideas.\n` +
          `- If the material cannot support 4 real questions, write fewer ` +
          `rather than inventing content.`;

      const out = await callGemini({
        system_instruction: { parts: [{ text: instruction }] },
        contents: [{ role: "user", parts }],
        ...(tools ? { tools } : {}),
        generationConfig: {
          response_mime_type: "application/json",
          response_schema: cards ? FLASHCARD_SCHEMA : QUIZ_SCHEMA,
        },
      });

      return json({ items: JSON.parse(out) });
    }

    if (action === "chat") {
      // The daily allowance, counted from rows the user cannot edit. The
      // client sends its UTC offset so "midnight" means their midnight; that
      // is a convenience, not a security boundary — spoofing it shifts the
      // window, it does not lift the cap.
      const offsetMinutes = Number(body.tzOffsetMinutes ?? 0);
      const now = new Date();
      const local = new Date(now.getTime() + offsetMinutes * 60_000);
      const startLocal = Date.UTC(
        local.getUTCFullYear(),
        local.getUTCMonth(),
        local.getUTCDate(),
      );
      const since = new Date(startLocal - offsetMinutes * 60_000).toISOString();

      const used = await asUser(
        `chat_messages?role=eq.user&created_at=gte.${since}&select=id`,
      );
      if (used.length >= CHAT_MESSAGES_PER_DAY) {
        return json({
          error: "limit",
          used: used.length,
          limit: CHAT_MESSAGES_PER_DAY,
        }, 429);
      }

      const question: string = body.question ?? "";
      const history: { role: string; text: string }[] = body.history ?? [];

      let parts: unknown[] = [];
      let tools: unknown[] | undefined;
      let heading = "The student has not chosen a document.";

      if (body.materialId) {
        const material = await loadMaterial(body.materialId);
        const source = await sourceParts(supabaseUrl, jwt, apikey, material);
        parts = source.parts;
        tools = source.tools;
        heading = `The student is asking about "${material.title}", attached.`;
      }

      const instruction =
        `You are Flow, a study assistant inside a revision app. ${heading}\n\n` +
        `Rules:\n` +
        `- Answer from the attached material. If the answer is not in it, ` +
        `say so plainly rather than answering from general knowledge.\n` +
        `- If no material is attached, say you need one chosen before you can ` +
        `answer about it, then answer only if the question is general.\n` +
        `- Be brief. Two or three short paragraphs at most, no preamble.\n` +
        `- Plain text. No markdown headings, no bullet characters.\n` +
        `- The student is revising, so explain rather than just assert.`;

      const contents = [
        { role: "user", parts: [...parts, { text: "This is my study material." }] },
        { role: "model", parts: [{ text: "Understood. Ask me about it." }] },
        ...history.map((m) => ({
          role: m.role === "flow" ? "model" : "user",
          parts: [{ text: m.text }],
        })),
        { role: "user", parts: [{ text: question }] },
      ];

      const answer = await callGemini({
        system_instruction: { parts: [{ text: instruction }] },
        contents,
        ...(tools ? { tools } : {}),
      });

      return json({
        answer,
        used: used.length + 1,
        limit: CHAT_MESSAGES_PER_DAY,
      });
    }

    if (action === "usage") {
      const offsetMinutes = Number(body.tzOffsetMinutes ?? 0);
      const now = new Date();
      const local = new Date(now.getTime() + offsetMinutes * 60_000);
      const startLocal = Date.UTC(
        local.getUTCFullYear(),
        local.getUTCMonth(),
        local.getUTCDate(),
      );
      const since = new Date(startLocal - offsetMinutes * 60_000).toISOString();
      const used = await asUser(
        `chat_messages?role=eq.user&created_at=gte.${since}&select=id`,
      );
      return json({ used: used.length, limit: CHAT_MESSAGES_PER_DAY });
    }

    return json({ error: `Unknown action "${action}".` }, 400);
  } catch (error) {
    return json({ error: String(error instanceof Error ? error.message : error) }, 500);
  }
});
