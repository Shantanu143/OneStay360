"use client";
import Link from "next/link";
import { useState } from "react";
import { Clock, MessageSquareText, Send, Trash2 } from "lucide-react";
import { Page, useShell } from "@/components/dash/shell";
import { pinCategories } from "@/components/dash/widgets";
import { Empty, Loading } from "@/components/ui";
import { useAction, useQuery } from "@/lib/hooks";
import { ago } from "@/lib/format";
import type { PinCategory } from "@/lib/types";

export default function PinboardPage() {
  const { account } = useShell();
  const { data, loading } = useQuery(async (b) => ({ stay: await b.getStay(), pins: await b.listPins() }));
  const { busy, run } = useAction();
  const [category, setCategory] = useState<PinCategory>("social");
  const [content, setContent] = useState("");
  const hoursLeft = (ms: number) => Math.max(0, Math.round((ms - Date.now()) / 3600_000));

  return (
    <Page title="Pinboard" sub={data?.stay ? `Notes for residents of ${data.stay.property.name} · expire after 48 hours` : "Your PG's notice board"}>
      {loading ? (
        <Loading />
      ) : !data?.stay ? (
        <div className="glass card">
          <Empty icon={MessageSquareText} title="Join a PG to use its pinboard" action={<Link href="/dashboard/tenant/explore/" className="btn btn-primary">Explore PGs</Link>} />
        </div>
      ) : (
        <>
          <form
            className="glass card stack"
            onSubmit={(e) => {
              e.preventDefault();
              void run((b) => b.addPin(category, content), "Pinned").then((r) => r.ok && setContent(""));
            }}
          >
            <div className="chips">
              {(Object.keys(pinCategories) as PinCategory[]).map((c) => (
                <button key={c} type="button" className="chip" aria-pressed={category === c} onClick={() => setCategory(c)}>
                  {pinCategories[c]!.emoji} {pinCategories[c]!.label}
                </button>
              ))}
            </div>
            <textarea className="textarea" maxLength={280} value={content} onChange={(e) => setContent(e.target.value)} placeholder="Ordering dinner? Lost your keys? Need a ride? Tell your housemates…" aria-label="Note" />
            <div className="row-between">
              <span className="faint" style={{ fontSize: 12 }}>
                {280 - content.length} characters left
              </span>
              <button className="btn btn-primary" disabled={busy || !content.trim()}>
                <Send size={16} /> Pin it
              </button>
            </div>
          </form>
          {data.pins.length === 0 ? (
            <div className="glass card">
              <Empty icon={MessageSquareText} title="No notes right now" body="Be the first to post." />
            </div>
          ) : (
            <div className="grid-3">
              {data.pins.map((p) => (
                <div key={p.id} className="glass card stack" style={{ gap: 10 }}>
                  <div className="row-between">
                    <span className="badge badge-green">
                      {pinCategories[p.category]?.emoji} {pinCategories[p.category]?.label}
                    </span>
                    <span className="faint row" style={{ gap: 4, fontSize: 12 }}>
                      <Clock size={12} /> {hoursLeft(p.expiresAt)}h left
                    </span>
                  </div>
                  <p style={{ fontSize: 15 }}>{p.content}</p>
                  <div className="row-between">
                    <span className="faint" style={{ fontSize: 12.5 }}>
                      {p.authorName} · {ago(p.createdAt)}
                    </span>
                    {p.authorUid === account.uid && (
                      <button className="icon-btn" style={{ width: 32, height: 32 }} aria-label="Delete note" disabled={busy} onClick={() => run((b) => b.deletePin(p.id), "Note removed")}>
                        <Trash2 size={14} />
                      </button>
                    )}
                  </div>
                </div>
              ))}
            </div>
          )}
        </>
      )}
    </Page>
  );
}
