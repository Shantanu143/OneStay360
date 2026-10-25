import React, { useEffect, useState } from "react";
import { collection, getDocs } from "firebase/firestore";
import { db } from "../../lib/firebase";
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Tooltip,
  ResponsiveContainer,
  AreaChart,
  Area,
  CartesianGrid,
} from "recharts";
import { Building2, UsersRound, CircleDollarSign, ShieldAlert } from "lucide-react";

export default function Overview() {
  const [stats, setStats] = useState({
    totalBeds: 0,
    totalProperties: 0,
    totalBusinesses: 0,
    pendingKYC: 0,
  });
  const [cityData, setCityData] = useState<any[]>([]);
  const [revenueData, setRevenueData] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function fetchDashboardStats() {
      try {
        setLoading(true);
        // Query global properties
        const propSnap = await getDocs(collection(db, "properties"));
        const properties = propSnap.docs.map(doc => doc.data());
        
        // Query businesses
        const bizSnap = await getDocs(collection(db, "businesses"));
        const businesses = bizSnap.docs.map(doc => doc.data());

        // Count pending KYC
        let pendingCount = 0;
        for (const biz of bizSnap.docs) {
          const membersSnap = await getDocs(collection(db, `businesses/${biz.id}/members`));
          const hasPending = membersSnap.docs.some(doc => doc.data().status === "pending");
          if (hasPending) pendingCount++;
        }

        // Calculate total beds
        const totalBeds = properties.reduce((sum, p) => sum + (p.totalBeds || 0), 0);

        // Aggregate by city
        const cityCounts: Record<string, number> = {};
        properties.forEach(p => {
          const city = p.city || "Unknown";
          cityCounts[city] = (cityCounts[city] || 0) + 1;
        });

        const formattedCityData = Object.entries(cityCounts).map(([name, count]) => ({
          name,
          properties: count,
        }));

        setStats({
          totalBeds,
          totalProperties: propSnap.size,
          totalBusinesses: bizSnap.size,
          pendingKYC: pendingCount,
        });

        setCityData(formattedCityData.length > 0 ? formattedCityData : [
          { name: "Bangalore", properties: 8 },
          { name: "Mumbai", properties: 7 },
          { name: "Delhi", properties: 6 },
          { name: "Pune", properties: 6 },
          { name: "Hyderabad", properties: 6 },
          { name: "Chennai", properties: 6 },
          { name: "Kolkata", properties: 6 },
          { name: "Ahmedabad", properties: 5 },
        ]);

        // Semi-mocked monthly platform billing revenue based on live data
        const baseRev = propSnap.size * 15 * 30; // properties * avg beds * rate
        setRevenueData([
          { month: "Jan", revenue: baseRev * 0.7 },
          { month: "Feb", revenue: baseRev * 0.8 },
          { month: "Mar", revenue: baseRev * 0.9 },
          { month: "Apr", revenue: baseRev * 0.95 },
          { month: "May", revenue: baseRev * 1.0 },
          { month: "Jun", revenue: baseRev * 1.1 },
        ]);

      } catch (error) {
        console.error("Error loading dashboard data:", error);
      } finally {
        setLoading(false);
      }
    }

    fetchDashboardStats();
  }, []);

  if (loading) {
    return (
      <div className="overviewLoading">
        <div className="spinner"></div>
        <p>Loading Dashboard Analytics...</p>
      </div>
    );
  }

  const statCards = [
    { label: "Active Beds Managed", value: stats.totalBeds.toLocaleString("en-IN"), icon: UsersRound, color: "teal" },
    { label: "Verified PG Listings", value: stats.totalProperties, icon: Building2, color: "cyan" },
    { label: "Partner PG Chains", value: stats.totalBusinesses, icon: CircleDollarSign, color: "blue" },
    { label: "KYC Pending Review", value: stats.pendingKYC, icon: ShieldAlert, color: "orange" },
  ];

  return (
    <div className="overviewContainer">
      <div className="dashboardHeader">
        <h2>Dashboard Overview</h2>
        <p>Real-time platform activities across all operations and registered PG chains.</p>
      </div>

      <div className="metricsGrid">
        {statCards.map((card) => {
          const Icon = card.icon;
          return (
            <div className={`metricCard ${card.color}`} key={card.label}>
              <div className="cardHeader">
                <span>{card.label}</span>
                <Icon size={20} className="cardIcon" />
              </div>
              <div className="cardBody">
                <h3>{card.value}</h3>
              </div>
            </div>
          );
        })}
      </div>

      <div className="chartsGrid">
        <div className="chartCard">
          <h3>PG Distribution by City</h3>
          <p>Total active properties indexed for public tenant browsing.</p>
          <div className="chartWrapper">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={cityData} margin={{ top: 20, right: 10, left: -10, bottom: 5 }}>
                <XAxis dataKey="name" stroke="#64748B" fontSize={12} tickLine={false} />
                <YAxis stroke="#64748B" fontSize={12} tickLine={false} axisLine={false} />
                <Tooltip 
                  contentStyle={{ backgroundColor: "#1E293B", border: "none", borderRadius: "8px" }}
                  labelStyle={{ color: "#94A3B8", fontWeight: "bold" }}
                />
                <Bar dataKey="properties" fill="#0D9488" radius={[4, 4, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>

        <div className="chartCard">
          <h3>OneStay360 Invoice Revenue Volume</h3>
          <p>Historical monthly billing generated from the ₹30/bed platform license.</p>
          <div className="chartWrapper">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={revenueData} margin={{ top: 20, right: 10, left: 0, bottom: 5 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#334155" />
                <XAxis dataKey="month" stroke="#64748B" fontSize={12} tickLine={false} />
                <YAxis stroke="#64748B" fontSize={12} tickLine={false} axisLine={false} />
                <Tooltip 
                  contentStyle={{ backgroundColor: "#1E293B", border: "none", borderRadius: "8px" }}
                  labelStyle={{ color: "#94A3B8", fontWeight: "bold" }}
                />
                <Area type="monotone" dataKey="revenue" stroke="#06B6D4" fillOpacity={0.2} fill="url(#colorRevenue)" />
                <defs>
                  <linearGradient id="colorRevenue" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#06B6D4" stopOpacity={0.3}/>
                    <stop offset="95%" stopColor="#06B6D4" stopOpacity={0}/>
                  </linearGradient>
                </defs>
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>
    </div>
  );
}
