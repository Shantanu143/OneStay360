import type { Metadata, Viewport } from "next";
import "./globals.css";
import { Aurora, Toasts } from "@/components/ui";
import { site, social } from "@/lib/site";

export const metadata: Metadata = {
  metadataBase: new URL(site.url),
  title: { default: site.title, template: "%s | OneStay360" },
  description: site.description,
  keywords: site.keywords,
  applicationName: site.name,
  alternates: { canonical: "/" },
  ...social(site.title, site.description, "/"),
  icons: {
    icon: [{ url: "/brand/icon-32.png", sizes: "32x32", type: "image/png" }, { url: "/brand/icon-192.png", sizes: "192x192", type: "image/png" }],
    apple: [{ url: "/brand/icon-180.png", sizes: "180x180" }],
  },
  formatDetection: { telephone: false },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#f1f5f3" },
    { media: "(prefers-color-scheme: dark)", color: "#0a1311" },
  ],
};

// Applies the saved theme before first paint so dark mode never flashes.
const themeScript = `try{var t=localStorage.getItem("onestay360.theme");if(t==="light"||t==="dark")document.documentElement.setAttribute("data-theme",t)}catch(e){}`;

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en-IN" suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: themeScript }} />
        <link rel="preload" href="/fonts/Inter-Latin.woff2" as="font" type="font/woff2" crossOrigin="anonymous" />
        <noscript>
          <style>{`.reveal{opacity:1!important;transform:none!important}`}</style>
        </noscript>
      </head>
      <body>
        <a href="#main" className="skip-link">
          Skip to content
        </a>
        <Aurora />
        {children}
        <Toasts />
      </body>
    </html>
  );
}
