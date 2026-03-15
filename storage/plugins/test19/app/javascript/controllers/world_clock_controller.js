import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["saoPaulo", "brisbane", "newYork"];

  connect() {
    this.updateTimes();
    this.interval = setInterval(() => this.updateTimes(), 1000);
  }

  disconnect() {
    if (this.interval) {
      clearInterval(this.interval);
    }
  }

  updateTimes() {
    const now = new Date();

    if (this.hasSaoPauloTarget) {
      this.saoPauloTarget.textContent = this.formatTime(now, 'America/Sao_Paulo');
      this.saoPauloTarget.dataset.date = this.formatDate(now, 'America/Sao_Paulo');
    }

    if (this.hasBrisbaneTarget) {
      this.brisbaneTarget.textContent = this.formatTime(now, 'Australia/Brisbane');
      this.brisbaneTarget.dataset.date = this.formatDate(now, 'Australia/Brisbane');
    }

    if (this.hasNewYorkTarget) {
      this.newYorkTarget.textContent = this.formatTime(now, 'America/New_York');
      this.newYorkTarget.dataset.date = this.formatDate(now, 'America/New_York');
    }

    this.updateDateDisplays();
  }

  formatTime(date, timezone) {
    return date.toLocaleTimeString('en-GB', {
      timeZone: timezone,
      hour12: false,
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit'
    });
  }

  formatDate(date, timezone) {
    return date.toLocaleDateString('pt-BR', {
      timeZone: timezone,
      day: '2-digit',
      month: '2-digit',
      year: 'numeric'
    });
  }

  updateDateDisplays() {
    const dateDisplays = this.element.querySelectorAll('[data-timezone-date]');
    const now = new Date();

    dateDisplays.forEach(display => {
      const timezone = display.dataset.timezone;
      if (timezone) {
        display.textContent = this.formatDate(now, timezone);
      }
    });
  }
}
