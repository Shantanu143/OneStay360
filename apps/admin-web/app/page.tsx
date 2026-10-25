"use client";

import React, { useState, useEffect } from "react";
import Sidebar from "../components/layout/Sidebar";
import Overview from "../components/dashboard/Overview";
import BusinessConsole from "../components/businesses/BusinessConsole";
import PropertyConsole from "../components/properties/PropertyConsole";
import BillingConsole from "../components/billing/BillingConsole";
import DisputeConsole from "../components/support/DisputeConsole";

export default function Home() {
  const [activeTab, setActiveTab] = useState("overview");
  const [mounted, setMounted] = useState(false);

  // Sync tab state with local storage for session recovery
  useEffect(() => {
    const savedTab = localStorage.getItem("onestay360_admin_active_tab");
    if (savedTab) {
      setActiveTab(savedTab);
    }
    setMounted(true);
  }, []);

  const handleTabChange = (tab: string) => {
    setActiveTab(tab);
    localStorage.setItem("onestay360_admin_active_tab", tab);
  };

  if (!mounted) {
    return (
      <div className="fullscreenLoader">
        <div className="spinner"></div>
        <p>Initializing OneStay360 Admin Portal...</p>
      </div>
    );
  }

  return (
    <div className="adminWorkspace">
      <Sidebar currentTab={activeTab} onTabChange={handleTabChange} />
      
      <main className="workspaceMain" id="top">
        <header className="workspaceHeader">
          <div className="headerLeft">
            <h1>System Operations Control</h1>
            <p className="subtext">Central dashboard for Tenant App status, Landlord audits, and revenue ledgers.</p>
          </div>
          <div className="headerRight">
            <span className="liveIndicator">
              <span className="pulseCircle"></span>
              Live Operations
            </span>
          </div>
        </header>

        <section className="workspaceContent">
          {activeTab === "overview" && <Overview />}
          {activeTab === "landlords" && <BusinessConsole />}
          {activeTab === "properties" && <PropertyConsole />}
          {activeTab === "billing" && <BillingConsole />}
          {activeTab === "disputes" && <DisputeConsole />}
        </section>
      </main>
    </div>
  );
}

