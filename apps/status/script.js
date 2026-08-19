// Genera las tiras de uptime de 90 dias en CSS puro (sin libreria de graficas).
// Los datos son estaticos/ficticios: un pequeno set de dias con incidencia por
// servicio, coherente con el historial de incidentes listado en la pagina.

const TOTAL_DAYS = 90;

const INCIDENT_DAYS = {
  api: {},
  dashboard: { 20: "warn" },
  statuspages: {},
  alerting: { 6: "warn", 7: "warn" },
  ingestion: { 18: "bad" },
  docs: {},
};

function formatDate(daysAgo) {
  const d = new Date();
  d.setDate(d.getDate() - daysAgo);
  return d.toLocaleDateString("es-ES", { day: "2-digit", month: "short" });
}

function statusLabel(status) {
  if (status === "bad") return "Outage";
  if (status === "warn") return "Degraded";
  return "Operational";
}

document.querySelectorAll(".uptime-strip").forEach((strip) => {
  const service = strip.dataset.service;
  const incidents = INCIDENT_DAYS[service] || {};

  for (let i = TOTAL_DAYS - 1; i >= 0; i--) {
    const status = incidents[i] || "ok";
    const bar = document.createElement("span");
    bar.className = `uptime-bar uptime-bar--${status}`;
    bar.title = `${formatDate(i)} — ${statusLabel(status)}`;
    strip.appendChild(bar);
  }
});
