import Image from "next/image";
import { Logo } from "@/components/Logo";

const GITHUB = "https://github.com/yug-space/ctrl-brain";

export default function Home() {
  return (
    <>
      <header className="nav">
        <div className="wrap nav-in">
          <a className="brand" href="#top">
            <Logo size={30} />
            ctrl<span className="p">+</span>brain
          </a>
          <nav className="nav-links">
            <a href="#capture">What it does</a>
            <a href="#how">How it works</a>
            <a href={GITHUB} target="_blank" rel="noopener">GitHub</a>
          </nav>
          <a className="btn btn-solid" href={GITHUB} target="_blank" rel="noopener">
            Download <span className="a">→</span>
          </a>
        </div>
      </header>

      <main id="top">
        {/* hero */}
        <section className="hero">
          <div className="wrap">
            <Image className="kc" src="/logo.svg" alt="Ctrl+Brain" width={96} height={96} priority />
            <p className="eyebrow" style={{ marginBottom: 22 }}>macOS · local-first</p>
            <h1 className="display">
              Your second brain,<br /><em>one keystroke</em> away.
            </h1>
            <p className="lede">
              Press <span className="kbd">⌃⇧2</span> anywhere. Ctrl+Brain captures the text, image, or
              screenshot in front of you — reads it <b>on your Mac</b> — and files it into one editable
              second brain, synced to Supermemory.
            </p>
            <div className="cta">
              <a className="btn btn-solid" href={GITHUB} target="_blank" rel="noopener">
                Download for macOS <span className="a">→</span>
              </a>
              <a className="btn btn-line" href={GITHUB} target="_blank" rel="noopener">View source ↗</a>
            </div>
            <div className="cmd">
              <span><span className="d">$</span> chmod +x build.sh &amp;&amp; ./build.sh</span>
              <span>⌃⇧2</span>
            </div>
            <p className="note">clang build · ~44 MB idle · Apple Silicon &amp; Intel</p>
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
                <h2>How it works</h2>
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
          <a className="brand" href="#top"><Logo size={26} /> ctrl<span className="p">+</span>brain</a>
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
