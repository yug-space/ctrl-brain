import { Logo } from "@/components/Logo";
import { Mockup, ICONS } from "@/components/Mockup";

const GITHUB = "https://github.com/yug-space/ctrl-brain";

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
            <a href="#showcase">What it does</a>
            <a href="#how">How it works</a>
          </nav>
          <div className="nav-cta">
            <a className="btn btn-line" href={GITHUB} target="_blank" rel="noopener">GitHub ↗</a>
            <a className="btn btn-solid" href={GITHUB} target="_blank" rel="noopener">
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
              <a className="btn btn-solid" href={GITHUB} target="_blank" rel="noopener">
                Download for macOS <span className="a">→</span>
              </a>
              <a className="btn btn-line" href={GITHUB} target="_blank" rel="noopener">GitHub ↗</a>
            </div>
          </div>
        </section>

        {/* showcase — the capture card, light + dark */}
        <section id="showcase" className="wrap">
          <div className="slab">
            <div>
              <p className="eyebrow">The capture</p>
              <h2 className="sec-h">One card. Everything you saved.</h2>
            </div>
            <p className="eyebrow">light · dark</p>
          </div>
          <div className="showcase">
            <Mockup
              variant="light"
              date="May 30" time="5:00 PM"
              title="Highlighted from arXiv"
              desc="Selected text, read and filed into your second brain."
              rows={[
                { icon: <ICONS.IconInbox />, label: "Highlighted text", on: true },
                { icon: <ICONS.IconGrid />, label: "Screenshot" },
                { icon: <ICONS.IconFlask />, label: "Image · OCR" },
                { icon: <ICONS.IconMega />, label: "Synced to Supermemory" },
              ]}
            />
            <Mockup
              variant="dark"
              date="May 30" time="5:00 PM"
              title="Understood on-device"
              desc="Apple Vision OCRs the pixels; a local model describes them."
              rows={[
                { icon: <ICONS.IconRoute />, label: "Routing variables" },
                { icon: <ICONS.IconAnchor />, label: "Risk parameters" },
                { icon: <ICONS.IconLock />, label: "Authorization limits" },
                { icon: <ICONS.IconMega />, label: "Synced to Supermemory" },
              ]}
            />
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
              <p>One editable Markdown brain, synced to Supermemory so your agents can recall it later.</p>
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
            <div className="step"><div className="n">04</div><div><h4>Saved &amp; synced</h4><p>Appended to your editable second brain and uploaded to Supermemory.</p></div></div>
          </div>
        </section>
      </main>

      <footer>
        <div className="wrap foot">
          <a className="brand" href="#top"><Logo size={28} /><span className="wm">ctrl<span className="p">+</span>brain</span></a>
          <div className="links">
            <a href={GITHUB} target="_blank" rel="noopener">GitHub</a>
            <a href="https://supermemory.ai" target="_blank" rel="noopener">Supermemory</a>
            <a href="#how">How it works</a>
          </div>
          <span className="copy">© 2026 · built on macOS</span>
        </div>
      </footer>
    </>
  );
}
