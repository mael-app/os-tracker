export interface Env {
  DB: D1Database;
  AUTH_TOKEN: string;
}

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Authorization, Content-Type",
  "Access-Control-Max-Age": "86400",
};

const ONLINE_THRESHOLD_SECS = 300;

interface MachineRow {
  os: string;
  last_seen: number;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    if (url.pathname === "/heartbeat" && request.method === "POST") {
      const auth = request.headers.get("Authorization");
      if (!auth || auth !== `Bearer ${env.AUTH_TOKEN}`) {
        return Response.json({ error: "Unauthorized" }, { status: 401, headers: CORS_HEADERS });
      }

      let body: { os?: string };
      try {
        body = await request.json();
      } catch {
        return Response.json({ error: "Invalid JSON payload" }, { status: 400, headers: CORS_HEADERS });
      }

      if (body.os !== "macos" && body.os !== "linux") {
        return Response.json({ error: "Invalid or unsupported OS value" }, { status: 400, headers: CORS_HEADERS });
      }

      const now = Math.floor(Date.now() / 1000);
      await env.DB.prepare(
        "INSERT INTO machines (os, last_seen) VALUES (?, ?) ON CONFLICT(os) DO UPDATE SET last_seen = excluded.last_seen"
      )
        .bind(body.os, now)
        .run();

      return Response.json({ ok: true }, { headers: CORS_HEADERS });
    }

    if (url.pathname === "/status" && request.method === "GET") {
      const { results } = await env.DB.prepare(
        "SELECT os, last_seen FROM machines"
      ).all<MachineRow>();

      const now = Math.floor(Date.now() / 1000);
      const machines = (results ?? []).map((row) => ({
        os: row.os,
        online: now - row.last_seen <= ONLINE_THRESHOLD_SECS,
        last_seen: row.last_seen * 1000,
      }));

      const anyOnline = machines.some((m) => m.online);

      return new Response(JSON.stringify({ online: anyOnline, machines }), {
        headers: {
          ...CORS_HEADERS,
          "Content-Type": "application/json",
          "Cache-Control": "no-cache, no-store",
        },
      });
    }

    return Response.json({ error: "Not Found" }, { status: 404, headers: CORS_HEADERS });
  },
};
