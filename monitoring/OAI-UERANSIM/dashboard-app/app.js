/* ==========================================================================
   5G OAI & GRAFANA MONITORING CONSOLE - INTERACTIVE JAVASCRIPT
   ========================================================================== */

document.addEventListener('DOMContentLoaded', () => {
    initNavigation();
    initPodData();
    initCharts();
    initTrafficSimulator();
    initPromQLExplorer();
});

// 1. Navigation & Tab Switching
function initNavigation() {
    const navItems = document.querySelectorAll('.nav-item');
    const tabPanes = document.querySelectorAll('.tab-pane');
    const pageTitle = document.getElementById('page-title');
    const pageSubtitle = document.getElementById('page-subtitle');

    const titles = {
        'overview': { title: 'System Overview', sub: 'Real-time status of 5G Standalone Core & Kubernetes Pods' },
        'topology': { title: '5G Core Network Topology', sub: 'Interactive 3GPP Release 16 Architecture & Data Flow' },
        'grafana': { title: 'Grafana Control Center', sub: 'Live Prometheus Telemetry & K8s Dashboards' },
        'metrics': { title: 'Kubernetes Pod Telemetry', sub: 'Resource utilization, CPU, Memory & Network rates' },
        'traffic': { title: 'Traffic & iPerf3 Simulator', sub: 'Simulate UE user data traffic & network throughput' },
        'promql': { title: 'PromQL Query Studio', sub: 'Execute live Prometheus queries against cluster metrics' }
    };

    navItems.forEach(btn => {
        btn.addEventListener('click', () => {
            const targetTab = btn.getAttribute('data-tab');

            navItems.forEach(b => b.classList.remove('active'));
            tabPanes.forEach(pane => pane.classList.remove('active'));

            btn.classList.add('active');
            const activePane = document.getElementById(`tab-${targetTab}`);
            if (activePane) activePane.classList.add('active');

            if (titles[targetTab]) {
                pageTitle.textContent = titles[targetTab].title;
                pageSubtitle.textContent = titles[targetTab].sub;
            }
        });
    });

    const refreshBtn = document.getElementById('quick-refresh-btn');
    if (refreshBtn) {
        refreshBtn.addEventListener('click', () => {
            refreshBtn.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> Syncing...';
            setTimeout(() => {
                refreshBtn.innerHTML = '<i class="fa-solid fa-arrows-rotate"></i> Sync Metrics';
                updateMetricsValues();
            }, 800);
        });
    }

    const reloadGrafanaBtn = document.getElementById('grafana-frame-reload');
    const dashboardSelect = document.getElementById('grafana-dashboard-select');
    const externalLink = document.getElementById('grafana-external-link');
    const iframe = document.getElementById('grafana-iframe');

    if (dashboardSelect && iframe) {
        dashboardSelect.addEventListener('change', (e) => {
            const url = e.target.value;
            iframe.src = url;
            if (externalLink) externalLink.href = url.replace('?kiosk=tv', '');
        });
    }

    if (reloadGrafanaBtn && iframe) {
        reloadGrafanaBtn.addEventListener('click', () => {
            iframe.src = iframe.src;
        });
    }
}

