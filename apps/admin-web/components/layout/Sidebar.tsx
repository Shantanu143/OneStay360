import React from "react";
import {
  Gauge,
  UsersRound,
  Building2,
  CircleDollarSign,
  MessageSquareText,
  LockKeyhole,
} from "lucide-react";

interface SidebarProps {
  currentTab: string;
  onTabChange: (tab: string) => void;
}

export default function Sidebar({ currentTab, onTabChange }: SidebarProps) {
  const menuItems = [
    { id: "overview", label: "Dashboard", icon: Gauge },
    { id: "landlords", label: "PG Landlords", icon: UsersRound },
    { id: "properties", label: "Properties", icon: Building2 },
    { id: "billing", label: "Billing & Invoices", icon: CircleDollarSign },
    { id: "disputes", label: "Disputes Desk", icon: MessageSquareText },
  ];

  return (
    <aside className="sidebar">
      <div className="sidebarBrand">
        <div className="brandLogo">O</div>
        <div className="brandDetails">
          <strong>OneStay360</strong>
          <span>Admin Portal</span>
        </div>
      </div>
      <nav className="sidebarMenu">
        {menuItems.map((item) => {
          const Icon = item.icon;
          const isActive = currentTab === item.id;
          return (
            <button
              key={item.id}
              onClick={() => onTabChange(item.id)}
              className={`sidebarMenuItem ${isActive ? "active" : ""}`}
              aria-current={isActive ? "page" : undefined}
            >
              <Icon size={18} className="menuIcon" />
              <span>{item.label}</span>
            </button>
          );
        })}
      </nav>
      <div className="sidebarFooter">
        <LockKeyhole size={14} />
        <span>Platform Secure</span>
      </div>
    </aside>
  );
}
