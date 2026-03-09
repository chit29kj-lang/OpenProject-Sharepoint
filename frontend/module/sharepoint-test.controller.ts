import { Controller } from "@hotwired/stimulus";

/**
 * Stimulus controller for the "Test Connection" button.
 *
 * HTML structure:
 *   <div data-controller="sharepoint-test"
 *        data-sharepoint-test-url-value="<url>"
 *        data-sharepoint-test-connecting-text-value="Connecting">
 *     <button data-sharepoint-test-target="btn"
 *             data-action="click->sharepoint-test#run">Test Connection</button>
 *     <span data-sharepoint-test-target="result"></span>
 *   </div>
 *
 * States:
 *   waiting  → grey badge, animated dots  "Connecting.", "Connecting..", "Connecting..."
 *   success  → green badge                "✓ <server message>"
 *   error    → red badge                  "✕ <server message>"
 */
export default class SharepointTestController extends Controller {
  static values = { url: String, connectingText: String };
  static targets = ["result", "btn"];

  declare urlValue: string;
  declare connectingTextValue: string;
  declare resultTarget: HTMLElement;
  declare btnTarget: HTMLButtonElement;

  private dotInterval: ReturnType<typeof setInterval> | null = null;

  async run(): Promise<void> {
    this.startWaiting();

    const csrfToken =
      document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')
        ?.content ?? "";

    try {
      const resp = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "X-CSRF-Token": csrfToken,
          Accept: "application/json",
        },
      });

      const data = (await resp.json()) as { ok: boolean; message: string };

      if (data.ok) {
        this.showSuccess(data.message);
      } else {
        this.showError(data.message);
      }
    } catch (e) {
      this.showError(String(e));
    }
  }

  private startWaiting(): void {
    const el = this.resultTarget;
    this.btnTarget.disabled = true;
    el.style.display = "inline";
    el.style.color = "#888";

    const base = this.connectingTextValue || "Connecting";
    let dots = 0;
    el.textContent = base;

    this.dotInterval = setInterval(() => {
      dots = (dots % 3) + 1;
      el.textContent = base + ".".repeat(dots);
    }, 400);
  }

  private stopWaiting(): void {
    if (this.dotInterval !== null) {
      clearInterval(this.dotInterval);
      this.dotInterval = null;
    }
    this.btnTarget.disabled = false;
  }

  private showSuccess(message: string): void {
    this.stopWaiting();
    const el = this.resultTarget;
    el.style.color = "#28a745";
    el.textContent = "\u2713 " + message;
  }

  private showError(message: string): void {
    this.stopWaiting();
    const el = this.resultTarget;
    el.style.color = "#dc3545";
    el.textContent = "\u2715 " + message;
  }
}
