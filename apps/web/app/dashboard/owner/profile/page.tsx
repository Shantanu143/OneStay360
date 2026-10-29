"use client";
import { useEffect, useState } from "react";
import { BadgeCheck, Briefcase } from "lucide-react";
import { Page, useShell } from "@/components/dash/shell";
import { AccountCard } from "@/components/dash/account";
import { Field, Loading, StatusBadge } from "@/components/ui";
import { useAction, useQuery } from "@/lib/hooks";
import { date } from "@/lib/format";
import { permissions } from "@/lib/permissions";

export default function OwnerProfilePage() {
  const { account } = useShell();
  const isOwner = permissions(account.role).canViewBilling;
  const { busy, run } = useAction();
  const { data: business, loading } = useQuery((b) => b.getBusiness());
  const [biz, setBiz] = useState({ name: "", phone: "", email: "", city: "", address: "" });
  const [kyc, setKyc] = useState({ legalName: "", pan: "", gstin: "", aadhaarLast4: "" });
  useEffect(() => {
    if (business) {
      setBiz({ name: business.name, phone: business.phone, email: business.email, city: business.city, address: business.address });
      setKyc({ legalName: business.kyc?.legalName ?? business.name, pan: business.kyc?.pan ?? "", gstin: business.kyc?.gstin ?? "", aadhaarLast4: business.kyc?.aadhaarLast4 ?? "" });
    }
  }, [business]);

  return (
    <Page title="Profile & KYC" sub="Your account and business details">
      <AccountCard />
      {loading ? (
        <Loading />
      ) : (
        business && (
          <div className="grid-2">
            <div className="glass card stack">
              <div className="row">
                <span className="feature-ic">
                  <Briefcase size={22} />
                </span>
                <div>
                  <h2 className="h3">{business.name}</h2>
                  <div className="faint" style={{ fontSize: 13 }}>
                    {business.id} · you are {account.role}
                  </div>
                </div>
              </div>
              <div className="form-grid">
                <Field label="Business name" full>
                  <input className="input" disabled={!isOwner} value={biz.name} onChange={(e) => setBiz({ ...biz, name: e.target.value })} />
                </Field>
                <Field label="Phone">
                  <input className="input" disabled={!isOwner} value={biz.phone} onChange={(e) => setBiz({ ...biz, phone: e.target.value })} />
                </Field>
                <Field label="Email">
                  <input className="input" disabled={!isOwner} value={biz.email} onChange={(e) => setBiz({ ...biz, email: e.target.value })} />
                </Field>
                <Field label="City">
                  <input className="input" disabled={!isOwner} value={biz.city} onChange={(e) => setBiz({ ...biz, city: e.target.value })} />
                </Field>
                <Field label="Address">
                  <input className="input" disabled={!isOwner} value={biz.address} onChange={(e) => setBiz({ ...biz, address: e.target.value })} />
                </Field>
              </div>
              {isOwner && (
                <button className="btn btn-primary" style={{ alignSelf: "flex-start" }} disabled={busy} onClick={() => run((b) => b.updateBusiness(biz), "Business updated")}>
                  Save business
                </button>
              )}
            </div>
            <div className="glass card stack">
              <div className="row-between">
                <div className="row">
                  <span className="feature-ic">
                    <BadgeCheck size={22} />
                  </span>
                  <div>
                    <h2 className="h3">KYC</h2>
                    <div className="faint" style={{ fontSize: 13 }}>
                      Needed for online rent collection
                    </div>
                  </div>
                </div>
                <StatusBadge status={business.kycStatus} />
              </div>
              {business.kyc && (
                <p className="muted" style={{ fontSize: 13 }}>
                  Submitted {date(business.kyc.submittedAt)}
                </p>
              )}
              {isOwner ? (
                <>
                  <div className="form-grid">
                    <Field label="Legal name" full>
                      <input className="input" value={kyc.legalName} onChange={(e) => setKyc({ ...kyc, legalName: e.target.value })} />
                    </Field>
                    <Field label="PAN">
                      <input className="input" value={kyc.pan} onChange={(e) => setKyc({ ...kyc, pan: e.target.value.toUpperCase() })} placeholder="ABCDE1234F" />
                    </Field>
                    <Field label="GSTIN (optional)">
                      <input className="input" value={kyc.gstin} onChange={(e) => setKyc({ ...kyc, gstin: e.target.value.toUpperCase() })} />
                    </Field>
                    <Field label="Aadhaar (last 4 digits)">
                      <input className="input" inputMode="numeric" maxLength={4} value={kyc.aadhaarLast4} onChange={(e) => setKyc({ ...kyc, aadhaarLast4: e.target.value })} />
                    </Field>
                  </div>
                  <button className="btn btn-primary" style={{ alignSelf: "flex-start" }} disabled={busy} onClick={() => run((b) => b.submitKyc(kyc), "KYC submitted for review")}>
                    {business.kycStatus === "not_started" ? "Submit KYC" : "Update KYC"}
                  </button>
                </>
              ) : (
                <p className="muted">Only the owner can manage KYC.</p>
              )}
            </div>
          </div>
        )
      )}
    </Page>
  );
}
