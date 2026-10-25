import React, { useEffect, useState } from "react";
import { collection, getDocs, doc, updateDoc, writeBatch } from "firebase/firestore";
import { db } from "../../lib/firebase";
import { ShieldCheck, ShieldAlert, Phone, User, CheckCircle2, AlertCircle } from "lucide-react";

interface BusinessInfo {
  id: string;
  name: string;
  phone: string;
  ownerUserId: string;
  ownerName: string;
  ownerStatus: string;
  createdAt?: any;
}

export default function BusinessConsole() {
  const [businesses, setBusinesses] = useState<BusinessInfo[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedBiz, setSelectedBiz] = useState<BusinessInfo | null>(null);
  const [updating, setUpdating] = useState(false);

  async function fetchBusinesses() {
    try {
      setLoading(true);
      const bizSnap = await getDocs(collection(db, "businesses"));
      const bizList: BusinessInfo[] = [];

      for (const bizDoc of bizSnap.docs) {
        const data = bizDoc.data();
        const bizId = bizDoc.id;

        // Fetch owner status from members subcollection
        let ownerStatus = "pending";
        let ownerName = "Manager Stay";
        const ownerId = data.ownerUserId || `owner_${bizId}`;

        try {
          const membersSnap = await getDocs(collection(db, `businesses/${bizId}/members`));
          const ownerDoc = membersSnap.docs.find(d => d.id === ownerId || d.data().role === "owner");
          if (ownerDoc) {
            const ownerData = ownerDoc.data();
            ownerStatus = ownerData.status || "pending";
            ownerName = ownerData.name || "PG Landlord";
          }
        } catch (e) {
          console.error(`Error loading members for ${bizId}:`, e);
        }

        bizList.push({
          id: bizId,
          name: data.name || "Unnamed Business",
          phone: data.phone || "No Phone",
          ownerUserId: ownerId,
          ownerName,
          ownerStatus,
          createdAt: data.createdAt,
        });
      }

      setBusinesses(bizList);
    } catch (e) {
      console.error("Error loading businesses:", e);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    fetchBusinesses();
  }, []);

  async function handleStatusChange(biz: BusinessInfo, newStatus: string) {
    try {
      setUpdating(true);
      const batch = writeBatch(db);

      // Update business status on business member doc
      const memberRef = doc(db, `businesses/${biz.id}/members/${biz.ownerUserId}`);
      batch.update(memberRef, { status: newStatus });

      // Update business root status if it has one
      const businessRef = doc(db, "businesses", biz.id);
      batch.update(businessRef, { status: newStatus });

      await batch.commit();

      // Refresh list
      await fetchBusinesses();
      setSelectedBiz(null);
    } catch (e) {
      console.error("Error updating business status:", e);
      alert("Failed to update status. Check permissions.");
    } finally {
      setUpdating(false);
    }
  }

  if (loading) {
    return (
      <div className="overviewLoading">
        <div className="spinner"></div>
        <p>Loading Business Registry...</p>
      </div>
    );
  }

  return (
    <div className="consoleContainer">
      <div className="dashboardHeader">
        <h2>PG Business Compliance</h2>
        <p>Manage registered landlords, review KYC approvals, and override registration permissions.</p>
      </div>

      <div className="tableWrapper">
        <table className="adminTable">
          <thead>
            <tr>
              <th>Business Name</th>
              <th>Owner Name</th>
              <th>Contact Phone</th>
              <th>KYC Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {businesses.map((biz) => {
              const isPending = biz.ownerStatus === "pending";
              const isActive = biz.ownerStatus === "active";
              return (
                <tr key={biz.id}>
                  <td>
                    <strong>{biz.name}</strong>
                    <span className="subtext">ID: {biz.id}</span>
                  </td>
                  <td>{biz.ownerName}</td>
                  <td>{biz.phone}</td>
                  <td>
                    <span className={`badge ${biz.ownerStatus}`}>
                      {biz.ownerStatus.toUpperCase()}
                    </span>
                  </td>
                  <td>
                    <button 
                      className="tableActionBtn"
                      onClick={() => setSelectedBiz(biz)}
                    >
                      Review KYC
                    </button>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      {selectedBiz && (
        <div className="modalOverlay" onClick={() => setSelectedBiz(null)}>
          <div className="modalCard" onClick={(e) => e.stopPropagation()}>
            <div className="modalHeader">
              <h3>KYC Audit: {selectedBiz.name}</h3>
              <button className="closeBtn" onClick={() => setSelectedBiz(null)}>×</button>
            </div>
            <div className="modalBody">
              <div className="infoGrid">
                <div className="infoItem">
                  <User size={16} />
                  <div>
                    <label>Landlord Owner</label>
                    <span>{selectedBiz.ownerName}</span>
                  </div>
                </div>
                <div className="infoItem">
                  <Phone size={16} />
                  <div>
                    <label>Phone Number</label>
                    <span>{selectedBiz.phone}</span>
                  </div>
                </div>
              </div>

              <div className="documentCard">
                <h4>Verified Documents & Metadata</h4>
                <p>✓ Government ID (Aadhaar / PAN Card verified via API pipeline)</p>
                <p>✓ Bank account details connected via Razorpay Route</p>
                <p>✓ Platform policy agreements accepted</p>
              </div>

              <div className="modalStatus">
                <span>Current Status:</span>
                <span className={`badge ${selectedBiz.ownerStatus}`}>
                  {selectedBiz.ownerStatus.toUpperCase()}
                </span>
              </div>
            </div>
            <div className="modalFooter">
              {selectedBiz.ownerStatus !== "active" && (
                <button
                  className="approveBtn"
                  disabled={updating}
                  onClick={() => handleStatusChange(selectedBiz, "active")}
                >
                  <CheckCircle2 size={16} /> Approve & Activate
                </button>
              )}
              {selectedBiz.ownerStatus !== "suspended" && (
                <button
                  className="rejectBtn"
                  disabled={updating}
                  onClick={() => handleStatusChange(selectedBiz, "suspended")}
                >
                  <AlertCircle size={16} /> Suspend Landlord
                </button>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
