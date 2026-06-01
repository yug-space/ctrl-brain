export function Logo({ size = 30 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 512 512" aria-label="Ctrl+Brain" style={{ borderRadius: size * 0.26 }}>
      <rect x="64" y="64" width="384" height="384" rx="100" fill="#20232B" />
      <rect x="86" y="72" width="340" height="330" rx="78" fill="#2C313C" />
      <path
        d="M200 256 C184 256 174 240 184 228 C166 222 166 198 186 194 C182 174 206 164 220 178 C226 160 250 160 256 176 C262 160 286 160 292 178 C306 164 330 174 326 194 C346 198 346 222 328 228 C338 240 328 256 312 256 C314 272 288 280 276 268 C266 280 246 280 236 268 C224 280 198 272 200 256 Z"
        fill="#EFEDE6"
      />
      <g fill="none" stroke="#2C313C" strokeWidth="9" strokeLinecap="round">
        <path d="M256 180 C248 202 262 218 252 238" />
        <path d="M216 202 C208 210 210 224 222 226" />
        <path d="M296 202 C304 210 302 224 290 226" />
      </g>
      <text x="256" y="336" textAnchor="middle" fontFamily="ui-monospace, Menlo, monospace" fontSize="30" letterSpacing="3" fill="#888FA1">
        ctrl <tspan fill="#E6A93C">+</tspan>
      </text>
    </svg>
  );
}
