import type { NextConfig } from "next";

// Static export: the whole site (landing, auth, dashboard) is client-rendered
// and can be served from Firebase Hosting or any static host.
const nextConfig: NextConfig = {
  output: "export",
  reactStrictMode: true,
  trailingSlash: true,
  images: { unoptimized: true },
};

export default nextConfig;
