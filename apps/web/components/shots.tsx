// Real product screenshots (public/shots, captured by scripts/screenshots.mjs)
// in browser and phone frames. Each shot exists in light and dark; CSS shows
// the one matching the current theme.

type ShotName = "owner-home" | "owner-layout" | "owner-approve" | "owner-payments" | "tenant-explore" | "tenant-home" | "tenant-pay" | "tenant-maintenance";

const sizes: Record<ShotName, [number, number]> = {
  "owner-home": [1440, 900],
  "owner-layout": [1168, 820],
  "owner-payments": [1168, 640],
  "owner-approve": [820, 1654],
  "tenant-explore": [780, 1688],
  "tenant-home": [780, 1688],
  "tenant-pay": [780, 1688],
  "tenant-maintenance": [780, 1688],
};

export function Shot({ name, alt, eager }: { name: ShotName; alt: string; eager?: boolean }) {
  const [w, h] = sizes[name];
  const loading = eager ? "eager" : "lazy";
  return (
    <>
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img className="shot shot-light" src={`/shots/${name}-light.jpg`} alt={alt} width={w} height={h} loading={loading} decoding="async" />
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img className="shot shot-dark" src={`/shots/${name}-dark.jpg`} alt="" aria-hidden width={w} height={h} loading={loading} decoding="async" />
    </>
  );
}

export function BrowserFrame({ name, alt, url, eager }: { name: ShotName; alt: string; url: string; eager?: boolean }) {
  return (
    <figure className="browser">
      <div className="browser-bar" aria-hidden>
        <i />
        <i />
        <i />
        <span>{url}</span>
      </div>
      <Shot name={name} alt={alt} eager={eager} />
    </figure>
  );
}

export function PhoneFrame({ name, alt, eager, className }: { name: ShotName; alt: string; eager?: boolean; className?: string }) {
  return (
    <figure className={className ? `device ${className}` : "device"}>
      <div className="device-screen">
        <Shot name={name} alt={alt} eager={eager} />
      </div>
    </figure>
  );
}
