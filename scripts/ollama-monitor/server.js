import express from 'express';
import si from 'systeminformation';
import http from 'http';

const app = express();
const port = 3000;
const OLLAMA_URL = 'http://localhost:11434';

app.use(express.static('public'));
app.use(express.json({ limit: '50mb' }));

const recentRequests = [];

// Wrapper Endpoint for Proxying to Ollama seamlessly
app.all(['/v1/*', '/api/generate', '/api/chat', '/api/embeddings'], async (req, res) => {
    const url = `${OLLAMA_URL}${req.originalUrl}`;
    const startTime = Date.now();
    let ttfb = 0;

    try {
        const fetchOptions = {
            method: req.method,
            headers: { 'Content-Type': 'application/json' },
            body: req.method !== 'GET' ? JSON.stringify(req.body) : undefined
        };

        const fetchRes = await fetch(url, { ...fetchOptions });
        ttfb = Date.now() - startTime; // Time to first byte

        const bodyText = await fetchRes.text();
        const endTime = Date.now();
        const e2eLatency = endTime - startTime;

        let parsed = {};
        try { parsed = JSON.parse(bodyText); } catch (e) { }

        const record = {
            id: Date.now(),
            path: req.originalUrl,
            model: req.body?.model || 'Unknown',
            ttfb: ttfb,
            e2eLatency: e2eLatency,
            total_duration: parsed.total_duration ? (parsed.total_duration / 1e6).toFixed(2) : null,
            load_duration: parsed.load_duration ? (parsed.load_duration / 1e6).toFixed(2) : null,
            prompt_eval_count: parsed.prompt_eval_count || (parsed.usage ? parsed.usage.prompt_tokens : null),
            eval_count: parsed.eval_count || (parsed.usage ? parsed.usage.completion_tokens : null),
            tokensPerSec: null
        };

        if (record.eval_count && e2eLatency > 0) {
            record.tokensPerSec = (record.eval_count / ((e2eLatency - ttfb) / 1000)).toFixed(2);
        }

        if (record.path.includes('generate') || record.path.includes('chat') || record.path.includes('embeddings')) {
            recentRequests.unshift(record);
            if (recentRequests.length > 50) recentRequests.pop();
        }

        res.status(fetchRes.status).send(bodyText);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});
app.get('/api/metrics', async (req, res) => {
    try {
        // 1. Fetch system CPU & Memory
        const cpuLoad = await si.currentLoad();
        const memData = await si.mem();
        const graphicsData = await si.graphics(); // Fetches GPU info

        // 2. Query Ollama's active, loaded models
        let ollamaModels = [];
        let ollamaStatus = 'offline';
        try {
            const ollamaRes = await fetch(`${OLLAMA_URL}/api/ps`);
            if (ollamaRes.ok) {
                const ollamaJson = await ollamaRes.json();
                ollamaModels = ollamaJson.models || [];
                ollamaStatus = 'online';
            }
        } catch (e) {
            ollamaStatus = 'offline';
        }

        res.json({
            timestamp: Date.now(),
            system: {
                cpu: {
                    loadPercent: cpuLoad.currentLoad.toFixed(2),
                },
                memory: {
                    total: (memData.total / 1024 / 1024 / 1024).toFixed(2) + ' GB',
                    used: (memData.used / 1024 / 1024 / 1024).toFixed(2) + ' GB',
                    percent: ((memData.used / memData.total) * 100).toFixed(2),
                },
                gpu: graphicsData.controllers.map(g => ({
                    model: g.model,
                    vram: g.vram ? g.vram + ' MB' : 'N/A',
                    utilization: g.utilizationGpu || 0,
                    memoryUsed: g.memoryUsed || 0,
                    temperature: g.temperatureGpu || 'N/A'
                }))
            },
            ollama: {
                status: ollamaStatus,
                loadedModels: ollamaModels.map(m => ({
                    name: m.name,
                    size: (m.size / 1024 / 1024 / 1024).toFixed(2) + ' GB',
                    format: m.details?.format,
                    family: m.details?.family,
                    quantization: m.details?.quantization_level
                }))
            },
            requests: recentRequests
        });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.listen(port, () => {
    console.log(`🚀 Ollama Monitor mapping local LLM telemetry!`);
    console.log(`🌐 Dashboard running at http://localhost:${port}`);
});
