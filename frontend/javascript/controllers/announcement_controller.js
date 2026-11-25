import { Controller } from "@hotwired/stimulus";

// Site-wide event banner. Hides itself after the event's last day, even
// if the site hasn't been rebuilt since, and stays hidden for the rest of
// the visit once dismissed.
export default class extends Controller {
  static values = { ends: String, key: String };

  connect() {
    if (this.isOver() || this.wasDismissed()) this.element.remove();
  }

  dismiss() {
    try {
      sessionStorage.setItem(this.storageKey, "1");
    } catch (_error) {
      // Storage can be unavailable (private browsing); dismissing still works for this page.
    }
    this.element.remove();
  }

  isOver() {
    if (!this.endsValue) return false;
    const [year, month, day] = this.endsValue.split("-").map(Number);
    const endOfLastDay = new Date(year, month - 1, day, 23, 59, 59);
    return Date.now() > endOfLastDay.getTime();
  }

  wasDismissed() {
    try {
      return sessionStorage.getItem(this.storageKey) === "1";
    } catch (_error) {
      return false;
    }
  }

  get storageKey() {
    return `announcement-dismissed:${this.keyValue}`;
  }
}
