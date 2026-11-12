/* Product mockup card — editorial serif + line-icon rows + iridescent / indigo highlight,
   segmented 1D/7D/1M control, and a deterministic generative-art panel. */

const S = { fill: "none", stroke: "currentColor", strokeWidth: 1.6, strokeLinecap: "round" as const, strokeLinejoin: "round" as const };

const IconCal = () => (<svg width="15" height="15" viewBox="0 0 24 24" {...S}><rect x="3" y="4.5" width="18" height="16" rx="3" /><path d="M3 9h18M8 2.5v4M16 2.5v4" /></svg>);
const IconClock = () => (<svg width="15" height="15" viewBox="0 0 24 24" {...S}><circle cx="12" cy="12" r="8.5" /><path d="M12 7.5V12l3 2" /></svg>);
const IconChevron = () => (<svg width="18" height="18" viewBox="0 0 24 24" {...S}><path d="M6 9l6 6 6-6" /></svg>);
const IconInbox = () => (<svg width="19" height="19" viewBox="0 0 24 24" {...S}><path d="M3.5 13.5L6 4.5h12l2.5 9M3.5 13.5v5a1.5 1.5 0 0 0 1.5 1.5h14a1.5 1.5 0 0 0 1.5-1.5v-5M3.5 13.5h4l1.5 2.5h6l1.5-2.5h4" /></svg>);
const IconGrid = () => (<svg width="19" height="19" viewBox="0 0 24 24" fill="currentColor" stroke="none"><g>{[5, 9.5, 14].flatMap((y) => [5, 9.5, 14].map((x) => <circle key={`${x}-${y}`} cx={x} cy={y} r="1.25" />))}</g></svg>);
const IconFlask = () => (<svg width="19" height="19" viewBox="0 0 24 24" {...S}><path d="M9 3h6M10 3v6l-5 9a2 2 0 0 0 1.8 3h10.4a2 2 0 0 0 1.8-3l-5-9V3" /><path d="M7.5 14h9" /></svg>);
const IconMega = () => (<svg width="19" height="19" viewBox="0 0 24 24" {...S}><path d="M4 9v6h3l9 4V5L7 9H4zM19 8.5a5 5 0 0 1 0 7" /></svg>);
const IconRoute = () => (<svg width="19" height="19" viewBox="0 0 24 24" {...S}><rect x="3" y="9" width="18" height="6" rx="2" /><path d="M7 12h.01M11 12h.01" /></svg>);
const IconAnchor = () => (<svg width="19" height="19" viewBox="0 0 24 24" {...S}><circle cx="12" cy="5" r="2" /><path d="M12 7v12M6 12H4a8 8 0 0 0 16 0h-2M8 11l4-4 4 4" /></svg>);
const IconLock = () => (<svg width="19" height="19" viewBox="0 0 24 24" {...S}><rect x="4.5" y="10.5" width="15" height="9" rx="2" /><path d="M8 10.5V8a4 4 0 0 1 8 0v2.5" /></svg>);
const IconExpand = () => (<svg width="15" height="15" viewBox="0 0 24 24" {...S}><path d="M9 4H5a1 1 0 0 0-1 1v4M15 4h4a1 1 0 0 1 1 1v4M9 20H5a1 1 0 0 1-1-1v-4M15 20h4a1 1 0 0 0 1-1v-4" /></svg>);

/* deterministic shattered-cell field — same on server & client (no Math.random) */
function field() {
  const W = 30, H = 17, cells: { cx: number; cy: number; s: number; o: number; r: number }[] = [];
  const hash = (x: number, y: number) => { const s = Math.sin(x * 127.1 + y * 311.7) * 43758.5453; return s - Math.floor(s); };
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const n = hash(x, y), m = hash(x + 9.2, y + 4.7);
    const dx = x / W - 0.5, dy = y / H - 0.5;
    const band = Math.abs(dx + dy * 0.6);            // diagonal emphasis
    if (n < 0.34 + band * 0.5) continue;
    cells.push({ cx: (x + 0.5) / W * 520, cy: (y + 0.5) / H * 150, s: 4 + n * 11, o: 0.22 + m * 0.78, r: (m - 0.5) * 46 });
  }
  return cells;
}
const CELLS = field();

function GenArt({ variant }: { variant: "light" | "dark" }) {
  const cell = variant === "light" ? "#FFFFFF" : "#4F46E5";
  return (
    <svg className="art" viewBox="0 0 520 150" preserveAspectRatio="xMidYMid slice" aria-hidden>
      <rect width="520" height="150" fill={variant === "light" ? "#0B0B0D" : "#F4F4FB"} />
      {CELLS.map((c, i) => (
        <rect key={i} x={c.cx - c.s / 2} y={c.cy - c.s / 2} width={c.s} height={c.s} rx={c.s * 0.22}
          fill={cell} opacity={c.o} transform={`rotate(${c.r} ${c.cx} ${c.cy})`} />
      ))}
    </svg>
  );
}

type Row = { icon: React.ReactNode; label: string; on?: boolean };

export function Mockup({
  variant, date, time, title, desc, rows,
}: { variant: "light" | "dark"; date: string; time: string; title: string; desc: string; rows: Row[] }) {
  return (
    <div className={`card ${variant}`}>
      <div className="meta">
        <span><IconCal /> {date}</span>
        <span><IconClock /> {time}</span>
      </div>
      <h3 className="title">{title}</h3>
      <p className="desc">{desc}</p>

      <div className="seclabel"><span>Capture</span><IconChevron /></div>

      <div className="rows">
        {rows.map((r, i) => (
          <div key={i} className={`row${r.on ? " on" : ""}`}>{r.icon}<span>{r.label}</span></div>
        ))}
      </div>

      <div className="bar">
        <div className="seg">
          <span>1D</span><span>7D</span><span className="on">1M</span>
        </div>
        <button className="exp"><IconExpand /> Expand</button>
      </div>

      <GenArt variant={variant} />
    </div>
  );
}

export const ICONS = { IconInbox, IconGrid, IconFlask, IconMega, IconRoute, IconAnchor, IconLock };