// 2. Pod Data Management
const podDataList = [
    { name: 'case3-mysql-66db7fdcc6-qzvjr', ns: 'oai-tutorial', status: 'Running', restarts: 3, cpu: '18 mCPU', mem: '240 MiB', role: 'Database' },
    { name: 'oai-amf-54954b5cd-dx6nv', ns: 'oai-tutorial', status: 'Running', restarts: 3, cpu: '34 mCPU', mem: '185 MiB', role: 'Core (Control)' },
    { name: 'oai-ausf-7455cd9d8b-mxjnp', ns: 'oai-tutorial', status: 'Running', restarts: 3, cpu: '12 mCPU', mem: '120 MiB', role: 'Core (Auth)' },
    { name: 'oai-cu-cp-6894ccdc6-jrnrs', ns: 'oai-tutorial', status: 'Running', restarts: 3, cpu: '45 mCPU', mem: '210 MiB', role: 'RAN Control' },
    { name: 'oai-cu-up-5b659c9667-7twmd', ns: 'oai-tutorial', status: 'Running', restarts: 3, cpu: '62 mCPU', mem: '310 MiB', role: 'RAN User Plane' },
    { name: 'oai-du-6b54c44cb9-sr6bc', ns: 'oai-tutorial', status: 'Running', restarts: 5, cpu: '85 mCPU', mem: '420 MiB', role: 'Distributed Unit' },
    { name: 'oai-nr-ue-54b5cdbbc9-8fj69', ns: 'oai-tutorial', status: 'Running', restarts: 5, cpu: '40 mCPU', mem: '190 MiB', role: 'UE Simulator' },
    { name: 'oai-nrf-9cd68d98-bmkrj', ns: 'oai-tutorial', status: 'Running', restarts: 3, cpu: '15 mCPU', mem: '140 MiB', role: 'Core Repo' },
    { name: 'oai-smf-749545b8f7-2hmwh', ns: 'oai-tutorial', status: 'Running', restarts: 3, cpu: '28 mCPU', mem: '175 MiB', role: 'Session Mgmt' },
    { name: 'oai-traffic-server-5f8b4f7fcd-7mtwd', ns: 'oai-tutorial', status: 'Running', restarts: 3, cpu: '95 mCPU', mem: '280 MiB', role: 'Traffic Sink' },
    { name: 'oai-udm-5c8cc9f68c-cmj7t', ns: 'oai-tutorial', status: 'Running', restarts: 3, cpu: '14 mCPU', mem: '130 MiB', role: 'User Data' },
    { name: 'oai-udr-5996fcc9f6-299jx', ns: 'oai-tutorial', status: 'Running', restarts: 3, cpu: '16 mCPU', mem: '145 MiB', role: 'User Repo' },
    { name: 'oai-upf-65d8b5d89c-rc8ph', ns: 'oai-tutorial', status: 'Running', restarts: 3, cpu: '110 mCPU', mem: '512 MiB', role: 'User Plane Data' },
    { name: 'grafana-8fc4884f7-2ccj4', ns: 'monitoring', status: 'Running', restarts: 0, cpu: '25 mCPU', mem: '115 MiB', role: 'Visualization' },
    { name: 'prometheus-deployment-854d8f784f-mlfgj', ns: 'monitoring', status: 'Running', restarts: 0, cpu: '70 mCPU', mem: '340 MiB', role: 'Metrics Engine' }
];

function initPodData() {
    const podListContainer = document.getElementById('pod-list-container');
    const podTableBody = document.getElementById('pod-table-body');

    if (podListContainer) {
        podListContainer.innerHTML = podDataList.map(pod => `
            <div class="pod-item">
                <span class="pod-name"><i class="fa-solid fa-cube text-muted"></i> ${pod.name}</span>
                <span class="badge badge-success">${pod.status}</span>
            </div>
        `).join('');
    }

    if (podTableBody) {
        podTableBody.innerHTML = podDataList.map(pod => `
            <tr>
                <td><code class="code-font">${pod.name}</code></td>
                <td><span class="badge badge-primary">${pod.ns}</span></td>
                <td><span class="badge badge-success"><i class="fa-solid fa-circle-check"></i> ${pod.status}</span></td>
                <td>${pod.restarts}</td>
                <td class="code-font">${pod.cpu}</td>
                <td class="code-font">${pod.mem}</td>
                <td><strong>${pod.role}</strong></td>
            </tr>
        `).join('');
    }
}

// 3. Real-time Charts Initialization (Chart.js)
let liveChart, cpuGauge, memGauge, netRateChart, trafficSimChart;

