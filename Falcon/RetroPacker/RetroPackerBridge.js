// FalconBridge:bridge-script
// RetroPackerBridge.js — bridge between the vendored portable-retro-games
// universal packer page and Falcon's hidden WKWebView packing engine.
//
// Loaded by pack_game_en.html from its marked `FalconBridge` block. The page
// calls the `onProgress`/`onComplete`/`onError` hooks below from tiny marked
// hooks of its own; this file owns all Falcon-specific behavior:
//
//   window.FalconRetroPacker.pack({ id, romBase64, romName, system, title, color })
//
// Posts to window.webkit.messageHandlers.falconRetroPacker (contract mirrors
// RetroPackerBridgeParser in Swift):
//   { type: 'progress', id, percent, message }   // percent is 0...1
//   { type: 'complete', id, fileName, htmlBase64 }
//   { type: 'error',    id, message }
//
// Outside Falcon (a plain browser) every hook is inert: pack() still works
// from the console, no messages are posted and anchor downloads are not
// suppressed, so the upstream page keeps its normal behavior.
(function () {
  'use strict';

  var HANDLER_NAME = 'falconRetroPacker';

  // Optional chaining keeps this safe in a browser, where `window.webkit`
  // does not exist.
  const post = (msg) => window.webkit?.messageHandlers?.falconRetroPacker?.postMessage(msg);

  // The single pack request currently being handled, if any.
  const active = { id: null, percent: -1, message: '' };

  function resetActive() {
    active.id = null;
    active.percent = -1;
    active.message = '';
  }

  // Upstream shows progress with a 0...100 value plus a "progress step" list.
  // The step label is the closest thing it has to a human-readable status.
  function currentStepLabel() {
    const steps = document.getElementById('progress-steps');
    if (!steps) return '';
    const running = steps.querySelector('.progress-step.active');
    const done = steps.querySelectorAll('.progress-step.done');
    const step = running || done[done.length - 1];
    if (!step) return '';
    return (step.textContent || '').replace(/[⏳✅❌]/g, '').trim();
  }

  function onProgress(percentValue) {
    if (active.id === null) return;
    const raw = Number(percentValue);
    if (!isFinite(raw)) return;
    // Swift expects 0...1 (upstream emits 0...100).
    const percent = Math.max(0, Math.min(1, raw / 100));
    const message = currentStepLabel() || 'Packing…';
    if (percent === active.percent && message === active.message) return;
    active.percent = percent;
    active.message = message;
    post({ type: 'progress', id: active.id, percent: percent, message: message });
  }

  function encodeBase64(text) {
    const bytes = new TextEncoder().encode(text);
    const CHUNK = 0x8000;
    let binary = '';
    for (let i = 0; i < bytes.length; i += CHUNK) {
      binary += String.fromCharCode.apply(null, bytes.subarray(i, i + CHUNK));
    }
    return btoa(binary);
  }

  function onComplete(html, fileName) {
    if (active.id === null) return;
    const id = active.id;
    resetActive();
    let htmlBase64;
    try {
      htmlBase64 = encodeBase64(String(html));
    } catch (err) {
      post({ type: 'error', id: id, message: 'Unable to encode generated HTML: ' + ((err && err.message) || err) });
      return;
    }
    post({ type: 'complete', id: id, fileName: String(fileName || ''), htmlBase64: htmlBase64 });
  }

  function onError(message) {
    if (active.id === null) return;
    const id = active.id;
    resetActive();
    post({ type: 'error', id: id, message: String(message || 'Packing failed.') });
  }

  // True only when the page is hosted by Falcon (native message handler
  // registered). Suppresses the upstream blob download inside the app while
  // leaving normal browser downloads untouched.
  function suppressDownload() {
    return !!window.webkit?.messageHandlers?.falconRetroPacker;
  }

  function decodeBase64(base64) {
    const cleaned = String(base64).replace(/\s+/g, '');
    if (!cleaned) throw new Error('Packing request has no ROM data.');
    let binary;
    try {
      binary = atob(cleaned);
    } catch (err) {
      throw new Error('ROM data is not valid base64.');
    }
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
    return bytes;
  }

  function outputNameFor(romName) {
    const dot = romName.lastIndexOf('.');
    const base = dot !== -1 ? romName.slice(0, dot) : romName;
    return base + '.html';
  }

  function pack(request) {
    const requestId = request && typeof request === 'object' ? String(request.id == null ? '' : request.id).trim() : '';
    try {
      if (!requestId) throw new Error('Invalid packing request: missing id.');
      if (active.id !== null) {
        // The page can only run one generation at a time (its Generate button
        // is disabled while packing). Report the conflict for the new request
        // without disturbing the one in flight.
        post({ type: 'error', id: requestId, message: 'Retro packer is busy with another request.' });
        return;
      }
      if (!request || typeof request !== 'object') throw new Error('Invalid packing request.');
      if (typeof request.romBase64 !== 'string' || !request.romBase64) {
        throw new Error('Packing request has no ROM data.');
      }

      const systemSelect = document.getElementById('system-select');
      const generateBtn = document.getElementById('generate-btn');
      if (!systemSelect || !generateBtn || typeof window.handleFile !== 'function') {
        throw new Error('Retro packer page is not ready.');
      }

      const romName = typeof request.romName === 'string' && request.romName ? request.romName : 'game.bin';
      const system = typeof request.system === 'string' ? request.system.trim() : '';
      if (system && !Array.prototype.some.call(systemSelect.options, (option) => option.value === system)) {
        throw new Error('Unsupported system: ' + system);
      }

      const romFile = new File([decodeBase64(request.romBase64)], romName, { type: 'application/octet-stream' });

      // Reuse upstream's own file-selection path so all of its UI/state
      // (drop zone, file info, auto-title, button enable) stays consistent.
      window.handleFile(romFile);

      // An empty system value makes upstream auto-detect from the file name.
      systemSelect.value = system;
      const titleInput = document.getElementById('title-input');
      if (titleInput) titleInput.value = typeof request.title === 'string' ? request.title : '';
      const outputInput = document.getElementById('output-input');
      if (outputInput) outputInput.value = outputNameFor(romName);

      const colorInput = document.getElementById('color-input');
      const color = typeof request.color === 'string' ? request.color.trim() : '';
      if (colorInput && /^#[0-9a-fA-F]{6}$/.test(color)) {
        colorInput.value = color.toUpperCase();
        const colorHex = document.getElementById('color-hex');
        if (colorHex) colorHex.textContent = color.toUpperCase();
      }

      active.id = requestId;
      active.percent = -1;
      active.message = '';
      // Run upstream's existing generation path (same as a user click).
      generateBtn.click();
    } catch (err) {
      const message = (err && err.message) || String(err);
      if (active.id !== null) {
        onError(message);
      } else if (requestId) {
        post({ type: 'error', id: requestId, message: message });
      } else if (window.console) {
        console.error('[FalconRetroPacker] ' + message);
      }
    }
  }

  window.FalconBridge = {
    // FalconBridge:hooks — called by the marked hooks in pack_game_en.html.
    onProgress: onProgress,
    onComplete: onComplete,
    onError: onError,
    suppressDownload: suppressDownload
  };

  window.FalconRetroPacker = {
    // FalconBridge:api — called by RetroPackerEngine (native side).
    pack: pack
  };
})();
