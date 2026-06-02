/* Icon-only mark: keycap + a symmetric, centered brain. The wordmark is written as text. */
export function Logo({ size = 30, className }: { size?: number; className?: string }) {
  const Half = () => (
    <>
      <path
        d="M256 178 C268 166 288 164 296 178 C310 168 330 174 330 192 C346 196 350 216 336 228 C348 238 346 258 330 260 C336 276 316 286 302 276 C292 286 268 284 256 276 Z"
        fill="#EFEDE6"
      />
      <g fill="none" stroke="#2C313C" strokeWidth={8} strokeLinecap="round">
        <path d="M298 198 C290 216 302 228 294 244" />
        <path d="M322 210 C330 218 326 230 314 232" />
      </g>
    </>
  );
  return (
    <svg className={className} width={size} height={size} viewBox="0 0 512 512" aria-label="Ctrl+Brain" style={{ borderRadius: size * 0.26 }}>
      <rect x="64" y="64" width="384" height="384" rx="100" fill="#20232B" />
      <rect x="86" y="72" width="340" height="330" rx="78" fill="#2C313C" />
      <rect x="86.75" y="72.75" width="338.5" height="328.5" rx="77" fill="none" stroke="#fff" strokeOpacity="0.06" strokeWidth="1.5" />
      <g transform="translate(0,31)">
        <Half />
        <g transform="translate(512,0) scale(-1,1)"><Half /></g>
        <path d="M256 180 C251 212 261 244 256 274" fill="none" stroke="#2C313C" strokeWidth={8} strokeLinecap="round" />
      </g>
    </svg>
  );
}
