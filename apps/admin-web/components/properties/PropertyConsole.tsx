import React, { useEffect, useState } from "react";
import { collection, getDocs, doc, writeBatch, deleteDoc } from "firebase/firestore";
import { db } from "../../lib/firebase";
import { Star, MapPin, Eye, ShieldAlert, Award, XCircle, Info, ShieldCheck } from "lucide-react";

interface PropertyInfo {
  id: string;
  name: string;
  city: string;
  cityCode: string;
  address: string;
  description: string;
  totalBeds: number;
  pricePerBed: number;
  featured: boolean;
  status: string;
  billingStatus: string;
  businessId: string;
  businessName: string;
  businessPhone: string;
  ratingAverage: number;
  ratingCount: number;
  rawMap: any;
  images?: string[];
}

export default function PropertyConsole() {
  const [properties, setProperties] = useState<PropertyInfo[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedProp, setSelectedProp] = useState<PropertyInfo | null>(null);
  const [updating, setUpdating] = useState(false);

  async function fetchProperties() {
    try {
      setLoading(true);
      const querySnap = await getDocs(collection(db, "properties"));
      const propList: PropertyInfo[] = querySnap.docs.map((doc) => {
        const data = doc.data();
        return {
          id: doc.id,
          name: data.name || "Unnamed PG",
          city: data.city || "Unknown",
          cityCode: data.cityCode || "Unknown",
          address: data.address || "No Address",
          description: data.description || "No Description",
          totalBeds: data.totalBeds || 0,
          pricePerBed: data.pricePerBed || 0,
          featured: data.featured || false,
          status: data.status || "active",
          billingStatus: data.billingStatus || "trial",
          businessId: data.businessId || "",
          businessName: data.businessName || "No Landlord",
          businessPhone: data.businessPhone || "No Phone",
          ratingAverage: data.rating?.average || 0.0,
          ratingCount: data.rating?.count || 0,
          rawMap: data,
          images: data.images || [],
        };
      });
      setProperties(propList);
    } catch (e) {
      console.error("Error loading properties:", e);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    fetchProperties();
  }, []);

  async function handleToggleFeatured(prop: PropertyInfo) {
    try {
      setUpdating(true);
      const newFeatured = !prop.featured;
      const batch = writeBatch(db);

      // Update in global properties
      batch.update(doc(db, "properties", prop.id), { featured: newFeatured });

      // Update in business properties
      batch.update(doc(db, `businesses/${prop.businessId}/properties/${prop.id}`), { featured: newFeatured });

      // Update in properties_by_city
      const cityIndexRef = doc(db, `properties_by_city/${prop.city}/properties/${prop.id}`);
      batch.update(cityIndexRef, { featured: newFeatured });

      await batch.commit();
      await fetchProperties();
      if (selectedProp && selectedProp.id === prop.id) {
        setSelectedProp({ ...selectedProp, featured: newFeatured });
      }
    } catch (e) {
      console.error("Error toggling featured state:", e);
      alert("Failed to toggle featured state. Check console.");
    } finally {
      setUpdating(false);
    }
  }

  async function handleVerification(prop: PropertyInfo, newStatus: "active" | "suspended") {
    try {
      setUpdating(true);
      const batch = writeBatch(db);

      const globalRef = doc(db, "properties", prop.id);
      const bizRef = doc(db, `businesses/${prop.businessId}/properties/${prop.id}`);
      const cityIndexRef = doc(db, `properties_by_city/${prop.city}/properties/${prop.id}`);

      if (newStatus === "active") {
        // Activate PG listing and clone to public city search collection
        const updatedData = { ...prop.rawMap, status: "active", updatedAt: new Date() };
        batch.set(globalRef, updatedData);
        batch.set(bizRef, updatedData);
        batch.set(cityIndexRef, updatedData);
      } else {
        // Suspend PG listing and remove it from search index
        batch.update(globalRef, { status: "suspended", updatedAt: new Date() });
        batch.update(bizRef, { status: "suspended", updatedAt: new Date() });
        batch.delete(cityIndexRef);
      }

      await batch.commit();
      await fetchProperties();
      setSelectedProp(null);
    } catch (e) {
      console.error("Error setting property status:", e);
      alert("Failed to change property status.");
    } finally {
      setUpdating(false);
    }
  }

  if (loading) {
    return (
      <div className="overviewLoading">
        <div className="spinner"></div>
        <p>Loading Property Inventory...</p>
      </div>
    );
  }

  return (
    <div className="consoleContainer">
      <div className="dashboardHeader">
        <h2>Platform Property Compliance</h2>
        <p>Audit co-living spaces, toggle search promotions, and verify listings for the public tenant index.</p>
      </div>

      <div className="tableWrapper">
        <table className="adminTable">
          <thead>
            <tr>
              <th>Property Details</th>
              <th>City</th>
              <th>Owner Chain</th>
              <th>Capacity (Beds)</th>
              <th>Featured</th>
              <th>Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {properties.map((prop) => (
              <tr key={prop.id}>
                <td>
                  <strong>{prop.name}</strong>
                  <span className="subtext">ID: {prop.id}</span>
                </td>
                <td>
                  <span className="cityLabel">{prop.city}</span>
                </td>
                <td>
                  <strong>{prop.businessName}</strong>
                </td>
                <td>{prop.totalBeds} Beds</td>
                <td>
                  <button
                    disabled={updating}
                    onClick={() => handleToggleFeatured(prop)}
                    className={`iconBtn ${prop.featured ? "starred" : ""}`}
                    title={prop.featured ? "Featured - click to remove" : "Make Featured"}
                  >
                    <Star size={18} fill={prop.featured ? "#F59E0B" : "none"} color={prop.featured ? "#F59E0B" : "#64748B"} />
                  </button>
                </td>
                <td>
                  <span className={`badge ${prop.status}`}>
                    {prop.status.toUpperCase()}
                  </span>
                </td>
                <td>
                  <button 
                    className="tableActionBtn"
                    onClick={() => setSelectedProp(prop)}
                  >
                    Manage
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {selectedProp && (
        <div className="modalOverlay" onClick={() => setSelectedProp(null)}>
          <div className="modalCard maxModal" onClick={(e) => e.stopPropagation()}>
            <div className="modalHeader">
              <h3>Property Audit: {selectedProp.name}</h3>
              <button className="closeBtn" onClick={() => setSelectedProp(null)}>×</button>
            </div>
            <div className="modalBody scrollableModal">
              <div className="propertyAuditGrid">
                <div>
                  <div className="propSection">
                    <label>Description & Context</label>
                    <p>{selectedProp.description}</p>
                  </div>
                  <div className="propSection">
                    <label>Locations & Landmark Details</label>
                    <span className="addressTag">
                      <MapPin size={14} /> {selectedProp.address}
                    </span>
                  </div>
                  <div className="propSection">
                    <label>Landlord Information</label>
                    <div className="bizProfileBadge">
                      <strong>{selectedProp.businessName}</strong>
                      <span>📞 {selectedProp.businessPhone}</span>
                    </div>
                  </div>
                </div>

                <div className="auditSidebar">
                  <div className="propSection">
                    <label>Spec Snapshot</label>
                    <ul className="specList">
                      <li>Beds capacity: <strong>{selectedProp.totalBeds}</strong></li>
                      <li>Base Pricing Plan: <strong>₹{selectedProp.pricePerBed}/bed</strong></li>
                      <li>Customer Rating: <strong>★ {selectedProp.ratingAverage}</strong> ({selectedProp.ratingCount} reviews)</li>
                      <li>Billing Status: <strong className="textTeal">{selectedProp.billingStatus.toUpperCase()}</strong></li>
                    </ul>
                  </div>

                  {selectedProp.images && selectedProp.images.length > 0 && (
                    <div className="propSection">
                      <label>Uploaded Photos ({selectedProp.images.length})</label>
                      <div className="thumbnailGallery">
                        {selectedProp.images.map((imgUrl, i) => (
                          <img 
                            key={i} 
                            src={imgUrl} 
                            alt={`Preview ${i + 1}`} 
                            onError={(e) => { (e.target as HTMLElement).style.display = 'none'; }}
                          />
                        ))}
                      </div>
                    </div>
                  )}
                </div>
              </div>
            </div>
            <div className="modalFooter">
              <button
                className="featuredBtn"
                disabled={updating}
                onClick={() => handleToggleFeatured(selectedProp)}
              >
                <Award size={16} /> {selectedProp.featured ? "Remove Featured" : "Promote to Featured"}
              </button>

              {selectedProp.status !== "active" && (
                <button
                  className="approveBtn"
                  disabled={updating}
                  onClick={() => handleVerification(selectedProp, "active")}
                >
                  <ShieldCheck size={16} /> Verify & Publish to Public
                </button>
              )}
              
              {selectedProp.status !== "suspended" && (
                <button
                  className="rejectBtn"
                  disabled={updating}
                  onClick={() => handleVerification(selectedProp, "suspended")}
                >
                  <XCircle size={16} /> Suspend Listing
                </button>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