function initCharts() {
    // 3.1 Live Network Throughput Line Chart
    const ctxLive = document.getElementById('liveThroughputChart');
    if (ctxLive) {
        const timeLabels = Array.from({length: 12}, (_, i) => `${(11-i)*5}s ago`).reverse();
        const initialData = [420, 510, 480, 620, 750, 810, 790, 840, 890, 830, 860, 840];

        liveChart = new Chart(ctxLive, {
            type: 'line',
            data: {
                labels: timeLabels,
                datasets: [{
                    label: 'User Plane Throughput (Mbps)',
                    data: initialData,
                    borderColor: '#3b82f6',
                    backgroundColor: 'rgba(59, 130, 246, 0.12)',
                    fill: true,
                    tension: 0.4,
                    borderWidth: 2,
                    pointRadius: 3
                }, {
                    label: 'Latency (ms)',
                    data: [5.2, 4.8, 5.0, 4.5, 4.2, 4.1, 4.3, 4.2, 4.0, 4.2, 4.1, 4.2],
                    borderColor: '#10b981',
                    backgroundColor: 'transparent',
                    borderWidth: 2,
                    borderDash: [5, 5],
                    pointRadius: 2,
                    yAxisID: 'y1'
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                    x: { grid: { color: 'rgba(255, 255, 255, 0.05)' }, ticks: { color: '#9ca3af' } },
                    y: { grid: { color: 'rgba(255, 255, 255, 0.05)' }, ticks: { color: '#9ca3af' }, title: { display: true, text: 'Mbps', color: '#9ca3af' } },
                    y1: { position: 'right', grid: { drawOnChartArea: false }, ticks: { color: '#10b981' }, title: { display: true, text: 'ms', color: '#10b981' } }
                },
                plugins: { legend: { labels: { color: '#f3f4f6' } } }
            }
        });

        // Dynamic update pulse
        setInterval(() => {
            const nextTp = 800 + Math.floor(Math.random() * 120) - 40;
            const nextLat = (4.0 + Math.random() * 0.5).toFixed(1);

            liveChart.data.datasets[0].data.shift();
            liveChart.data.datasets[0].data.push(nextTp);

            liveChart.data.datasets[1].data.shift();
            liveChart.data.datasets[1].data.push(parseFloat(nextLat));

            liveChart.update('none');

            document.getElementById('qs-tp-val').textContent = `${nextTp} Mbps`;
            document.getElementById('qs-latency-val').textContent = `${nextLat} ms`;
        }, 3000);
    }

    // 3.2 CPU Gauge Chart
    const ctxCpu = document.getElementById('cpuGaugeChart');
    if (ctxCpu) {
        cpuGauge = new Chart(ctxCpu, {
            type: 'doughnut',
            data: {
                labels: ['Used CPU', 'Available'],
                datasets: [{
                    data: [24.5, 75.5],
                    backgroundColor: ['#10b981', 'rgba(255, 255, 255, 0.08)'],
                    borderWidth: 0
                }]
            },
            options: {
                cutout: '75%',
                responsive: true,
                plugins: { legend: { display: false } }
            }
        });
    }

    // 3.3 Memory Gauge Chart
    const ctxMem = document.getElementById('memGaugeChart');
    if (ctxMem) {
        memGauge = new Chart(ctxMem, {
            type: 'doughnut',
            data: {
                labels: ['Used Memory', 'Available'],
                datasets: [{
                    data: [30.1, 69.9],
                    backgroundColor: ['#f59e0b', 'rgba(255, 255, 255, 0.08)'],
                    borderWidth: 0
                }]
            },
            options: {
                cutout: '75%',
                responsive: true,
                plugins: { legend: { display: false } }
            }
        });
    }

    // 3.4 Network RX/TX Doughnut
    const ctxNet = document.getElementById('netRateChart');
    if (ctxNet) {
        netRateChart = new Chart(ctxNet, {
            type: 'doughnut',
            data: {
                labels: ['RX (Ingress)', 'TX (Egress)'],
                datasets: [{
                    data: [59, 41],
                    backgroundColor: ['#3b82f6', '#8b5cf6'],
                    borderWidth: 0
                }]
            },
            options: {
                cutout: '75%',
                responsive: true,
                plugins: { legend: { display: false } }
            }
        });
    }
}

// 4. Traffic & iPerf3 Simulator Logic
function initTrafficSimulator() {
    const rangeInput = document.getElementById('ue-range-slider');
    const countDisp = document.getElementById('ue-count-disp');
    const startBtn = document.getElementById('start-traffic-btn');
    const stopBtn = document.getElementById('stop-traffic-btn');
    const statusBadge = document.getElementById('test-status-badge');

    const rateVal = document.getElementById('t-rate-val');
    const lossVal = document.getElementById('t-loss-val');
    const jitterVal = document.getElementById('t-jitter-val');

    let simInterval = null;

    if (rangeInput && countDisp) {
        rangeInput.addEventListener('input', (e) => {
            countDisp.textContent = e.target.value;
        });
    }

    const ctxSim = document.getElementById('trafficSimChart');
    if (ctxSim) {
        trafficSimChart = new Chart(ctxSim, {
            type: 'bar',
            data: {
                labels: ['UE 1', 'UE 2', 'UE 3', 'UE 4', 'UE 5'],
                datasets: [{
                    label: 'Bandwidth (Mbps)',
                    data: [180, 175, 190, 165, 185],
                    backgroundColor: 'rgba(59, 130, 246, 0.7)',
                    borderRadius: 6
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                    x: { ticks: { color: '#9ca3af' } },
                    y: { ticks: { color: '#9ca3af' }, title: { display: true, text: 'Mbps', color: '#9ca3af' } }
                },
                plugins: { legend: { labels: { color: '#f3f4f6' } } }
            }
        });
    }

    if (startBtn && stopBtn) {
        startBtn.addEventListener('click', () => {
            const numUes = parseInt(rangeInput.value);
            startBtn.disabled = true;
            stopBtn.disabled = false;
            statusBadge.textContent = 'Running iPerf3 Load Test...';
            statusBadge.className = 'badge badge-success';

            // Generate UEs labels & data
            trafficSimChart.data.labels = Array.from({length: numUes}, (_, i) => `UE ${i+1}`);
            trafficSimChart.data.datasets[0].data = Array.from({length: numUes}, () => 150 + Math.floor(Math.random() * 50));
            trafficSimChart.update();

            simInterval = setInterval(() => {
                const newData = Array.from({length: numUes}, () => 150 + Math.floor(Math.random() * 80));
                trafficSimChart.data.datasets[0].data = newData;
                trafficSimChart.update('none');

                const totalRate = newData.reduce((a, b) => a + b, 0);
                rateVal.textContent = `${totalRate} Mbps`;
                lossVal.textContent = `${(Math.random() * 0.05).toFixed(3)}%`;
                jitterVal.textContent = `${(0.08 + Math.random() * 0.08).toFixed(2)} ms`;
            }, 1500);
        });

        stopBtn.addEventListener('click', () => {
            clearInterval(simInterval);
            startBtn.disabled = false;
            stopBtn.disabled = true;
            statusBadge.textContent = 'Idle';
            statusBadge.className = 'badge badge-pulse';

            rateVal.textContent = '0 Mbps';
            lossVal.textContent = '0.00%';
            jitterVal.textContent = '0.12 ms';

            trafficSimChart.data.datasets[0].data = Array.from({length: trafficSimChart.data.labels.length}, () => 0);
            trafficSimChart.update();
        });
    }
}

// 5. PromQL Query Studio
function initPromQLExplorer() {
    const queryInput = document.getElementById('promql-input');
    const runBtn = document.getElementById('run-promql-btn');
    const output = document.getElementById('promql-output');
    const presetBtns = document.querySelectorAll('.preset-btn');

    presetBtns.forEach(btn => {
        btn.addEventListener('click', () => {
            const query = btn.getAttribute('data-query');
            if (queryInput && query) {
                queryInput.value = query;
                executeMockQuery(query);
            }
        });
    });

    if (runBtn && queryInput) {
        runBtn.addEventListener('click', () => {
            executeMockQuery(queryInput.value);
        });
    }

    function executeMockQuery(queryStr) {
        output.textContent = "Connecting to http://prometheus-service.monitoring.svc:8080...\nExecuting PromQL query...";
        
        setTimeout(() => {
            const mockResponse = {
                status: "success",
                data: {
                    resultType: "vector",
                    result: [
                        { metric: { pod: "oai-amf-54954b5cd-dx6nv", namespace: "oai-tutorial" }, value: [Date.now() / 1000, "0.034"] },
                        { metric: { pod: "oai-smf-749545b8f7-2hmwh", namespace: "oai-tutorial" }, value: [Date.now() / 1000, "0.028"] },
                        { metric: { pod: "oai-upf-65d8b5d89c-rc8ph", namespace: "oai-tutorial" }, value: [Date.now() / 1000, "0.110"] },
                        { metric: { pod: "ueransim-gnb-76b9f4859-x2k4l", namespace: "oai-tutorial" }, value: [Date.now() / 1000, "0.085"] }
                    ]
                }
            };
            output.textContent = JSON.stringify(mockResponse, null, 2);
        }, 500);
    }
}

function updateMetricsValues() {
    const cpuVal = document.getElementById('kpi-cpu-val');
    if (cpuVal) cpuVal.textContent = `${(22 + Math.random() * 5).toFixed(1)}%`;

    const memVal = document.getElementById('kpi-mem-val');
    if (memVal) memVal.textContent = `${(4.6 + Math.random() * 0.4).toFixed(1)} GB / 16 GB`;
}
