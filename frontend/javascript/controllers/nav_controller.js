import { Controller } from "@hotwired/stimulus";

// Collapses the main navigation behind a menu button on small screens.
// From the md breakpoint up the menu is always visible via CSS.
export default class extends Controller {
  static targets = ["button", "menu"];

  toggle() {
    this.isOpen ? this.close() : this.open();
  }

  open() {
    this.menuTarget.classList.remove("hidden");
    this.menuTarget.classList.add("flex");
    this.buttonTarget.setAttribute("aria-expanded", "true");
    this.buttonTarget.setAttribute("aria-label", "Close menu");
  }

  close() {
    if (!this.isOpen) return;
    this.menuTarget.classList.add("hidden");
    this.menuTarget.classList.remove("flex");
    this.buttonTarget.setAttribute("aria-expanded", "false");
    this.buttonTarget.setAttribute("aria-label", "Open menu");
  }

  closeOnLink(event) {
    if (event.target.closest("a")) this.close();
  }

  closeOnDesktop() {
    if (window.matchMedia("(min-width: 48rem)").matches) this.close();
  }

  get isOpen() {
    return this.buttonTarget.getAttribute("aria-expanded") === "true";
  }
}
