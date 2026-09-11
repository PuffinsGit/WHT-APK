
      const DAYS = [
        "Monday",
        "Tuesday",
        "Wednesday",
        "Thursday",
        "Friday",
        "Saturday",
        "Sunday",
      ];
      const storeKey = "worktrack.desktop.v1";
      function readLocalState() {
        try {
          return JSON.parse(localStorage.getItem(storeKey) || "{}");
        } catch (_) {
          return {};
        }
      }
      function normaliseState(target) {
        target.entries = target.entries || {};
        target.scheduleEntries = target.scheduleEntries || {};
        target.weekdayRate = target.weekdayRate ?? 0;
        target.saturdayRate = target.saturdayRate ?? 0;
        target.sundayRate = target.sundayRate ?? 0;
        target.use24Hour = target.use24Hour !== false;
      }
      const state = readLocalState();
      normaliseState(state);
      let viewMonday = monday(new Date());
      function save() {
        const data = JSON.stringify(state);
        localStorage.setItem(storeKey, data);
        const plugin =
          window.Capacitor &&
          window.Capacitor.Plugins &&
          window.Capacitor.Plugins.GallerySaver;
        if (plugin && plugin.saveAppData) {
          plugin.saveAppData({ data }).catch(() => {});
        }
      }
      async function restoreDeviceSave() {
        const plugin =
          window.Capacitor &&
          window.Capacitor.Plugins &&
          window.Capacitor.Plugins.GallerySaver;
        if (!plugin || !plugin.loadAppData) return;
        try {
          const result = await plugin.loadAppData();
          if (result && result.data) {
            const restored = JSON.parse(result.data);
            Object.keys(state).forEach((key) => delete state[key]);
            Object.assign(state, restored);
            normaliseState(state);
            localStorage.setItem(storeKey, JSON.stringify(state));
            refreshScreen();
          } else {
            await plugin.saveAppData({ data: JSON.stringify(state) });
          }
        } catch (_) {
          // Keep using the browser copy if the device save cannot be read.
        }
      }
      function monday(d) {
        let x = new Date(d);
        x.setHours(0, 0, 0, 0);
        let day = x.getDay();
        let diff = day === 0 ? -6 : 1 - day;
        x.setDate(x.getDate() + diff);
        return x;
      }
      function iso(d) {
        return d.toISOString().slice(0, 10);
      }
      function dateFor(i) {
        let d = new Date(viewMonday);
        d.setDate(d.getDate() + i);
        return d;
      }
      function fmtDate(d, year = true) {
        return d.toLocaleDateString("en-AU", {
          day: "numeric",
          month: "short",
          ...(year ? { year: "numeric" } : {}),
        });
      }
      function parseTime(s) {
        if (!s) return -1;
        let t = s.trim().toUpperCase().replace(/\./g, ":").replace(/\s+/g, "");
        let pm = t.endsWith("PM"),
          am = t.endsWith("AM");
        t = t.replace(/AM|PM/g, "");
        let a = t.split(":");
        if (a.length !== 2) return -1;
        let h = Number(a[0]),
          m = Number(a[1]);
        if (!Number.isInteger(h) || !Number.isInteger(m) || m < 0 || m > 59)
          return -1;
        if (pm && h < 12) h += 12;
        if (am && h === 12) h = 0;
        if (h < 0 || h > 23) return -1;
        return h * 60 + m;
      }
      function displayTime(s) {
        let m = parseTime(s);
        if (m < 0) return s || "—";
        let h = Math.floor(m / 60),
          mi = m % 60;
        if (state.use24Hour)
          return String(h).padStart(2, "0") + ":" + String(mi).padStart(2, "0");
        let ap = h >= 12 ? "PM" : "AM",
          hh = h % 12 || 12;
        return hh + ":" + String(mi).padStart(2, "0") + " " + ap;
      }
      function paidHours(i) {
        let e = state.entries[iso(dateFor(i))] || {};
        let s = parseTime(e.start),
          f = parseTime(e.finish);
        if (s < 0 || f < 0) return 0;
        if (f <= s) f += 1440;
        return Math.max(0, (f - s) / 60);
      }
      function rate(i) {
        return i === 5
          ? Number(state.saturdayRate || 0)
          : i === 6
            ? Number(state.sundayRate || 0)
            : Number(state.weekdayRate || 0);
      }
      function money(n) {
        return "$" + Number(n).toFixed(2);
      }
      function render() {
        if (activeScreen === "schedule") {
          renderSchedule();
          return;
        }
        document.getElementById("weekLabel").textContent =
          fmtDate(viewMonday, false) + " – " + fmtDate(dateFor(6), true);
        const box = document.getElementById("days");
        box.innerHTML = "";
        let sum = 0,
          pay = 0;
        DAYS.forEach((name, i) => {
          let d = dateFor(i),
            key = iso(d),
            e = state.entries[key] || {},
            hrs = paidHours(i);
          sum += hrs;
          pay += hrs * rate(i);
          const card = document.createElement("article");
          card.className = "day" + (iso(new Date()) === key ? " active" : "");
          card.innerHTML = `<div class="dayhead"><div class="dow">${name}</div><div class="date">${fmtDate(d, false)}</div></div>
  <div class="field"><div class="label">Start</div><input class="time" data-day="${i}" data-field="start" type="time" value="${toInput(e.start)}"></div>
  <div class="field"><div class="label">Finish</div><input class="time" data-day="${i}" data-field="finish" type="time" value="${toInput(e.finish)}"></div>
  <div class="field break"><div class="label">Break (min)</div><input class="time" data-day="${i}" data-field="break" type="number" min="0" step="1" value="${e.breakMin ?? (hrs ? (hrs >= 6 ? 30 : 10) : 0)}"></div>
  <div class="totalrow">
    <div class="totalcell">
      <span class="totalcell-label">Total</span>
      <span class="hours ${hrs ? "" : "empty"}">${hrs ? hrs.toFixed(2) + " h" : "0.00 h"}</span>
    </div>
    <div class="totalcell">
      <span class="totalcell-label">Daily income</span>
      <span class="dailyincome ${hrs ? "" : "empty"}">${hrs ? money(hrs * rate(i)) : "$0.00"}</span>
    </div>
  </div>`;
          card
            .querySelectorAll("input")
            .forEach((inp) =>
              inp.addEventListener("change", () =>
                updateEntry(i, inp.dataset.field, inp.value),
              ),
            );
          box.appendChild(card);
        });
        document.getElementById("weeklyHours").textContent =
          sum.toFixed(2) + " h";
        document.getElementById("estimatedPay").textContent = money(pay);
      }
      function toInput(s) {
        let m = parseTime(s);
        return m < 0
          ? ""
          : String(Math.floor(m / 60)).padStart(2, "0") +
              ":" +
              String(m % 60).padStart(2, "0");
      }
      function updateEntry(i, field, value) {
        let key = iso(dateFor(i));
        let e = state.entries[key] || {};
        if (field === "break") e.breakMin = Math.max(0, Number(value) || 0);
        else e[field] = value;
        if (!e.start && !e.finish && !e.breakMin) delete state.entries[key];
        else state.entries[key] = e;
        save();
        render();
      }
      function showModal(html) {
        document.getElementById("modal").innerHTML = html;
        document.getElementById("modalBack").classList.add("show");
      }
      function closeModal() {
        document.getElementById("modalBack").classList.remove("show");
        document.getElementById("modal").classList.remove("calendar-modal");
      }
      document.getElementById("modalBack").addEventListener("click", (e) => {
        if (e.target.id === "modalBack") closeModal();
      });
      function toast(msg) {
        let t = document.getElementById("toast");
        t.textContent = msg;
        t.classList.add("show");
        clearTimeout(toast.timer);
        toast.timer = setTimeout(() => t.classList.remove("show"), 2200);
      }

      function refreshScreen() {
        if (activeScreen === "schedule") showScheduleScreen();
        else render();
      }

      document.getElementById("prevWeek").onclick = () => {
        viewMonday.setDate(viewMonday.getDate() - 7);
        refreshScreen();
      };
      document.getElementById("nextWeek").onclick = () => {
        viewMonday.setDate(viewMonday.getDate() + 7);
        refreshScreen();
      };
      document.getElementById("todayBtn").onclick = () => {
        viewMonday = monday(new Date());
        showWorkScreen();
      };
      document.getElementById("scheduleBtn").addEventListener("click", (e) => {
        e.preventDefault();
        e.stopPropagation();
        if (activeScreen === "schedule") showWorkScreen();
        else showScheduleScreen();
      });
      document.getElementById("clearWeek").onclick = () => {
        closeSettingsMenu();
        if (confirm("Clear all shifts for this week?")) {
          for (let i = 0; i < 7; i++) delete state.entries[iso(dateFor(i))];
          save();
          render();
          toast("Week cleared");
        }
      };
      document.getElementById("ratesBtn").onclick = () => {
        closeSettingsMenu();
        showModal(
          `<h2>Hourly rates</h2><p>Rates are selected automatically by the day. Weekday covers Monday–Friday.</p><div class="modalgrid"><div><label>Weekday</label><input id="mWeek" type="number" step="0.01" value="${state.weekdayRate}"></div><div><label>Saturday</label><input id="mSat" type="number" step="0.01" value="${state.saturdayRate}"></div><div><label>Sunday</label><input id="mSun" type="number" step="0.01" value="${state.sundayRate}"></div></div><div class="modalactions"><button onclick="closeModal()">Cancel</button><button class="primary" onclick="saveRates()">Save</button></div>`,
        );
      };
      window.saveRates = () => {
        state.weekdayRate = Number(document.getElementById("mWeek").value) || 0;
        state.saturdayRate = Number(document.getElementById("mSat").value) || 0;
        state.sundayRate = Number(document.getElementById("mSun").value) || 0;
        save();
        closeModal();
        render();
        toast("Rates saved");
      };
      document.getElementById("formatBtn").onclick = () => {
        closeSettingsMenu();
        showModal(
          `<h2>Time format</h2><p>Choose how saved times are displayed.</p><div class="modalgrid"><label><input id="f24" type="radio" name="fmt" ${state.use24Hour ? "checked" : ""}> 24-hour (14:30)</label><label><input id="f12" type="radio" name="fmt" ${!state.use24Hour ? "checked" : ""}> 12-hour AM/PM (2:30 PM)</label></div><div class="modalactions"><button onclick="closeModal()">Cancel</button><button class="primary" onclick="saveFormat()">Save</button></div>`,
        );
      };
      window.saveFormat = () => {
        state.use24Hour = document.getElementById("f24").checked;
        save();
        closeModal();
        render();
      };
      function closeExportMenu() {
        document.getElementById("exportMenu").removeAttribute("open");
      }
      function closeEmailMenu() {
        document.getElementById("emailMenu").removeAttribute("open");
      }
      function closeSettingsMenu() {
        document.getElementById("settingsMenu").removeAttribute("open");
      }
      function downloadBlob(blob, filename) {
        const url = URL.createObjectURL(blob),
          a = document.createElement("a");
        a.href = url;
        a.download = filename;
        document.body.appendChild(a);
        a.click();
        a.remove();
        setTimeout(() => URL.revokeObjectURL(url), 1000);
      }
      let exportLogoPromise;
      function loadExportLogo() {
        if (!exportLogoPromise) {
          exportLogoPromise = new Promise((resolve) => {
            const image = new Image();
            image.onload = () => resolve(image);
            image.onerror = () => resolve(null);
            image.src = "header-logo.png";
          });
        }
        return exportLogoPromise;
      }
      function drawExportLogo(context, image) {
        if (image) context.drawImage(image, 1240, 40, 90, 90);
      }
      function drawExportCopyright(context, y) {
        context.save();
        context.fillStyle = "#687487";
        context.font = "600 17px system-ui,sans-serif";
        context.textAlign = "right";
        context.fillText("© 2026 Mark Breddy · Puffins", 1330, y);
        context.restore();
      }
      function weekRows() {
        let rows = [];
        for (let i = 0; i < 7; i++) {
          let d = dateFor(i),
            e = state.entries[iso(d)] || {},
            raw = paidHours(i),
            s = parseTime(e.start),
            f = parseTime(e.finish),
            autoBr =
              s >= 0 && f >= 0
                ? (f <= s ? f + 1440 : f) - s >= 360
                  ? 30
                  : 10
                : 0,
            br = e.breakMin ?? autoBr;
          rows.push({
            date: iso(d),
            day: DAYS[i],
            start: displayTime(e.start),
            finish: displayTime(e.finish),
            breakMin: br,
            hours: raw,
            rate: rate(i),
            pay: raw * rate(i),
          });
        }
        return rows;
      }
      document.getElementById("exportPng").onclick = async () => {
        const exportLogo = await loadExportLogo();
        const rows = weekRows(),
          canvas = document.createElement("canvas"),
          x = canvas.getContext("2d");
        canvas.width = 1400;
        canvas.height = 1120;
        const sum = rows.reduce((n, r) => n + r.hours, 0),
          pay = rows.reduce((n, r) => n + r.pay, 0);
        x.fillStyle = "#070a0f";
        x.fillRect(0, 0, canvas.width, canvas.height);
        const glow = x.createRadialGradient(170, 80, 0, 170, 80, 650);
        glow.addColorStop(0, "#24195b");
        glow.addColorStop(1, "rgba(7,10,15,0)");
        x.fillStyle = glow;
        x.fillRect(0, 0, 900, 700);
        x.fillStyle = "#9a7bff";
        x.font = "900 50px system-ui,sans-serif";
        x.fillText("WorkedHours", 70, 92);
        const titleWidth = x.measureText("WorkedHours").width;
        x.fillStyle = "#f4f6fb";
        x.fillText("Tracker", 70 + titleWidth, 92);
        x.fillStyle = "#8e99aa";
        x.font = "600 25px system-ui,sans-serif";
        x.fillText(
          fmtDate(viewMonday, false) + " – " + fmtDate(dateFor(6), true),
          70,
          140,
        );
        x.fillStyle = "#151b25";
        roundRect(x, 70, 185, 1260, 125, 22);
        x.fill();
        x.fillStyle = "#8e99aa";
        x.font = "700 20px system-ui,sans-serif";
        x.fillText("WEEKLY HOURS", 105, 228);
        x.fillText("ESTIMATED GROSS PAY", 735, 228);
        x.fillStyle = "#f4f6fb";
        x.font = "900 43px system-ui,sans-serif";
        x.fillText(sum.toFixed(2) + " h", 105, 282);
        x.fillText(money(pay), 735, 282);
        const headers = [
          "DAY / DATE",
          "START",
          "FINISH",
          "BREAK",
          "HOURS",
          "PAY",
        ];
        const cols = [95, 510, 680, 850, 1020, 1170];
        x.fillStyle = "#8e99aa";
        x.font = "800 18px system-ui,sans-serif";
        headers.forEach((h, i) => x.fillText(h, cols[i], 365));
        rows.forEach((r, i) => {
          const y = 395 + i * 92;
          x.fillStyle = i % 2 ? "#11161f" : "#141a23";
          roundRect(x, 70, y, 1260, 72, 14);
          x.fill();
          x.fillStyle = "#f4f6fb";
          x.font = "800 22px system-ui,sans-serif";
          x.fillText(r.day, 95, y + 31);
          x.fillStyle = "#8e99aa";
          x.font = "600 17px system-ui,sans-serif";
          x.fillText(fmtDate(dateFor(i), false), 95, y + 55);
          x.fillStyle = "#f4f6fb";
          x.font = "700 21px system-ui,sans-serif";
          x.fillText(r.start, 510, y + 44);
          x.fillText(r.finish, 680, y + 44);
          x.fillText(String(r.breakMin) + " min", 850, y + 44);
          x.fillText(r.hours.toFixed(2) + " h", 1020, y + 44);
          x.fillText(money(r.pay), 1170, y + 44);
        });
        x.fillStyle = "#687487";
        x.font = "600 17px system-ui,sans-serif";
        x.fillText(
          "Exported " + new Date().toLocaleDateString("en-AU"),
          70,
          1080,
        );
        drawExportCopyright(x, 1080);
        drawExportLogo(x, exportLogo);
        closeExportMenu();
        try {
          const plugin =
            window.Capacitor &&
            window.Capacitor.Plugins &&
            window.Capacitor.Plugins.GallerySaver;
          if (plugin) {
            await plugin.savePng({
              data: canvas.toDataURL("image/png"),
              fileName: "worktrack-" + iso(viewMonday) + ".png",
            });
            toast("PNG saved to your Gallery");
          } else {
            canvas.toBlob((blob) => {
              if (!blob) {
                toast("PNG export failed");
                return;
              }
              downloadBlob(blob, "worktrack-" + iso(viewMonday) + ".png");
              toast("PNG downloaded");
            }, "image/png");
          }
        } catch (err) {
          toast("Could not save PNG: " + (err.message || err));
        }
      };
      function rowForDate(d) {
        const e = state.entries[iso(d)] || {},
          s = parseTime(e.start),
          f = parseTime(e.finish);
        let raw = 0,
          autoBr = 0;
        if (s >= 0 && f >= 0) {
          let end = f;
          if (end <= s) end += 1440;
          const shift = (end - s) / 60;
          autoBr = shift >= 6 ? 30 : 10;
          raw = Math.max(0, shift);
        }
        const br = e.breakMin ?? autoBr,
          day = d.getDay(),
          r =
            day === 6
              ? Number(state.saturdayRate || 0)
              : day === 0
                ? Number(state.sundayRate || 0)
                : Number(state.weekdayRate || 0);
        return {
          date: iso(d),
          dateObject: new Date(d),
          day: d.toLocaleDateString("en-AU", { weekday: "long" }),
          start: displayTime(e.start),
          finish: displayTime(e.finish),
          breakMin: br,
          hours: raw,
          rate: r,
          pay: raw * r,
        };
      }
      function rowsForRange(start, end) {
        const rows = [];
        for (let d = new Date(start); d <= end; d.setDate(d.getDate() + 1))
          rows.push(rowForDate(d));
        return rows;
      }
      async function saveRangePng(rows, start, end) {
        const exportLogo = await loadExportLogo();
        const canvas = document.createElement("canvas"),
          x = canvas.getContext("2d"),
          height = 430 + rows.length * 92;
        canvas.width = 1400;
        canvas.height = height;
        const sum = rows.reduce((n, r) => n + r.hours, 0),
          pay = rows.reduce((n, r) => n + r.pay, 0);
        x.fillStyle = "#070a0f";
        x.fillRect(0, 0, canvas.width, canvas.height);
        const glow = x.createRadialGradient(170, 80, 0, 170, 80, 650);
        glow.addColorStop(0, "#24195b");
        glow.addColorStop(1, "rgba(7,10,15,0)");
        x.fillStyle = glow;
        x.fillRect(0, 0, 900, Math.min(700, height));
        x.fillStyle = "#9a7bff";
        x.font = "900 50px system-ui,sans-serif";
        x.fillText("WorkedHours", 70, 92);
        const titleWidth = x.measureText("WorkedHours").width;
        x.fillStyle = "#f4f6fb";
        x.fillText("Tracker", 70 + titleWidth, 92);
        x.fillStyle = "#8e99aa";
        x.font = "600 25px system-ui,sans-serif";
        x.fillText(fmtDate(start, false) + " – " + fmtDate(end, true), 70, 140);
        x.fillStyle = "#151b25";
        roundRect(x, 70, 185, 1260, 125, 22);
        x.fill();
        x.fillStyle = "#8e99aa";
        x.font = "700 20px system-ui,sans-serif";
        x.fillText("TOTAL HOURS", 105, 228);
        x.fillText("ESTIMATED GROSS PAY", 735, 228);
        x.fillStyle = "#f4f6fb";
        x.font = "900 43px system-ui,sans-serif";
        x.fillText(sum.toFixed(2) + " h", 105, 282);
        x.fillText(money(pay), 735, 282);
        const headers = [
            "DAY / DATE",
            "START",
            "FINISH",
            "BREAK",
            "HOURS",
            "PAY",
          ],
          cols = [95, 510, 680, 850, 1020, 1170];
        x.fillStyle = "#8e99aa";
        x.font = "800 18px system-ui,sans-serif";
        headers.forEach((h, i) => x.fillText(h, cols[i], 365));
        rows.forEach((r, i) => {
          const y = 395 + i * 92;
          x.fillStyle = i % 2 ? "#11161f" : "#141a23";
          roundRect(x, 70, y, 1260, 72, 14);
          x.fill();
          x.fillStyle = "#f4f6fb";
          x.font = "800 22px system-ui,sans-serif";
          x.fillText(r.day, 95, y + 31);
          x.fillStyle = "#8e99aa";
          x.font = "600 17px system-ui,sans-serif";
          x.fillText(fmtDate(r.dateObject, false), 95, y + 55);
          x.fillStyle = "#f4f6fb";
          x.font = "700 21px system-ui,sans-serif";
          x.fillText(r.start, 510, y + 44);
          x.fillText(r.finish, 680, y + 44);
          x.fillText(String(r.breakMin) + " min", 850, y + 44);
          x.fillText(r.hours.toFixed(2) + " h", 1020, y + 44);
          x.fillText(money(r.pay), 1170, y + 44);
        });
        x.fillStyle = "#687487";
        x.font = "600 17px system-ui,sans-serif";
        x.fillText(
          "Exported " + new Date().toLocaleDateString("en-AU"),
          70,
          height - 25,
        );
        drawExportCopyright(x, height - 25);
        drawExportLogo(x, exportLogo);
        const fileName = "worktrack-" + iso(start) + "-to-" + iso(end) + ".png";
        try {
          const plugin =
            window.Capacitor &&
            window.Capacitor.Plugins &&
            window.Capacitor.Plugins.GallerySaver;
          if (plugin) {
            await plugin.savePng({
              data: canvas.toDataURL("image/png"),
              fileName,
            });
            toast("Date range saved to your Gallery");
          } else {
            canvas.toBlob((blob) => {
              if (!blob) {
                toast("PNG export failed");
                return;
              }
              downloadBlob(blob, fileName);
              toast("PNG downloaded");
            }, "image/png");
          }
        } catch (err) {
          toast("Could not save PNG: " + (err.message || err));
        }
      }
      document.getElementById("exportRangePng").onclick = () => {
        closeExportMenu();
        showModal(
          `<h2>Export custom date range</h2><p>Select the first and last date to include in your PNG. You can export up to 31 days at once.</p><div class="modalrow"><label>Start date<input id="rangeStart" type="date" value="${iso(viewMonday)}"></label><label>End date<input id="rangeEnd" type="date" value="${iso(dateFor(6))}"></label></div><div class="modalactions"><button onclick="closeModal()">Cancel</button><button class="primary" onclick="exportSelectedRange()">Save PNG</button></div>`,
        );
      };
      window.exportSelectedRange = async () => {
        const startValue = document.getElementById("rangeStart").value,
          endValue = document.getElementById("rangeEnd").value;
        if (!startValue || !endValue) {
          toast("Please select both dates");
          return;
        }
        const start = new Date(startValue + "T00:00:00"),
          end = new Date(endValue + "T00:00:00"),
          days = Math.round((end - start) / 86400000) + 1;
        if (days < 1) {
          toast("End date must be after start date");
          return;
        }
        if (days > 31) {
          toast("Please select 31 days or fewer");
          return;
        }
        closeModal();
        await saveRangePng(rowsForRange(start, end), start, end);
      };
      async function emailRangeReport(rows, start, end) {
        const exportLogo = await loadExportLogo();
        const canvas = document.createElement("canvas"),
          x = canvas.getContext("2d"),
          height = 430 + rows.length * 92;
        canvas.width = 1400;
        canvas.height = height;
        const sum = rows.reduce((n, r) => n + r.hours, 0),
          pay = rows.reduce((n, r) => n + r.pay, 0);
        x.fillStyle = "#070a0f";
        x.fillRect(0, 0, canvas.width, canvas.height);
        const glow = x.createRadialGradient(170, 80, 0, 170, 80, 650);
        glow.addColorStop(0, "#24195b");
        glow.addColorStop(1, "rgba(7,10,15,0)");
        x.fillStyle = glow;
        x.fillRect(0, 0, 900, Math.min(700, height));
        x.fillStyle = "#9a7bff";
        x.font = "900 50px system-ui,sans-serif";
        x.fillText("WorkedHours", 70, 92);
        const titleWidth = x.measureText("WorkedHours").width;
        x.fillStyle = "#f4f6fb";
        x.fillText("Tracker", 70 + titleWidth, 92);
        x.fillStyle = "#8e99aa";
        x.font = "600 25px system-ui,sans-serif";
        x.fillText(fmtDate(start, false) + " – " + fmtDate(end, true), 70, 140);
        x.fillStyle = "#151b25";
        roundRect(x, 70, 185, 1260, 125, 22);
        x.fill();
        x.fillStyle = "#8e99aa";
        x.font = "700 20px system-ui,sans-serif";
        x.fillText("TOTAL HOURS", 105, 228);
        x.fillText("ESTIMATED GROSS PAY", 735, 228);
        x.fillStyle = "#f4f6fb";
        x.font = "900 43px system-ui,sans-serif";
        x.fillText(sum.toFixed(2) + " h", 105, 282);
        x.fillText(money(pay), 735, 282);
        const headers = [
            "DAY / DATE",
            "START",
            "FINISH",
            "BREAK",
            "HOURS",
            "PAY",
          ],
          cols = [95, 510, 680, 850, 1020, 1170];
        x.fillStyle = "#8e99aa";
        x.font = "800 18px system-ui,sans-serif";
        headers.forEach((h, i) => x.fillText(h, cols[i], 365));
        rows.forEach((r, i) => {
          const y = 395 + i * 92;
          x.fillStyle = i % 2 ? "#11161f" : "#141a23";
          roundRect(x, 70, y, 1260, 72, 14);
          x.fill();
          x.fillStyle = "#f4f6fb";
          x.font = "800 22px system-ui,sans-serif";
          x.fillText(r.day, 95, y + 31);
          x.fillStyle = "#8e99aa";
          x.font = "600 17px system-ui,sans-serif";
          x.fillText(fmtDate(r.dateObject, false), 95, y + 55);
          x.fillStyle = "#f4f6fb";
          x.font = "700 21px system-ui,sans-serif";
          x.fillText(r.start, 510, y + 44);
          x.fillText(r.finish, 680, y + 44);
          x.fillText(String(r.breakMin) + " min", 850, y + 44);
          x.fillText(r.hours.toFixed(2) + " h", 1020, y + 44);
          x.fillText(money(r.pay), 1170, y + 44);
        });
        x.fillStyle = "#687487";
        x.font = "600 17px system-ui,sans-serif";
        x.fillText(
          "Exported " + new Date().toLocaleDateString("en-AU"),
          70,
          height - 25,
        );
        drawExportCopyright(x, height - 25);
        drawExportLogo(x, exportLogo);
        const fileName = "worktrack-" + iso(start) + "-to-" + iso(end) + ".png",
          subject =
            "WHT hours: " + fmtDate(start, false) + " – " + fmtDate(end, true);
        try {
          const plugin =
            window.Capacitor &&
            window.Capacitor.Plugins &&
            window.Capacitor.Plugins.GallerySaver;
          if (plugin) {
            await plugin.emailPng({
              data: canvas.toDataURL("image/png"),
              fileName,
              subject,
            });
            toast("Email app opened with PNG attached");
          } else {
            canvas.toBlob((blob) => {
              if (!blob) {
                toast("PNG creation failed");
                return;
              }
              downloadBlob(blob, fileName);
              toast("PNG downloaded—attach it to your email");
            }, "image/png");
          }
        } catch (err) {
          toast("Could not open email: " + (err.message || err));
        }
      }
      document.getElementById("emailWeekPng").onclick = async () => {
        closeEmailMenu();
        const start = new Date(viewMonday),
          end = dateFor(6);
        await emailRangeReport(rowsForRange(start, end), start, end);
      };
      document.getElementById("emailRangePng").onclick = () => {
        closeEmailMenu();
        showModal(
          `<h2>Email custom date range</h2><p>Select the first and last date to include in the attached PNG. You can email up to 31 days at once.</p><div class="modalrow"><label>Start date<input id="emailRangeStart" type="date" value="${iso(viewMonday)}"></label><label>End date<input id="emailRangeEnd" type="date" value="${iso(dateFor(6))}"></label></div><div class="modalactions"><button onclick="closeModal()">Cancel</button><button class="primary" onclick="emailSelectedRange()">Create Email</button></div>`,
        );
      };
      window.emailSelectedRange = async () => {
        const startValue = document.getElementById("emailRangeStart").value,
          endValue = document.getElementById("emailRangeEnd").value;
        if (!startValue || !endValue) {
          toast("Please select both dates");
          return;
        }
        const start = new Date(startValue + "T00:00:00"),
          end = new Date(endValue + "T00:00:00"),
          days = Math.round((end - start) / 86400000) + 1;
        if (days < 1) {
          toast("End date must be after start date");
          return;
        }
        if (days > 31) {
          toast("Please select 31 days or fewer");
          return;
        }
        closeModal();
        await emailRangeReport(rowsForRange(start, end), start, end);
      };
      function roundRect(ctx, x, y, w, h, r) {
        ctx.beginPath();
        ctx.roundRect(x, y, w, h, r);
      }
      document.getElementById("exportMenu").addEventListener("toggle", (e) => {
        if (e.target.open) {
          closeSettingsMenu();
        }
      });
      document
        .getElementById("settingsMenu")
        .addEventListener("toggle", (e) => {
          if (e.target.open) {
            closeExportMenu();
            closeEmailMenu();
          }
        });
      document.addEventListener("click", (e) => {
        const menus = [
          document.getElementById("exportMenu"),
          document.getElementById("emailMenu"),
          document.getElementById("settingsMenu"),
        ];
        menus.forEach((menu) => {
          if (menu.open && !menu.contains(e.target))
            menu.removeAttribute("open");
        });
      });

      // Defensive fallback for older saved states.
      state.scheduleEntries = state.scheduleEntries || {};
      let activeScreen = "work";

      function scheduleEntry(i) {
        return state.scheduleEntries[iso(dateFor(i))] || {};
      }

      function updateScheduleEntry(i, field, value) {
        const key = iso(dateFor(i));
        const entry = state.scheduleEntries[key] || {};
        if (field === "clear") {
          delete state.scheduleEntries[key];
        } else if (value) {
          entry[field] = value;
          state.scheduleEntries[key] = entry;
        } else {
          delete entry[field];
          if (!entry.start && !entry.finish) delete state.scheduleEntries[key];
          else state.scheduleEntries[key] = entry;
        }
        save();
        renderSchedule();
      }

      function renderSchedule() {
        const screen = document.getElementById("scheduleScreen");
        document.getElementById("weekLabel").textContent = fmtDate(viewMonday, false) + " – " + fmtDate(dateFor(6), true);
        screen.innerHTML = `<div class="schedule-panel"><div class="schedule-days" id="scheduleDays"></div></div>`;
        const box = document.getElementById("scheduleDays");
        DAYS.forEach((name, i) => {
          const d = dateFor(i), key = iso(d), e = scheduleEntry(i);
          const card = document.createElement("article");
          card.className = "schedule-day" + (iso(new Date()) === key ? " active" : "");
          card.innerHTML = `<div class="schedule-dayhead"><div class="schedule-dow">${name}</div><div class="schedule-date">${fmtDate(d, false)}</div></div>
            <div class="schedule-fields">
              <div class="schedule-field"><div class="label">Start</div><input class="schedule-time" data-field="start" type="time" aria-label="${name} expected start" value="${toInput(e.start)}"></div>
              <div class="schedule-field"><div class="label">End</div><input class="schedule-time" data-field="finish" type="time" aria-label="${name} expected finish" value="${toInput(e.finish)}"></div>
            </div>
            <button type="button" class="schedule-clear" data-field="clear">Clear</button>`;
          card.querySelectorAll("input").forEach(input => input.addEventListener("change", () => updateScheduleEntry(i, input.dataset.field, input.value)));
          card.querySelector(".schedule-clear").addEventListener("click", () => updateScheduleEntry(i, "clear", ""));
          box.appendChild(card);
        });
      }

      function setScreenVisibility(schedule) {
        document.getElementById("appRoot").classList.toggle("schedule-mode", schedule);
        document.getElementById("days").hidden = schedule;
        document.getElementById("workSummary").hidden = schedule;
        document.getElementById("scheduleScreen").classList.toggle("active", schedule);
        document.getElementById("workActions").hidden = schedule;
        document.getElementById("workNote").hidden = schedule;
        document.getElementById("scheduleBtn").classList.toggle("today", schedule);
      }

      function showWorkScreen() {
        activeScreen = "work";
        setScreenVisibility(false);
        render();
      }

      function showScheduleScreen() {
        activeScreen = "schedule";
        setScreenVisibility(true);
        renderSchedule();
      }

      let calendarMonth = new Date();
      calendarMonth.setDate(1);
      function monthName(d) {
        return d.toLocaleDateString("en-AU", {
          month: "long",
          year: "numeric",
        });
      }
      function monthKey(y, m, day) {
        return iso(new Date(y, m, day));
      }
      function monthCalendarHTML() {
        const y = calendarMonth.getFullYear(),
          m = calendarMonth.getMonth();
        const first = new Date(y, m, 1),
          daysInMonth = new Date(y, m + 1, 0).getDate();
        const startCol = (first.getDay() + 6) % 7;
        let cells = [];
        const weeks = Math.ceil((startCol + daysInMonth) / 7);
        let workedDays = 0,
          totalHours = 0,
          biggest = 0;
        for (let w = 0; w < weeks; w++) {
          cells.push(`<div class="week-label">${w + 1}</div>`);
          for (let col = 0; col < 7; col++) {
            const n = w * 7 + col - startCol;
            if (n < 1 || n > daysInMonth) {
              cells.push('<div class="heatcell empty"></div>');
              continue;
            }
            const d = new Date(y, m, n),
              key = iso(d),
              e = state.entries[key] || {};
            const s = parseTime(e.start),
              f = parseTime(e.finish);
            let hrs = 0;
            if (s >= 0 && f >= 0) {
              let end = f;
              if (end <= s) end += 1440;
              hrs = Math.max(0, (end - s) / 60);
            }
            if (hrs > 0) {
              workedDays++;
              totalHours += hrs;
              biggest = Math.max(biggest, hrs);
            }
            let level =
              hrs <= 0
                ? ""
                : hrs < 4
                  ? "level1"
                  : hrs < 7
                    ? "level2"
                    : hrs < 9
                      ? "level3"
                      : "level4";
            const today = key === iso(new Date()) ? " today" : "";
            const title = hrs
              ? `${d.toLocaleDateString("en-AU", { day: "numeric", month: "short" })}: ${hrs.toFixed(2)} h`
              : `${d.toLocaleDateString("en-AU", { day: "numeric", month: "short" })}: No hours logged`;
            cells.push(
              `<button type="button" class="heatcell ${level}${hrs ? " worked" : ""}${today}" data-date="${key}" title="${title} — click to open this week" aria-label="${title}. Click to open this week."><span class="num">${n}</span></button>`,
            );
          }
        }
        return `<div class="calendar-top"><div class="calendar-title">${monthName(calendarMonth)}</div><div class="calendar-nav"><button id="calPrev">←</button><button id="calToday">Today</button><button id="calNext">→</button></div></div>
 <div class="heatmap-wrap"><div class="heatmap-head"><span></span><span>Mon</span><span>Tue</span><span>Wed</span><span>Thu</span><span>Fri</span><span>Sat</span><span>Sun</span></div><div class="heatmap-grid">${cells.join("")}</div><div class="heat-legend"><span>Less</span><span class="legend-box"></span><span class="legend-box l1"></span><span class="legend-box l2"></span><span class="legend-box l3"></span><span class="legend-box l4"></span><span>More</span></div></div>
 <div class="calendar-stats"><span><b>${workedDays}</b> days worked</span><span><b>${totalHours.toFixed(2)} h</b> total</span><span><b>${biggest.toFixed(2)} h</b> longest day</span></div>`;
      }
      function renderCalendar() {
        const modal = document.getElementById("modal");
        modal.classList.add("calendar-modal");
        modal.innerHTML = `<h2>Work calendar</h2><p>Each square is one day. Darker purple means more hours worked.</p>${monthCalendarHTML()}<div class="modalactions"><button onclick="closeCalendar()">Close</button></div>`;
        document.getElementById("modalBack").classList.add("show");
        document.getElementById("calPrev").onclick = () => {
          calendarMonth.setMonth(calendarMonth.getMonth() - 1);
          renderCalendar();
        };
        document.getElementById("calNext").onclick = () => {
          calendarMonth.setMonth(calendarMonth.getMonth() + 1);
          renderCalendar();
        };
        document.getElementById("calToday").onclick = () => {
          calendarMonth = new Date();
          calendarMonth.setDate(1);
          renderCalendar();
        };
        document.querySelectorAll(".heatcell[data-date]").forEach((cell) => {
          cell.onclick = () => {
            const selected = new Date(cell.dataset.date + "T00:00:00");
            viewMonday = monday(selected);
            closeCalendar();
            render();
            toast("Week of " + fmtDate(viewMonday, true));
          };
        });
      }
      window.closeCalendar = () => {
        document.getElementById("modal").classList.remove("calendar-modal");
        closeModal();
      };
      document.getElementById("calendarBtn").onclick = () => {
        if (activeScreen === "schedule") showWorkScreen();
        calendarMonth = new Date(viewMonday);
        calendarMonth.setDate(1);
        renderCalendar();
      };
      function escapeHTML(v) {
        return String(v).replace(
          /[&<>"']/g,
          (c) =>
            ({
              "&": "&amp;",
              "<": "&lt;",
              ">": "&gt;",
              '"': "&quot;",
              "'": "&#39;",
            })[c],
        );
      }
      function sleep(ms) {
        return new Promise((r) => setTimeout(r, ms));
      }

      // Prepare a photographed notebook page for OCR.  This deliberately keeps the
      // page large and removes most of the surrounding desk/background.
      function preprocessPhoto(file, mode = 0) {
        return new Promise((resolve, reject) => {
          const img = new Image();
          img.onload = () => {
            const max = 3200,
              scale = Math.min(
                2.4,
                max / Math.max(img.naturalWidth, img.naturalHeight),
              );
            const sw = Math.round(img.naturalWidth * scale),
              sh = Math.round(img.naturalHeight * scale);
            // Most phone photos put the notebook page in the central/lower part of the
            // frame. Cropping the desk/keyboard/hand first gives OCR far less clutter.
            const mx = Math.round(sw * 0.07),
              my = Math.round(sh * 0.07),
              rx = Math.round(sw * 0.985),
              by = Math.round(sh * 0.94);
            const cw = rx - mx,
              ch = by - my;
            const c = document.createElement("canvas");
            c.width = cw;
            c.height = ch;
            const x = c.getContext("2d", { willReadFrequently: true });
            let angle = 0;
            if (mode === 1) angle = (3 * Math.PI) / 180;
            if (mode === 2) angle = (-3 * Math.PI) / 180;
            x.save();
            x.translate(cw / 2, ch / 2);
            x.rotate(angle);
            x.drawImage(img, -cw / 2 - mx, -ch / 2 - my, sw, sh);
            x.restore();
            let d = x.getImageData(0, 0, cw, ch),
              a = d.data;
            for (let i = 0; i < a.length; i += 4) {
              const g = 0.299 * a[i] + 0.587 * a[i + 1] + 0.114 * a[i + 2];
              let v = g;
              if (mode === 3) {
                v = Math.max(0, Math.min(255, (g - 135) * 1.8 + 135));
              } else if (mode === 4) {
                v = g > 165 ? 255 : 0;
              } else if (mode === 5) {
                v = g > 145 ? 255 : 0;
              }
              a[i] = a[i + 1] = a[i + 2] = v;
            }
            x.putImageData(d, 0, 0);
            resolve(c.toDataURL("image/png"));
            URL.revokeObjectURL(img.src);
          };
          img.onerror = reject;
          img.src = URL.createObjectURL(file);
        });
      }
      function normalizeOCRText(s) {
        return String(s || "")
          .replace(/[|¦]/g, "1")
          .replace(/—|–/g, "-")
          .replace(/\s+/g, " ")
          .trim();
      }
      function normalizeOCRForTime(s) {
        return normalizeOCRText(s)
          .replace(/[OoQ]/g, "0")
          .replace(/[Ss]/g, "5")
          .replace(/[Bb]/g, "8")
          .replace(/[Gg]/g, "9")
          .replace(/[Il]/g, "1");
      }
      function normalizeOCRTime(h, m, ap) {
        h = Number(h);
        m = m === "" || m == null ? 0 : Number(m);
        if (!Number.isFinite(h) || !Number.isFinite(m) || m > 59) return null;
        ap = (ap || "").toUpperCase().replace(/[^APM]/g, "");
        if (ap === "PM" && h < 12) h += 12;
        if (ap === "AM" && h === 12) h = 0;
        return h <= 23
          ? String(h).padStart(2, "0") + ":" + String(m).padStart(2, "0")
          : null;
      }
      function extractTimes(line) {
        const s = normalizeOCRForTime(line)
          .toUpperCase()
          .replace(/\b(A\s*\.??\s*M|P\s*\.??\s*M)\b/g, (x) =>
            x.replace(/\s|\./g, ""),
          );
        const candidates = [];
        const patterns = [
          /\b(\d{1,2})\s*[:.]\s*(\d{1,2})\s*(AM|PM)\b/gi,
          /(?<![\d.:])\b(\d{1,2})\s*(AM|PM)\b/gi,
          /(?<![\d.:])(\d{1,2})(\d{2})\s*(AM|PM)?\b/gi,
          /\b(\d{1,2})\s*[:.]\s*(\d{1,2})\b/gi,
        ];
        for (const re of patterns) {
          for (const hit of s.matchAll(re)) {
            let t;
            if (re === patterns[1]) t = normalizeOCRTime(hit[1], "0", hit[2]);
            else if (re === patterns[2])
              t = normalizeOCRTime(hit[1], hit[2], hit[3]);
            else t = normalizeOCRTime(hit[1], hit[2], hit[3]);
            if (t) candidates.push({ index: hit.index, time: t });
          }
        }
        candidates.sort((a, b) => a.index - b.index);
        const out = [];
        for (const c of candidates) if (!out.includes(c.time)) out.push(c.time);
        return out;
      }
      const MONTHS = {
        jan: 0,
        january: 0,
        feb: 1,
        february: 1,
        mar: 2,
        march: 2,
        apr: 3,
        april: 3,
        may: 4,
        jun: 5,
        june: 5,
        jul: 6,
        july: 6,
        aug: 7,
        august: 7,
        sep: 8,
        sept: 8,
        september: 8,
        oct: 9,
        october: 9,
        nov: 10,
        november: 10,
        dec: 11,
        december: 11,
      };
      function monthFromText(s) {
        const m = String(s || "")
          .toLowerCase()
          .match(
            /\b(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|jun|jul|aug|sep|sept|oct|nov|dec)\b/,
          );
        return m ? { month: MONTHS[m[1]], monthName: m[1] } : null;
      }
      function extractDateInfo(line, currentMonth = null) {
        const s = normalizeOCRText(line).toLowerCase();
        const mm = monthFromText(s);
        const month = mm ? mm.month : currentMonth;
        if (month == null) return null;
        let dm = s.match(/\b(\d{1,2})(?:st|nd|rd|th)?\b/);
        if (!dm) return null;
        const day = Number(dm[1]);
        if (day < 1 || day > 31) return null;
        return { day, month, monthName: mm ? mm.monthName : "" };
      }
      function extractWeekday(line) {
        const s = normalizeOCRText(line)
          .toLowerCase()
          .replace(/\b5at\b/, "sat")
          .replace(/\b5un\b/, "sun");
        const names = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"];
        for (let i = 0; i < names.length; i++)
          if (new RegExp("\\b" + names[i]).test(s)) return i;
        return -1;
      }
      function inferYear(day, month, weekday) {
        const base = new Date().getFullYear();
        // Prefer the current calendar year. Handwritten weekdays are often the first
        // thing OCR gets wrong, so a mismatch should not silently move an entry into
        // a different year.
        if (weekday < 0) return base;
        const current = new Date(base, month, day);
        if (
          current.getMonth() === month &&
          current.getDate() === day &&
          current.getDay() === weekday
        )
          return base;
        return base;
      }
      function dateFromInfo(info, weekday) {
        if (!info) return null;
        const y = inferYear(info.day, info.month, weekday);
        const d = new Date(y, info.month, info.day);
        return d.getMonth() === info.month && d.getDate() === info.day
          ? d
          : null;
      }
      function dateForOCRRow(day, month, weekday, previous) {
        const direct = dateFromInfo({ day, month }, weekday);
        if (direct) return direct;
        if (previous) {
          const d = new Date(previous);
          d.setDate(d.getDate() + 1);
          return d;
        }
        return null;
      }
      function dedupeEntries(found) {
        const map = new Map();
        for (const x of found) {
          if (!x.date || !x.start || !x.finish) continue;
          const k = iso(x.date) + "|" + x.start + "|" + x.finish;
          if (!map.has(k)) map.set(k, x);
        }
        return [...map.values()].sort((a, b) => a.date - b.date);
      }

      // Parse notebook rows even when OCR drops the month, splits the date/time across
      // lines, or reads hour-only entries such as "12pm - 5pm".
      function parseOCRLines(lines) {
        const found = [];
        let lastDate = null,
          lastMonth = null,
          lastWeekday = -1;
        for (let i = 0; i < lines.length; i++) {
          const raw = lines[i],
            line = normalizeOCRText(raw);
          if (!line) continue;
          const wd = extractWeekday(line);
          if (wd >= 0) lastWeekday = wd;
          const explicitMonth = monthFromText(line);
          if (explicitMonth) lastMonth = explicitMonth.month;
          const di = extractDateInfo(line, lastMonth);
          if (di) {
            const candidate = dateFromInfo(di, lastWeekday);
            if (candidate) lastDate = candidate;
            lastMonth = di.month;
          }
          const ts = extractTimes(line);
          if (ts.length >= 2 && lastDate) {
            let d = new Date(lastDate);
            // If a day is visible on this row, prefer that day over the carried date.
            const dm = line.match(/\b(\d{1,2})(?:st|nd|rd|th)?\b/);
            if (dm && lastMonth != null) {
              const candidate = dateFromInfo(
                { day: Number(dm[1]), month: lastMonth },
                lastWeekday,
              );
              if (candidate) d = candidate;
            }
            found.push({ date: d, start: ts[0], finish: ts[1] });
            lastDate = d;
          }
        }
        // Second pass: only combine an adjacent date/time fragment when a single
        // OCR row was split. Avoid merging two complete neighbouring shifts.
        for (let i = 0; i < lines.length - 1; i++) {
          const a = normalizeOCRText(lines[i]),
            b = normalizeOCRText(lines[i + 1]);
          const ta = extractTimes(a),
            tb = extractTimes(b);
          if (ta.length === 1 && tb.length === 1) {
            const combined = a + " " + b;
            const wd = extractWeekday(combined),
              mm = monthFromText(combined),
              di = extractDateInfo(combined, mm?.month ?? lastMonth);
            if (di) {
              const d = dateFromInfo(di, wd);
              if (d) found.push({ date: d, start: ta[0], finish: tb[0] });
            }
          }
        }
        return dedupeEntries(found);
      }

      async function waitForTesseract() {
        try {
          await window.TesseractLoadPromise;
          return !!window.Tesseract;
        } catch (e) {
          throw e;
        }
      }

      document.getElementById("photoInput").onchange = async (e) => {
        const file = e.target.files[0];
        if (!file) return;
        e.target.value = "";
        const url = URL.createObjectURL(file);
        showModal(
          `<h2>Import hours from photo</h2><p id="ocrStatus">Preparing the page…</p><img src="${url}" style="width:100%;max-height:280px;object-fit:contain;background:#080c12;border-radius:8px;border:1px solid #293341"><div id="ocrResults"></div><div class="modalactions"><button onclick="closeModal()">Cancel</button></div>`,
        );
        try {
          document.getElementById("ocrStatus").textContent =
            "Loading the handwriting recognition engine…";
          await waitForTesseract();
          const worker = await Tesseract.createWorker("eng", 1, {
            workerPath:
              "https://cdn.jsdelivr.net/npm/tesseract.js@5.1.1/dist/worker.min.js",
            corePath: "https://cdn.jsdelivr.net/npm/tesseract.js-core@5.1.1",
            langPath: "https://tessdata.projectnaptha.com/4.0.0",
          });
          const passes = [];
          const runs = [
            { mode: 0, psm: "6", label: "Reading the notebook…" },
            { mode: 1, psm: "6", label: "Straightening the handwriting…" },
            { mode: 2, psm: "11", label: "Trying another page angle…" },
            { mode: 3, psm: "6", label: "Enhancing the handwriting…" },
            { mode: 4, psm: "11", label: "Trying a high-contrast pass…" },
            { mode: 5, psm: "11", label: "Checking the page one more time…" },
          ];
          for (const run of runs) {
            document.getElementById("ocrStatus").textContent = run.label;
            await worker.setParameters({
              tessedit_pageseg_mode: run.psm,
              preserve_interword_spaces: "1",
              user_defined_dpi: "300",
              thresholding_method: run.mode >= 4 ? "2" : "0",
            });
            const img = await preprocessPhoto(file, run.mode);
            const r = await worker.recognize(img);
            passes.push(r.data.text || "");
          }
          await worker.terminate();
          const allText = passes.join("\n");
          const lines = allText
            .split(/\r?\n/)
            .map((x) => x.trim())
            .filter(Boolean);
          const unique = parseOCRLines(lines);
          const status = document.getElementById("ocrStatus"),
            out = document.getElementById("ocrResults");
          if (!unique.length) {
            status.textContent =
              "I could not confidently read the shifts from this photo.";
            out.innerHTML = `<p style="font-size:11px;color:#aab4c3">This photo style is supported, but handwriting can still confuse the browser OCR. Try holding the phone directly above the page and keeping the whole writing area in good light.</p><div class="ocr-preview">${escapeHTML(allText.slice(0, 2600)) || "(No OCR text returned.)"}</div>`;
            return;
          }
          status.textContent =
            "I found these shifts. Please check them before importing.";
          out.innerHTML =
            unique
              .map(
                (x, i) =>
                  `<div class="modalrow" style="margin-top:10px"><div><label>Date</label><input id="ocrD${i}" type="date" value="${iso(x.date)}"></div><div><label>Start</label><input id="ocrS${i}" type="time" value="${x.start}"></div><div><label>Finish</label><input id="ocrE${i}" type="time" value="${x.finish}"></div></div>`,
              )
              .join("") +
            `<p style="font-size:10px;color:#8f9bad;margin-top:10px">The recognizer is tuned for handwritten rows with dates like “14th July” and times like “11.02am – 5.33pm”. Please review the results before importing.</p><div class="modalactions"><button onclick="closeModal()">Cancel</button><button class="primary" onclick="importOCR()">Import ${unique.length} shift${unique.length === 1 ? "" : "s"}</button></div>`;
          window.importOCR = () => {
            let count = 0;
            for (let i = 0; i < unique.length; i++) {
              const ds = document.getElementById("ocrD" + i).value;
              if (!ds) continue;
              const d = new Date(ds + "T00:00:00");
              const key = iso(d),
                st = document.getElementById("ocrS" + i).value,
                fn = document.getElementById("ocrE" + i).value;
              if (!st || !fn) continue;
              state.entries[key] = { start: st, finish: fn };
              count++;
            }
            save();
            closeModal();
            render();
            toast(count + " shift" + (count === 1 ? "" : "s") + " imported");
          };
        } catch (err) {
          const status = document.getElementById("ocrStatus"),
            out = document.getElementById("ocrResults");
          if (status) status.textContent = "OCR could not run in this browser.";
          if (out)
            out.innerHTML =
              '<div class="ocr-preview">' +
              escapeHTML(err.message || err) +
              "</div>";
        }
      };

      // Populate the current week immediately when the app first opens.
      refreshScreen();
      restoreDeviceSave();
    