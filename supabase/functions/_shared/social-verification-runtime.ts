import { createClient } from "npm:@supabase/supabase-js@2.57.4";

export function socialRuntime() {
  const db = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );
  const checked = <T>(result: { data: T; error: unknown }) => {
    if (result.error) throw new Error("database_error");
    return result.data;
  };
  return {
    env: (key: string) => Deno.env.get(key),
    fetcher: fetch,
    authenticate: async (token: string) => {
      const { data, error } = await db.auth.getUser(token);
      if (error || !data.user || data.user.is_anonymous) return null;
      try {
        // Claims are read only after getUser verifies the very same token.
        const part = token.split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
        const session = JSON.parse(atob(part)).session_id;
        if (typeof session !== "string" || !/^[0-9a-f-]{36}$/i.test(session)) {
          return null;
        }
        return { id: data.user.id, session_id: session };
      } catch {
        return null;
      }
    },
    start: async (
      owner: string,
      session: string,
      provider: string,
      hash: string,
    ) => {
      return {
        id: checked(
          await db.rpc("social_verification_start", {
            p_owner: owner,
            p_session: session,
            p_provider: provider,
            p_hash: hash,
          }),
        ),
      };
    },
    list: async (owner: string) =>
      checked(
        await db.from("social_verification_proofs").select(
          "provider,label,verified_at",
        ).eq("owner_id", owner),
      ),
    status: async (owner: string, session: string, id: string) =>
      checked(
        await db.from("social_verification_attempts").select(
          "provider,status,label,expires_at",
        ).eq("id", id).eq("owner_id", owner).eq("session_id", session)
          .maybeSingle(),
      ),
    disconnect: async (owner: string, provider: string) => {
      checked(
        await db.rpc("social_verification_disconnect", {
          p_owner: owner,
          p_provider: provider,
        }),
      );
    },
    cancel: async (owner: string, session: string, id: string) => {
      checked(
        await db.from("social_verification_attempts").update({
          status: "denied",
        }).eq("id", id).eq("owner_id", owner).eq("session_id", session).in(
          "status",
          ["pending", "processing"],
        ),
      );
    },
    consume: async (hash: string) => {
      const rows = checked(
        await db.rpc("social_verification_consume", { p_hash: hash }),
      );
      return rows?.[0] ?? null;
    },
    finish: async (id: string, subject: string, label: string) => {
      checked(
        await db.rpc("social_verification_finish", {
          p_attempt: id,
          p_subject: subject,
          p_label: label,
        }),
      );
    },
    fail: async (id: string, status: string) => {
      checked(
        await db.from("social_verification_attempts").update({ status }).eq(
          "id",
          id,
        ).eq("status", "processing"),
      );
    },
    providerRemove: async (
      provider: string,
      subject: string,
      deletion: boolean,
      hash: string,
    ) =>
      checked(
        await db.rpc("social_verification_provider_remove", {
          p_provider: provider,
          p_subject: subject,
          p_deletion: deletion,
          p_request_hash: hash,
        }),
      ),
    deletionStatus: async (id: string) =>
      !!checked(
        await db.from("social_verification_deletions").select("id").eq("id", id)
          .gt("expires_at", new Date().toISOString()).maybeSingle(),
      ),
  };
}
