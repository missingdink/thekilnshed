import { Controller } from "@hotwired/stimulus";

// Sends a form to a configured endpoint, or falls back to opening a
// pre-filled email to the studio when no endpoint is set yet.
//
// Values:
//   endpoint      URL that accepts a POST of the form data (optional)
//   email         studio address for the email fallback
//   subject       email subject; {topic} and {name} are filled in
//   success       message shown after a successful send
export default class extends Controller {
  static targets = ["status", "submit"];
  static values = { endpoint: String, email: String, subject: String, success: String };

  connect() {
    this.preselectTopic();
  }

  async submit(event) {
    event.preventDefault();
    const form = this.element;

    // Bots fill in the hidden field; quietly pretend it worked.
    if (form.elements.company_website?.value) return this.showStatus(this.successValue, "success");

    if (!this.endpointValue) return this.openEmail(form);

    this.setBusy(true);
    try {
      const response = await fetch(this.endpointValue, {
        method: "POST",
        body: new FormData(form),
        headers: { Accept: "application/json" },
      });
      if (!response.ok) throw new Error(`Request failed with ${response.status}`);
      form.reset();
      this.preselectTopic();
      this.showStatus(this.successValue, "success");
    } catch (error) {
      this.showStatus(
        `Sorry, that didn't go through. Please try again, or email us at ${this.emailValue}.`,
        "error",
      );
    } finally {
      this.setBusy(false);
    }
  }

  openEmail(form) {
    const data = new FormData(form);
    const topicField = form.elements.topic;
    const topic = topicField ? topicField.selectedOptions[0]?.text || "" : "";
    const name = data.get("name") || "";
    const subject = (this.subjectValue || "Website message")
      .replace("{topic}", topic)
      .replace("{name}", name)
      .replace(/\s+/g, " ")
      .trim();

    const lines = [];
    for (const element of form.elements) {
      if (!element.name || element.type === "submit" || element.name === "company_website") continue;
      if ((element.type === "checkbox" || element.type === "radio") && !element.checked) continue;
      const label = element.labels?.[0]?.innerText.replace(/\s*\*?\s*$/, "").trim() || element.name;
      const value = element.tagName === "SELECT" ? element.selectedOptions[0]?.text : element.value;
      if (value) lines.push(element.type === "checkbox" ? label : `${label}: ${value}`);
    }

    window.location.href = `mailto:${this.emailValue}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(lines.join("\n\n"))}`;
    this.showStatus(
      `Your email app should open with your message ready to send. If it doesn't, email us at ${this.emailValue}.`,
      "success",
    );
  }

  // Lets other pages link to /contact?topic=membership to preselect a topic.
  preselectTopic() {
    const select = this.element.elements.topic;
    const topic = new URLSearchParams(window.location.search).get("topic");
    if (!select || !topic) return;
    const option = [...select.options].find((o) => o.value === topic);
    if (option) select.value = topic;
  }

  setBusy(busy) {
    if (!this.hasSubmitTarget) return;
    this.submitTarget.disabled = busy;
    this.submitTarget.setAttribute("aria-busy", String(busy));
  }

  showStatus(message, kind) {
    if (!this.hasStatusTarget) return;
    this.statusTarget.textContent = message;
    this.statusTarget.dataset.kind = kind;
    this.statusTarget.hidden = false;
  }
}
