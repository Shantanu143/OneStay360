import React, { useEffect, useState } from "react";
import { collection, getDocs, doc, writeBatch, Timestamp, getDoc } from "firebase/firestore";
import { db } from "../../lib/firebase";
import { Calendar, ShieldAlert, CircleDollarSign, CheckCircle2, RefreshCw, Clock, AlertTriangle } from "lucide-react";

interface BillingInvoice {
  id: string;
  invoiceId: string;
  businessId: string;
  propertyId: string;
  purpose: string;
  periodStart: Timestamp;
  periodEnd: Timestamp;
  baseAmount: number;
  finalAmount: number;
  status: string;
  dueDate: Timestamp;
  paidAt: Timestamp | null;
  createdAt: Timestamp;
}

interface PropertyMinInfo {
  id: string;
  name: string;
  city: string;
  businessId: string;
  businessName: string;
  totalBeds: number;
  nextBillingDate: Timestamp | null;
  billingStatus: string;
}

export default function BillingConsole() {
  const [invoices, setInvoices] = useState<BillingInvoice[]>([]);
  const [properties, setProperties] = useState<Record<string, PropertyMinInfo>>({});
  const [loading, setLoading] = useState(true);
  const [selectedInv, setSelectedInv] = useState<BillingInvoice | null>(null);
  const [updating, setUpdating] = useState(false);
  const [overrideDate, setOverrideDate] = useState("");
  const [statusFilter, setStatusFilter] = useState("all");

  async function fetchBillingData() {
    try {
      setLoading(true);

      // Fetch properties first for mapping names
      const propSnap = await getDocs(collection(db, "properties"));
      const propMap: Record<string, PropertyMinInfo> = {};
      propSnap.docs.forEach((doc) => {
        const d = doc.data();
        propMap[doc.id] = {
          id: doc.id,
          name: d.name || "Unnamed PG",
          city: d.city || "Unknown",
          businessId: d.businessId || "",
          businessName: d.businessName || "No Owner",
          totalBeds: d.totalBeds || 0,
          nextBillingDate: d.nextBillingDate || null,
          billingStatus: d.billingStatus || "trial",
        };
      });
      setProperties(propMap);

      // Fetch invoices
      const invSnap = await getDocs(collection(db, "billing_invoices"));
      const invList: BillingInvoice[] = invSnap.docs.map((doc) => {
        const d = doc.data();
        return {
          id: doc.id,
          invoiceId: d.invoiceId || doc.id,
          businessId: d.businessId || "",
          propertyId: d.propertyId || "",
          purpose: d.purpose || "monthly",
          periodStart: d.periodStart,
          periodEnd: d.periodEnd,
          baseAmount: d.baseAmount || 0,
          finalAmount: d.finalAmount || 0,
          status: d.status || "due",
          dueDate: d.dueDate,
          paidAt: d.paidAt || null,
          createdAt: d.createdAt,
        };
      });

      // Sort newest first
      invList.sort((a, b) => b.createdAt?.toMillis() - a.createdAt?.toMillis());
      setInvoices(invList);
    } catch (e) {
      console.error("Error loading billing data:", e);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    fetchBillingData();
  }, []);

  async function handleMarkPaid(invoice: BillingInvoice) {
    try {
      setUpdating(true);
      const batch = writeBatch(db);
      const now = Timestamp.now();

      // 1. Update Invoice in global invoices
      batch.update(doc(db, "billing_invoices", invoice.id), {
        status: "paid",
        paidAt: now,
      });

      // 2. Find property config
      const propInfo = properties[invoice.propertyId];
      if (propInfo) {
        const globalPropRef = doc(db, "properties", invoice.propertyId);
        const bizPropRef = doc(db, `businesses/${propInfo.businessId}/properties/${invoice.propertyId}`);
        const cityPropRef = doc(db, `properties_by_city/${propInfo.city}/properties/${invoice.propertyId}`);

        // Get actual doc to check if it exists in city index
        const citySnap = await getDoc(cityPropRef);

        const updates = {
          billingStatus: "paid",
          status: "active", // Reactivate if it was suspended due to billing
          updatedAt: now,
        };

        batch.update(globalPropRef, updates);
        batch.update(bizPropRef, updates);
        if (citySnap.exists()) {
          batch.update(cityPropRef, updates);
        }

        // Also update subcollection invoice
        batch.update(doc(db, `businesses/${propInfo.businessId}/properties/${invoice.propertyId}/invoices`, invoice.invoiceId), {
          status: "paid",
          paidAt: now,
        });
      }

      await batch.commit();
      await fetchBillingData();
      setSelectedInv(null);
    } catch (e) {
      console.error("Error marking invoice paid:", e);
      alert("Failed to update payment status.");
    } finally {
      setUpdating(false);
    }
  }

  async function handleOverrideBillingDate(invoice: BillingInvoice) {
    if (!overrideDate) return;
    try {
      setUpdating(true);
      const selectedDate = new Date(overrideDate);
      const newBillingTimestamp = Timestamp.fromDate(selectedDate);
      const propInfo = properties[invoice.propertyId];

      if (!propInfo) {
        alert("Property metadata not found.");
        return;
      }

      const batch = writeBatch(db);
      const globalPropRef = doc(db, "properties", invoice.propertyId);
      const bizPropRef = doc(db, `businesses/${propInfo.businessId}/properties/${invoice.propertyId}`);
      const cityPropRef = doc(db, `properties_by_city/${propInfo.city}/properties/${invoice.propertyId}`);

      const citySnap = await getDoc(cityPropRef);
      const updates = {
        nextBillingDate: newBillingTimestamp,
        billingStatus: "paid", // Reset billing status to healthy since we extended
        updatedAt: Timestamp.now(),
      };

      batch.update(globalPropRef, updates);
      batch.update(bizPropRef, updates);
      if (citySnap.exists()) {
        batch.update(cityPropRef, updates);
      }

      await batch.commit();
      await fetchBillingData();
      setSelectedInv(null);
      setOverrideDate("");
      alert("Billing date successfully extended!");
    } catch (e) {
      console.error("Error updating billing date:", e);
      alert("Failed to update billing date.");
    } finally {
      setUpdating(false);
    }
  }

  async function handleManualGenerateInvoice(propertyId: string) {
    const propInfo = properties[propertyId];
    if (!propInfo) return;

    try {
      setUpdating(true);
      const periodStart = propInfo.nextBillingDate || Timestamp.now();
      const startDate = periodStart.toDate();
      const periodEnd = new Date(startDate);
      periodEnd.setDate(periodEnd.getDate() + 30);
      const dueDate = new Date(startDate);
      dueDate.setDate(dueDate.getDate() + 5);

      const baseAmount = propInfo.totalBeds * 30; // ₹30 per bed
      const invoiceId = `${propertyId}_manual_${Date.now()}`;

      const invoiceData = {
        invoiceId,
        businessId: propInfo.businessId,
        propertyId,
        purpose: "monthly",
        periodStart,
        periodEnd: Timestamp.fromDate(periodEnd),
        baseAmount,
        discountAmount: 0,
        finalAmount: baseAmount,
        status: "due",
        dueDate: Timestamp.fromDate(dueDate),
        paidAt: null,
        paymentId: null,
        promoCode: null,
        createdAt: Timestamp.now(),
      };

      const batch = writeBatch(db);
      batch.set(doc(db, "billing_invoices", invoiceId), invoiceData);
      batch.set(doc(db, `businesses/${propInfo.businessId}/properties/${propertyId}/invoices`, invoiceId), {
        ...invoiceData,
        type: "monthly",
        amount: baseAmount,
      });

      // Update property billing status
      const updates = {
        billingStatus: "due",
        updatedAt: Timestamp.now(),
      };
      batch.update(doc(db, "properties", propertyId), updates);
      batch.update(doc(db, `businesses/${propInfo.businessId}/properties/${propertyId}`), updates);
      
      const cityPropRef = doc(db, `properties_by_city/${propInfo.city}/properties/${propertyId}`);
      const citySnap = await getDoc(cityPropRef);
      if (citySnap.exists()) {
        batch.update(cityPropRef, updates);
      }

      await batch.commit();
      await fetchBillingData();
      alert("Manual platform invoice generated successfully!");
    } catch (e) {
      console.error("Error generating manual invoice:", e);
      alert("Failed to generate manual invoice.");
    } finally {
      setUpdating(false);
    }
  }

  const filteredInvoices = invoices.filter((inv) => {
    if (statusFilter === "all") return true;
    return inv.status === statusFilter;
  });

  if (loading) {
    return (
      <div className="overviewLoading">
        <div className="spinner"></div>
        <p>Loading Platform Invoices...</p>
      </div>
    );
  }

  return (
    <div className="consoleContainer">
      <div className="dashboardHeader">
        <h2>Platform Billing & Invoices</h2>
        <p>Audit monthly ₹30/bed licensing invoices, force payment confirmations, and adjust PG renewal dates.</p>
      </div>

      <div className="filterBand">
        <div className="filterGroup">
          <label>Status Filter:</label>
          <select value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)} className="adminSelect">
            <option value="all">All Invoices</option>
            <option value="due">Due</option>
            <option value="grace">Grace</option>
            <option value="past_due">Past Due</option>
            <option value="suspended">Suspended</option>
            <option value="paid">Paid</option>
          </select>
        </div>
        <button onClick={fetchBillingData} className="refreshBtn">
          <RefreshCw size={16} /> Refresh
        </button>
      </div>

      <div className="tableWrapper">
        <table className="adminTable">
          <thead>
            <tr>
              <th>Invoice ID</th>
              <th>Property Name</th>
              <th>Period</th>
              <th>Total Amount</th>
              <th>Due Date</th>
              <th>Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {filteredInvoices.map((inv) => {
              const prop = properties[inv.propertyId];
              return (
                <tr key={inv.id}>
                  <td>
                    <strong>{inv.invoiceId.substring(0, 18)}...</strong>
                    <span className="subtext">Prop ID: {inv.propertyId}</span>
                  </td>
                  <td>
                    <strong>{prop?.name || "Unknown PG"}</strong>
                    <span className="subtext">{prop?.businessName || "No Landlord"}</span>
                  </td>
                  <td>
                    <span className="dateSpan">
                      {inv.periodStart?.toDate().toLocaleDateString("en-IN")} - {inv.periodEnd?.toDate().toLocaleDateString("en-IN")}
                    </span>
                  </td>
                  <td>
                    <strong className="textTeal">₹{inv.finalAmount.toLocaleString("en-IN")}</strong>
                    <span className="subtext">₹30/bed × {prop?.totalBeds || 0} beds</span>
                  </td>
                  <td>{inv.dueDate?.toDate().toLocaleDateString("en-IN")}</td>
                  <td>
                    <span className={`badge ${inv.status}`}>
                      {inv.status.toUpperCase()}
                    </span>
                  </td>
                  <td>
                    <button className="tableActionBtn" onClick={() => setSelectedInv(inv)}>
                      Manage Invoice
                    </button>
                  </td>
                </tr>
              );
            })}
            {filteredInvoices.length === 0 && (
              <tr>
                <td colSpan={7} style={{ textAlign: "center", padding: "24px", color: "#64748B" }}>
                  No invoices found matching the selected filter.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      {selectedInv && (
        <div className="modalOverlay" onClick={() => setSelectedInv(null)}>
          <div className="modalCard" onClick={(e) => e.stopPropagation()}>
            <div className="modalHeader">
              <h3>Platform Invoice Audit</h3>
              <button className="closeBtn" onClick={() => setSelectedInv(null)}>×</button>
            </div>
            <div className="modalBody">
              <div className="invoiceInfoSummary">
                <div className="summaryRow">
                  <span>Invoice ID:</span>
                  <strong>{selectedInv.invoiceId}</strong>
                </div>
                <div className="summaryRow">
                  <span>Property:</span>
                  <strong>{properties[selectedInv.propertyId]?.name || "Unknown"}</strong>
                </div>
                <div className="summaryRow">
                  <span>Landlord Chain:</span>
                  <strong>{properties[selectedInv.propertyId]?.businessName || "Unknown"}</strong>
                </div>
                <div className="summaryRow">
                  <span>Billing Period:</span>
                  <span>{selectedInv.periodStart?.toDate().toLocaleDateString("en-IN")} to {selectedInv.periodEnd?.toDate().toLocaleDateString("en-IN")}</span>
                </div>
                <div className="summaryRow">
                  <span>Base Licensing Fee:</span>
                  <strong className="textTeal">₹{selectedInv.finalAmount}</strong>
                </div>
                <div className="summaryRow">
                  <span>Current Invoice Status:</span>
                  <span className={`badge ${selectedInv.status}`}>{selectedInv.status.toUpperCase()}</span>
                </div>
                {selectedInv.paidAt && (
                  <div className="summaryRow">
                    <span>Paid At:</span>
                    <span>{selectedInv.paidAt.toDate().toLocaleString("en-IN")}</span>
                  </div>
                )}
              </div>

              <div className="overrideFormSection">
                <h4><Calendar size={16} /> Extension & Override Tools</h4>
                <div className="formGroup">
                  <label>Extend Next Billing Date:</label>
                  <div className="overrideInputGroup">
                    <input
                      type="date"
                      value={overrideDate}
                      onChange={(e) => setOverrideDate(e.target.value)}
                      className="adminDateInput"
                    />
                    <button
                      className="overrideBtn"
                      disabled={updating || !overrideDate}
                      onClick={() => handleOverrideBillingDate(selectedInv)}
                    >
                      Override Date
                    </button>
                  </div>
                  <span className="subtext">
                    Current Billing Cycle Date:{" "}
                    <strong>
                      {properties[selectedInv.propertyId]?.nextBillingDate?.toDate().toLocaleDateString("en-IN") || "None"}
                    </strong>
                  </span>
                </div>

                <div className="dangerActionsSection">
                  <label>Manual Triggers:</label>
                  <button
                    className="manualGenerateBtn"
                    disabled={updating}
                    onClick={() => handleManualGenerateInvoice(selectedInv.propertyId)}
                  >
                    <RefreshCw size={14} /> Force-Generate Next Billing Invoice
                  </button>
                </div>
              </div>
            </div>
            <div className="modalFooter">
              {selectedInv.status !== "paid" && (
                <button
                  className="approveBtn"
                  disabled={updating}
                  onClick={() => handleMarkPaid(selectedInv)}
                >
                  <CheckCircle2 size={16} /> Force Mark Paid
                </button>
              )}
              <button className="rejectBtn" onClick={() => setSelectedInv(null)}>
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
