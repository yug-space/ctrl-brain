import { Logo } from "@/components/Logo";

const GITHUB = "https://github.com/yug-space/ctrl-brain";
const DOWNLOAD =
  "https://github.com/yug-space/ctrl-brain/releases/latest/download/Ctrl+Brain-1.0.dmg";

export default function Home() {
  return (
    <>
      <header className="nav">
        <div className="wrap nav-in">
          <a className="brand" href="#top">
            <Logo size={38} />
            <span className="wm">ctrl<span className="p">+</span>brain</span>
          </a>
          <nav className="nav-links">
            <a href="#capture">What it does</a>
            <a href="#how">How it works</a>
          </nav>
          <div className="nav-cta">
            <a className="btn btn-line" href={GITHUB} target="_blank" rel="noopener">GitHub ↗</a>
            <a className="btn btn-solid" href={DOWNLOAD}>
              Download <span className="a">→</span>
            </a>
          </div>
        </div>
      </header>

      <main id="top">
        {/* hero */}
        <section className="hero">
          <div className="wrap">
            <Logo className="kc" size={74} />
            <p className="eyebrow" style={{ marginBottom: 20 }}>macOS · local-first</p>
            <h1 className="display">
              Your second brain,<br /><em>one keystroke</em> away.
            </h1>
            <div className="keys" aria-label="Control + Shift + 2">
              <span className="key"><b>⌃</b><i>control</i></span>
              <span className="op">+</span>
              <span className="key"><b>⇧</b><i>shift</i></span>
              <span className="op">+</span>
              <span className="key"><b>2</b><i>two</i></span>
            </div>
            <p className="lede">
              Press it anywhere — Ctrl+Brain captures the text, image, or screenshot in front of you,
              reads it <b>on your Mac</b>, and saves it to your second brain.
            </p>
            <div className="cta">
              <a className="btn btn-solid" href={DOWNLOAD}>
                Download for macOS <span className="a">→</span>
              </a>
              <a className="btn btn-line" href={GITHUB} target="_blank" rel="noopener">GitHub ↗</a>
            </div>
          </div>
        </section>

        {/* pillars */}
        <section id="capture" className="wrap">
          <div className="slab">
            <p className="eyebrow">Three steps, one shortcut</p>
            <p className="eyebrow">01 — 03</p>
          </div>
          <div className="pillars">
            <div className="pillar">
              <div className="n">01</div>
              <h3>Capture</h3>
              <p>Text, images, and screenshots — saved with one global shortcut, from anywhere on your Mac.</p>
            </div>
            <div className="pillar">
              <div className="n">02</div>
              <h3>Understand</h3>
              <p>Apple Vision OCRs the pixels and a local model describes them. Everything stays on-device.</p>
            </div>
            <div className="pillar">
              <div className="n">03</div>
              <h3>Remember</h3>
              <p>One editable Markdown brain that local MCP agents can read, search, and append to. Supermemory sync is optional.</p>
            </div>
          </div>
        </section>

        {/* statement */}
        <section className="statement">
          <div className="wrap">
            <p>
              A second brain should be a keystroke —<br />
              <em>not another app to open.</em>
            </p>
          </div>
        </section>

        <div className="wrap"><div className="rule" /></div>

        {/* how it works */}
        <section id="how" className="steps">
          <div className="wrap">
            <div className="slab" style={{ paddingTop: 64 }}>
              <div>
                <h2 className="sec-h">How it works</h2>
                <p className="sub">Select, press, understand, remember — and the file stays yours, in plain Markdown.</p>
              </div>
            </div>
            <div className="step"><div className="n">01</div><div><h4>Select anything</h4><p>Highlight text, copy an image, or trigger it on any screen.</p></div></div>
            <div className="step"><div className="n">02</div><div><h4>Press ⌃⇧2</h4><p>The selection is read via the Accessibility API — globally, in any app.</p></div></div>
            <div className="step"><div className="n">03</div><div><h4>Understood on-device</h4><p>Vision OCRs images; a local Claude/Codex model describes them. Nothing leaves your Mac.</p></div></div>
            <div className="step"><div className="n">04</div><div><h4>Saved locally</h4><p>Appended to your editable second brain, available to local MCP agents, and synced to Supermemory only if you add a key.</p></div></div>
          </div>
        </section>
      </main>

      <footer>
        <div className="wrap foot">
          <a className="brand" href="#top"><Logo size={28} /><span className="wm">ctrl<span className="p">+</span>brain</span></a>
          <div className="links">
            <a href={GITHUB} target="_blank" rel="noopener">GitHub</a>
            <a href={GITHUB + "/tree/main/mcp"} target="_blank" rel="noopener">Local MCP</a>
            <a href="https://supermemory.ai" target="_blank" rel="noopener">Supermemory</a>
            <a href="#how">How it works</a>
          </div>
          <span className="copy">© 2026 · built on macOS</span>
        </div>
      </footer>
    </>
  );
}
