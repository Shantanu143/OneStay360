"use client";
import Link from "next/link";
import { Bell, CheckCheck, ClipboardCheck, MailOpen, Receipt, Users, Wallet, Wrench } from "lucide-react";
import { Page } from "./shell";
import { Empty, Loading } from "../ui";
import { useAction, useQuery } from "@/lib/hooks";
import { ago, cls } from "@/lib/format";
import type { AppNotification } from "@/lib/types";

const icons: Record<AppNotification["kind"], typeof Bell> = { request: ClipboardCheck, payment: Wallet, maintenance: Wrench, invitation: MailOpen, billing: Receipt, team: Users, general: Bell };
const tones: Record<AppNotification["kind"], string> = { request: "blue", payment: "", maintenance: "amber", invitation: "blue", billing: "amber", team: "grey", general: "grey" };

export function NotificationsPage() {
  const { data, loading } = useQuery((b) => b.listNotifications());
  const { busy, run } = useAction();
  const unread = data?.filter((n) => !n.read).length ?? 0;
  return (
    <Page
      title="Notifications"
      sub={unread ? `${unread} unread` : "You're all caught up"}
      actions={
        unread > 0 && (
          <button className="btn btn-ghost btn-sm" disabled={busy} onClick={() => run((b) => b.markNotificationsRead())}>
            <CheckCheck size={15} /> Mark all read
          </button>
        )
      }
    >
      <div className="glass card">
        {loading ? (
          <Loading />
        ) : !data?.length ? (
          <Empty icon={Bell} title="No notifications yet" />
        ) : (
          <div className="list">
            {data.map((n) => {
              const Icon = icons[n.kind];
              const body = (
                <>
                  <span className={cls("tile-ic", tones[n.kind])}>
                    <Icon size={18} />
                  </span>
                  <div className="grow">
                    <div className="title" style={{ fontWeight: n.read ? 550 : 750 }}>
                      {n.title}
                    </div>
                    <div className="meta" style={{ whiteSpace: "normal" }}>
                      {n.body}
                    </div>
                  </div>
                  <span className="faint" style={{ fontSize: 12, whiteSpace: "nowrap" }}>
                    {ago(n.createdAt)}
                  </span>
                  {!n.read && <span style={{ width: 8, height: 8, borderRadius: 4, background: "var(--brand)", flex: "none" }} aria-label="Unread" />}
                </>
              );
              return n.href ? (
                <Link key={n.id} href={n.href} className="list-row" onClick={() => !n.read && run((b) => b.markNotificationsRead([n.id]))}>
                  {body}
                </Link>
              ) : (
                <button key={n.id} className="list-row" onClick={() => !n.read && run((b) => b.markNotificationsRead([n.id]))}>
                  {body}
                </button>
              );
            })}
          </div>
        )}
      </div>
    </Page>
  );
}
