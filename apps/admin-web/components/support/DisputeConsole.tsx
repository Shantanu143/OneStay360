import React, { useEffect, useState } from "react";
import { collectionGroup, getDocs, doc, writeBatch, query, where, getDoc, Timestamp } from "firebase/firestore";
import { db } from "../../lib/firebase";
import { CheckCircle2, XCircle, AlertCircle, Image as ImageIcon, ExternalLink, RefreshCw, FileText } from "lucide-react";

interface PaymentDispute {
  id: string;
  tenantId: string;
  businessId: string;
  tenantName: string;
  roomNumber: string;
  bedNumber: string;
  amount: number;
  month: string;
  date: Timestamp;
  status: string;
  method: string;
  transactionId: string | null;
  screenshotUrl: string | null;
  rentInvoiceId?: string;
  createdAt: Timestamp;
  refPath: string; // reconstructed ref path
}

export default function DisputeConsole() {
  const [disputes, setDisputes] = useState<PaymentDispute[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedDispute, setSelectedDispute] = useState<PaymentDispute | null>(null);
  const [updating, setUpdating] = useState(false);
  const [rejectionReason, setRejectionReason] = useState("");
  const [showRejectForm, setShowRejectForm] = useState(false);

  async function fetchDisputes() {
    try {
      setLoading(true);
      const q = query(collectionGroup(db, "payments"), where("status", "==", "pending_verification"));
      const querySnap = await getDocs(q);
      
      const disputeList: PaymentDispute[] = querySnap.docs.map((docSnap) => {
        const d = docSnap.data();
        // Path structure: businesses/{bizId}/tenants/{tenantId}/payments/{paymentId}
        const refPath = docSnap.ref.path;
        return {
          id: docSnap.id,
          tenantId: d.tenantId || "",
          businessId: d.businessId || "",
          tenantName: d.tenantName || "Unknown Tenant",
          roomNumber: d.roomNumber || "",
          bedNumber: d.bedNumber || "",
          amount: d.amount || 0,
          month: d.month || "",
          date: d.date || d.createdAt,
          status: d.status || "pending_verification",
          method: d.method || "UPI",
          transactionId: d.transactionId || null,
          screenshotUrl: d.screenshotUrl || null,
          rentInvoiceId: d.rentInvoiceId,
          createdAt: d.createdAt,
          refPath,
        };
      });

      setDisputes(disputeList);
    } catch (e) {
      console.error("Error loading payment disputes:", e);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    fetchDisputes();
  }, []);

  async function handleConfirmPayment(dispute: PaymentDispute) {
    try {
      setUpdating(true);
      const batch = writeBatch(db);
      const now = Timestamp.now();

      // 1. Update Payment status to Paid
      const paymentRef = doc(db, dispute.refPath);
      batch.update(paymentRef, {
        status: "Paid",
        verifiedBy: "super_admin_ops",
        verifiedAt: now,
        updatedAt: now,
      });

      // 2. Update nested tenant doc: businesses/{businessId}/tenants/{tenantId}
      const bizTenantRef = doc(db, `businesses/${dispute.businessId}/tenants/${dispute.tenantId}`);
      batch.update(bizTenantRef, {
        lastPaymentDate: now,
        lastPaymentAmount: dispute.amount,
        lastPaymentMonth: dispute.month,
        updatedAt: now,
      });

      // 3. Update global tenant doc: tenants/{tenantId}
      const globalTenantRef = doc(db, `tenants/${dispute.tenantId}`);
      const globalTenantSnap = await getDoc(globalTenantRef);
      if (globalTenantSnap.exists()) {
        batch.update(globalTenantRef, {
          lastPaymentDate: now,
          lastPaymentAmount: dispute.amount,
          updatedAt: now,
        });
      }

      // 4. Update the rent_invoice to paid
      if (dispute.rentInvoiceId) {
        const invoiceRef = doc(
          db,
          `businesses/${dispute.businessId}/tenants/${dispute.tenantId}/rent_invoices/${dispute.rentInvoiceId}`
        );
        const invoiceSnap = await getDoc(invoiceRef);
        if (invoiceSnap.exists() && invoiceSnap.data()?.status !== "paid") {
          batch.update(invoiceRef, {
            status: "paid",
            paidAt: now,
            verification: "verified",
            mode: dispute.method || "manual_override",
            updatedAt: now,
          });
        }
      } else {
        // Fallback: query invoice for matching month
        const invoiceColRef = getDocs(
          query(
            collectionGroup(db, "rent_invoices"),
            where("tenantId", "==", dispute.tenantId),
            where("month", "==", dispute.month),
            where("status", "in", ["unpaid", "overdue"])
          )
        );
        const invoiceSnap = await invoiceColRef;
        if (!invoiceSnap.empty) {
          batch.update(invoiceSnap.docs[0].ref, {
            status: "paid",
            paidAt: now,
            verification: "verified",
            mode: dispute.method || "manual_override",
            updatedAt: now,
          });
        }
      }

      await batch.commit();
      await fetchDisputes();
      setSelectedDispute(null);
      alert("Payment successfully force-confirmed!");
    } catch (e) {
      console.error("Error confirming rent payment:", e);
      alert("Failed to confirm rent payment. Check console.");
    } finally {
      setUpdating(false);
    }
  }

  async function handleRejectPayment(dispute: PaymentDispute) {
    if (!rejectionReason.trim()) {
      alert("Please provide a rejection reason.");
      return;
    }

    try {
      setUpdating(true);
      const batch = writeBatch(db);
      const now = Timestamp.now();

      const paymentRef = doc(db, dispute.refPath);
      batch.update(paymentRef, {
        status: "rejected",
        rejectionReason,
        rejectedBy: "super_admin_ops",
        rejectedAt: now,
        updatedAt: now,
      });

      await batch.commit();
      await fetchDisputes();
      setSelectedDispute(null);
      setRejectionReason("");
      setShowRejectForm(false);
      alert("Payment submission rejected.");
    } catch (e) {
      console.error("Error rejecting rent payment:", e);
      alert("Failed to reject payment.");
    } finally {
      setUpdating(false);
    }
  }

  if (loading) {
    return (
      <div className="overviewLoading">
        <div className="spinner"></div>
        <p>Loading Pending Payment Verification Disputes...</p>
      </div>
    );
  }

  return (
    <div className="consoleContainer">
      <div className="dashboardHeader">
        <h2>Rent Payment & Dispute Desk</h2>
        <p>Resolve rent transaction discrepancies. Audit tenant offline receipts, check transaction references, and force-verify rent status.</p>
      </div>

      <div className="filterBand">
        <div className="filterGroup">
          <span className="infoLabel"><AlertCircle size={16} /> Total Pending Disputes: <strong>{disputes.length}</strong></span>
        </div>
        <button onClick={fetchDisputes} className="refreshBtn">
          <RefreshCw size={16} /> Refresh Disputes
        </button>
      </div>

      <div className="tableWrapper">
        <table className="adminTable">
          <thead>
            <tr>
              <th>Tenant Info</th>
              <th>Rent Month</th>
              <th>Rent Amount</th>
              <th>Payment Method</th>
              <th>Transaction ID / Reference</th>
              <th>Receipt Screenshot</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {disputes.map((d) => (
              <tr key={d.id}>
                <td>
                  <strong>{d.tenantName}</strong>
                  <span className="subtext">ID: {d.tenantId}</span>
                  <span className="subtext">Room {d.roomNumber} - Bed {d.bedNumber}</span>
                </td>
                <td>
                  <span className="cityLabel">{d.month}</span>
                </td>
                <td>
                  <strong className="textTeal">₹{d.amount.toLocaleString("en-IN")}</strong>
                </td>
                <td>{d.method.toUpperCase()}</td>
                <td>
                  {d.transactionId ? (
                    <span className="txnRef">{d.transactionId}</span>
                  ) : (
                    <span className="subtext italic">No Txn ID submitted</span>
                  )}
                </td>
                <td>
                  {d.screenshotUrl ? (
                    <button 
                      className="screenshotBtn" 
                      onClick={() => { setSelectedDispute(d); setShowRejectForm(false); }}
                      title="Click to view full receipt"
                    >
                      <ImageIcon size={16} /> View Image
                    </button>
                  ) : (
                    <span className="subtext italic">No receipt uploaded</span>
                  )}
                </td>
                <td>
                  <button 
                    className="tableActionBtn"
                    onClick={() => { setSelectedDispute(d); setShowRejectForm(false); }}
                  >
                    Resolve Dispute
                  </button>
                </td>
              </tr>
            ))}
            {disputes.length === 0 && (
              <tr>
                <td colSpan={7} style={{ textAlign: "center", padding: "24px", color: "#64748B" }}>
                  🎉 All caught up! No pending rent payment verification disputes found.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      {selectedDispute && (
        <div className="modalOverlay" onClick={() => setSelectedDispute(null)}>
          <div className="modalCard maxModal" onClick={(e) => e.stopPropagation()}>
            <div className="modalHeader">
              <h3>Dispute Mediation Desk: {selectedDispute.tenantName}</h3>
              <button className="closeBtn" onClick={() => setSelectedDispute(null)}>×</button>
            </div>
            <div className="modalBody scrollableModal">
              <div className="propertyAuditGrid">
                <div>
                  <div className="propSection">
                    <label>Transaction Details</label>
                    <div className="specSnapshot">
                      <p>Tenant Name: <strong>{selectedDispute.tenantName}</strong></p>
                      <p>Tenant ID: <strong>{selectedDispute.tenantId}</strong></p>
                      <p>Rent Month: <strong>{selectedDispute.month}</strong></p>
                      <p>Claimed Payment Mode: <strong>{selectedDispute.method.toUpperCase()}</strong></p>
                      <p>Transaction ID: <code className="textTeal">{selectedDispute.transactionId || "NONE PROVIDED"}</code></p>
                      <p>Amount: <strong className="textTeal">₹{selectedDispute.amount.toLocaleString("en-IN")}</strong></p>
                      <p>Submitted On: <strong>{selectedDispute.date?.toDate().toLocaleString("en-IN") || "Unknown Date"}</strong></p>
                    </div>
                  </div>
                  
                  {showRejectForm ? (
                    <div className="propSection rejectFormArea">
                      <label className="textDanger">Rejection Audit Log</label>
                      <textarea
                        placeholder="Provide reason for rejecting the payment receipt proof (e.g. invalid screenshot, incorrect amount)..."
                        value={rejectionReason}
                        onChange={(e) => setRejectionReason(e.target.value)}
                        className="adminTextarea"
                        rows={4}
                      />
                      <div className="formActions">
                        <button 
                          className="rejectBtn inlineBtn" 
                          onClick={() => handleRejectPayment(selectedDispute)}
                          disabled={updating || !rejectionReason.trim()}
                        >
                          Confirm Rejection
                        </button>
                        <button className="secondaryBtn inlineBtn" onClick={() => setShowRejectForm(false)}>
                          Back
                        </button>
                      </div>
                    </div>
                  ) : (
                    <div className="propSection disputeHelpNotice">
                      <p className="noticeText">
                        <AlertCircle size={16} /> <strong>Operations Guildeline:</strong> Review the uploaded payment receipt screenshot on the right. Verify if the transaction ID corresponds to the landlord's account statements.
                      </p>
                    </div>
                  )}
                </div>

                <div className="auditSidebar">
                  <div className="propSection">
                    <label>Uploaded Proof Image</label>
                    {selectedDispute.screenshotUrl ? (
                      <div className="fullScreenshotContainer">
                        <img 
                          src={selectedDispute.screenshotUrl} 
                          alt="Rent payment receipt screenshot proof" 
                          className="disputeScreenshotImg"
                        />
                        <a 
                          href={selectedDispute.screenshotUrl} 
                          target="_blank" 
                          rel="noopener noreferrer" 
                          className="openExternalBtn"
                        >
                          Open in New Tab <ExternalLink size={14} />
                        </a>
                      </div>
                    ) : (
                      <div className="noScreenshotPlaceholder">
                        <FileText size={48} color="#64748B" />
                        <p>No receipt image was uploaded for this transaction</p>
                      </div>
                    )}
                  </div>
                </div>
              </div>
            </div>
            <div className="modalFooter">
              {!showRejectForm && (
                <>
                  <button
                    className="approveBtn"
                    disabled={updating}
                    onClick={() => handleConfirmPayment(selectedDispute)}
                  >
                    <CheckCircle2 size={16} /> Force Confirm (Mark Paid)
                  </button>
                  <button
                    className="rejectBtn"
                    disabled={updating}
                    onClick={() => setShowRejectForm(true)}
                  >
                    <XCircle size={16} /> Reject Proof
                  </button>
                </>
              )}
              <button className="closeActionBtn" onClick={() => setSelectedDispute(null)}>
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
