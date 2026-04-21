// admin/app.js

const CONFIG = {
    // ⚠️ Update this URL to your actual production backend (or keep ngrok if still testing)
    API_BASE_URL: 'https://currenta-backend-etzmdxn4fa-ey.a.run.app', // PRODUCTION
    
    SUPABASE_URL: 'https://trfqhobnkgtfccrdsexa.supabase.co',
    SUPABASE_ANON_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRyZnFob2Jua2d0ZmNjcmRzZXhhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIyODI1NzMsImV4cCI6MjA4Nzg1ODU3M30.CkbozQuTUm5v9X_eQoVdceI41QVXau9pivfqLDJOjfk',
    
    // --- Session Security Config ---
    SESSION_LIMIT_MS: 12 * 60 * 60 * 1000, // 12 hours
    WARNING_THRESHOLD_MS: 5 * 60 * 1000,    // 5 minutes
    CHECK_INTERVAL_MS: 10 * 1000            // Check every 10 seconds
};

const VALID_CATEGORIES = ["politics", "tech", "science", "business", "sports", "entertainment", "health", "world", "environment"];

let supabaseClient;
let session = null;
let sessionStartTime = null;
let warningModalActive = false;
let checkInterval = null;
let selectedCategories = [];

function clearTrailingHash() {
    // Supabase OAuth can leave a trailing '#', which confuses operators but carries no state.
    if (window.location.hash === '#') {
        const cleanUrl = `${window.location.pathname}${window.location.search}`;
        window.history.replaceState({}, document.title, cleanUrl);
    }
}

async function verifyAdminViaLegacyProbe() {
    // Backward compatibility for older backend deployments that lack /api/admin/session/check.
    const response = await fetch(`${CONFIG.API_BASE_URL}/api/admin/news/draft`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${session.access_token}`
        },
        body: JSON.stringify({
            url: 'https://example.invalid/admin-auth-probe'
        })
    });

    if (response.status === 401 || response.status === 403) {
        throw new Error('Access denied: this account is not an admin.');
    }

    if (response.status === 404) {
        throw new Error('Admin API not found on backend deployment (/api/admin/*).');
    }

    if (!response.ok && response.status >= 500) {
        throw new Error('Admin backend is reachable but currently unhealthy.');
    }

    // Any non-auth response means the request reached an admin-protected route.
    return true;
}

async function enforceAdminSession() {
    if (!session?.access_token) return false;

    const errorEl = document.getElementById('auth-error');

    try {
        const response = await fetch(`${CONFIG.API_BASE_URL}/api/admin/session/check`, {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${session.access_token}`
            }
        });

        if (response.status === 403 || response.status === 401) {
            await supabaseClient.auth.signOut();
            errorEl.textContent = 'Access denied: this account is not an admin.';
            return false;
        }

        if (!response.ok) {
            let detail = '';
            try {
                const body = await response.json();
                detail = body?.detail || '';
            } catch (_) {
                detail = '';
            }

            if (response.status === 404) {
                // Fallback to legacy admin probe when this endpoint is missing in older deployments.
                return await verifyAdminViaLegacyProbe();
            }

            throw new Error(detail || `Unable to verify admin privileges right now (HTTP ${response.status}).`);
        }

        errorEl.textContent = '';
        if (response.ok) {
            const data = await response.json();
            if (data.email) {
                document.getElementById('user-email-display').textContent = data.email;
            }
        }
        return true;
    } catch (err) {
        errorEl.textContent = err.message || 'Unable to verify admin privileges right now.';
        await supabaseClient.auth.signOut();
        return false;
    }
}

const COUNTRIES = [
    { name: "Afghanistan", code: "AF" }, { name: "Albania", code: "AL" }, { name: "Algeria", code: "DZ" },
    { name: "Andorra", code: "AD" }, { name: "Angola", code: "AO" }, { name: "Antigua and Barbuda", code: "AG" },
    { name: "Argentina", code: "AR" }, { name: "Armenia", code: "AM" }, { name: "Australia", code: "AU" },
    { name: "Austria", code: "AT" }, { name: "Azerbaijan", code: "AZ" }, { name: "Bahamas", code: "BS" },
    { name: "Bahrain", code: "BH" }, { name: "Bangladesh", code: "BD" }, { name: "Barbados", code: "BB" },
    { name: "Belarus", code: "BY" }, { name: "Belgium", code: "BE" }, { name: "Belize", code: "BZ" },
    { name: "Benin", code: "BJ" }, { name: "Bhutan", code: "BT" }, { name: "Bolivia", code: "BO" },
    { name: "Bosnia and Herzegovina", code: "BA" }, { name: "Botswana", code: "BW" }, { name: "Brazil", code: "BR" },
    { name: "Brunei", code: "BN" }, { name: "Bulgaria", code: "BG" }, { name: "Burkina Faso", code: "BF" },
    { name: "Burundi", code: "BI" }, { name: "Cabo Verde", code: "CV" }, { name: "Cambodia", code: "KH" },
    { name: "Cameroon", code: "CM" }, { name: "Canada", code: "CA" }, { name: "Central African Republic", code: "CF" },
    { name: "Chad", code: "TD" }, { name: "Chile", code: "CL" }, { name: "China", code: "CN" },
    { name: "Colombia", code: "CO" }, { name: "Comoros", code: "KM" }, { name: "Congo (Congo-Brazzaville)", code: "CG" },
    { name: "Costa Rica", code: "CR" }, { name: "Croatia", code: "HR" }, { name: "Cuba", code: "CU" },
    { name: "Cyprus", code: "CY" }, { name: "Czechia (Czech Republic)", code: "CZ" }, { name: "Democratic Republic of the Congo", code: "CD" },
    { name: "Denmark", code: "DK" }, { name: "Djibouti", code: "DJ" }, { name: "Dominica", code: "DM" },
    { name: "Dominican Republic", code: "DO" }, { name: "Ecuador", code: "EC" }, { name: "Egypt", code: "EG" },
    { name: "El Salvador", code: "SV" }, { name: "Equatorial Guinea", code: "GQ" }, { name: "Eritrea", code: "ER" },
    { name: "Estonia", code: "EE" }, { name: "Eswatini", code: "SZ" }, { name: "Ethiopia", code: "ET" },
    { name: "Fiji", code: "FJ" }, { name: "Finland", code: "FI" }, { name: "France", code: "FR" },
    { name: "Gabon", code: "GA" }, { name: "Gambia", code: "GM" }, { name: "Georgia", code: "GE" },
    { name: "Germany", code: "DE" }, { name: "Ghana", code: "GH" }, { name: "Greece", code: "GR" },
    { name: "Grenada", code: "GD" }, { name: "Guatemala", code: "GT" }, { name: "Guinea", code: "GN" },
    { name: "Guinea-Bissau", code: "GW" }, { name: "Guyana", code: "GY" }, { name: "Haiti", code: "HT" },
    { name: "Holy See", code: "VA" }, { name: "Honduras", code: "HN" }, { name: "Hungary", code: "HU" },
    { name: "Iceland", code: "IS" }, { name: "India", code: "IN" }, { name: "Indonesia", code: "ID" },
    { name: "Iran", code: "IR" }, { name: "Iraq", code: "IQ" }, { name: "Ireland", code: "IE" },
    { name: "Israel", code: "IL" }, { name: "Italy", code: "IT" }, { name: "Jamaica", code: "JM" },
    { name: "Japan", code: "JP" }, { name: "Jordan", code: "JO" }, { name: "Kazakhstan", code: "KZ" },
    { name: "Kenya", code: "KE" }, { name: "Kiribati", code: "KI" }, { name: "Kuwait", code: "KW" },
    { name: "Kyrgyzstan", code: "KG" }, { name: "Laos", code: "LA" }, { name: "Latvia", code: "LV" },
    { name: "Lebanon", code: "LB" }, { name: "Lesotho", code: "LS" }, { name: "Liberia", code: "LR" },
    { name: "Libya", code: "LY" }, { name: "Liechtenstein", code: "LI" }, { name: "Lithuania", code: "LT" },
    { name: "Luxembourg", code: "LU" }, { name: "Madagascar", code: "MG" }, { name: "Malawi", code: "MW" },
    { name: "Malaysia", code: "MY" }, { name: "Maldives", code: "MV" }, { name: "Mali", code: "ML" },
    { name: "Malta", code: "MT" }, { name: "Marshall Islands", code: "MH" }, { name: "Mauritania", code: "MR" },
    { name: "Mauritius", code: "MU" }, { name: "Mexico", code: "MX" }, { name: "Micronesia", code: "FM" },
    { name: "Moldova", code: "MD" }, { name: "Monaco", code: "MC" }, { name: "Mongolia", code: "MN" },
    { name: "Montenegro", code: "ME" }, { name: "Morocco", code: "MA" }, { name: "Mozambique", code: "MZ" },
    { name: "Myanmar (formerly Burma)", code: "MM" }, { name: "Namibia", code: "NA" }, { name: "Nauru", code: "NR" },
    { name: "Nepal", code: "NP" }, { name: "Netherlands", code: "NL" }, { name: "New Zealand", code: "NZ" },
    { name: "Nicaragua", code: "NI" }, { name: "Niger", code: "NE" }, { name: "Nigeria", code: "NG" },
    { name: "North Korea", code: "KP" }, { name: "North Macedonia", code: "MK" }, { name: "Norway", code: "NO" },
    { name: "Oman", code: "OM" }, { name: "Pakistan", code: "PK" }, { name: "Palau", code: "PW" },
    { name: "Palestine State", code: "PS" }, { name: "Panama", code: "PA" }, { name: "Papua New Guinea", code: "PG" },
    { name: "Paraguay", code: "PY" }, { name: "Peru", code: "PE" }, { name: "Philippines", code: "PH" },
    { name: "Poland", code: "PL" }, { name: "Portugal", code: "PT" }, { name: "Qatar", code: "QA" },
    { name: "Romania", code: "RO" }, { name: "Russia", code: "RU" }, { name: "Rwanda", code: "RW" },
    { name: "Saint Kitts and Nevis", code: "KN" }, { name: "Saint Lucia", code: "LC" }, { name: "Saint Vincent and the Grenades", code: "VC" },
    { name: "Samoa", code: "WS" }, { name: "San Marino", code: "SM" }, { name: "Sao Tome and Principe", code: "ST" },
    { name: "Saudi Arabia", code: "SA" }, { name: "Senegal", code: "SN" }, { name: "Serbia", code: "RS" },
    { name: "Seychelles", code: "SC" }, { name: "Sierra Leone", code: "SL" }, { name: "Singapore", code: "SG" },
    { name: "Slovakia", code: "SK" }, { name: "Slovenia", code: "SI" }, { name: "Solomon Islands", code: "SB" },
    { name: "Somalia", code: "SO" }, { name: "South Africa", code: "ZA" }, { name: "South Korea", code: "KR" },
    { name: "South Sudan", code: "SS" }, { name: "Spain", code: "ES" }, { name: "Sri Lanka", code: "LK" },
    { name: "Sudan", code: "SD" }, { name: "Suriname", code: "SR" }, { name: "Sweden", code: "SE" },
    { name: "Switzerland", code: "CH" }, { name: "Syria", code: "SY" }, { name: "Tajikistan", code: "TJ" },
    { name: "Tanzania", code: "TZ" }, { name: "Thailand", code: "TH" }, { name: "Timor-Leste", code: "TL" },
    { name: "Togo", code: "TG" }, { name: "Tonga", code: "TO" }, { name: "Trinidad and Tobago", code: "TT" },
    { name: "Tunisia", code: "TN" }, { name: "Turkey", code: "TR" }, { name: "Turkmenistan", code: "TM" },
    { name: "Tuvalu", code: "TV" }, { name: "Uganda", code: "UG" }, { name: "Ukraine", code: "UA" },
    { name: "United Arab Emirates", code: "AE" }, { name: "United Kingdom", code: "GB" }, { name: "United States", code: "US" },
    { name: "Uruguay", code: "UY" }, { name: "Uzbekistan", code: "UZ" }, { name: "Vanuatu", code: "VU" },
    { name: "Venezuela", code: "VE" }, { name: "Vietnam", code: "VN" }, { name: "Yemen", code: "YE" },
    { name: "Zambia", code: "ZM" }, { name: "Zimbabwe", code: "ZW" }
];

// --- Initialization ---

async function init() {
    // strict login: use sessionStorage so tab close results in logout
    supabaseClient = supabase.createClient(CONFIG.SUPABASE_URL, CONFIG.SUPABASE_ANON_KEY, {
        auth: {
            storage: window.sessionStorage,
            autoRefreshToken: true,
            persistSession: true,
            detectSessionInUrl: true
        }
    });
    
    // Check initial session
    const { data } = await supabaseClient.auth.getSession();
    session = data.session;
    clearTrailingHash();

    let isAdminSession = false;
    if (session) {
        isAdminSession = await enforceAdminSession();
    }

    if (isAdminSession) {
        // Load session start time from storage or set it now
        const savedStart = sessionStorage.getItem('admin_session_start');
        sessionStartTime = savedStart ? parseInt(savedStart) : Date.now();
        if (!savedStart) sessionStorage.setItem('admin_session_start', sessionStartTime);
        startSessionTimer();
    }

    updateUI(isAdminSession);

    // Listen for auth changes
    supabaseClient.auth.onAuthStateChange(async (event, _session) => {
        session = _session;

        if (event === 'SIGNED_IN') {
            const isAdmin = await enforceAdminSession();
            if (!isAdmin) {
                updateUI(false);
                return;
            }

            sessionStartTime = Date.now();
            sessionStorage.setItem('admin_session_start', sessionStartTime);
            startSessionTimer();
        } else if (event === 'SIGNED_OUT') {
            sessionStartTime = null;
            sessionStorage.removeItem('admin_session_start');
            stopSessionTimer();
        }

        updateUI(!!session);
    });

    setupEventListeners();
    renderCategories();
    renderCountries();
}

function startSessionTimer() {
    if (checkInterval) clearInterval(checkInterval);
    checkInterval = setInterval(checkSessionExpiry, CONFIG.CHECK_INTERVAL_MS);
}

function stopSessionTimer() {
    if (checkInterval) clearInterval(checkInterval);
    checkInterval = null;
    hideSessionWarning();
}

function checkSessionExpiry() {
    if (!session || !sessionStartTime) return;

    const now = Date.now();
    const elapsed = now - sessionStartTime;
    const remaining = CONFIG.SESSION_LIMIT_MS - elapsed;

    if (remaining <= 0) {
        alert("Session expired. Logging out now.");
        supabaseClient.auth.signOut();
    } else if (remaining <= CONFIG.WARNING_THRESHOLD_MS) {
        showSessionWarning(remaining);
    } else {
        hideSessionWarning();
    }
}

function showSessionWarning(remainingMs) {
    const modal = document.getElementById('session-warning');
    const countdown = document.getElementById('session-countdown');
    
    modal.classList.remove('hidden');
    warningModalActive = true;

    // Update countdown text
    const minutes = Math.floor(remainingMs / 60000);
    const seconds = Math.floor((remainingMs % 60000) / 1000);
    countdown.textContent = `${minutes}:${seconds.toString().padStart(2, '0')}`;
}

function hideSessionWarning() {
    document.getElementById('session-warning').classList.add('hidden');
    warningModalActive = false;
}

function extendSession() {
    sessionStartTime = Date.now();
    sessionStorage.setItem('admin_session_start', sessionStartTime);
    hideSessionWarning();
}

function updateUI(isAuthenticated) {
    const authOverlay = document.getElementById('auth-overlay');
    const dashboard = document.getElementById('dashboard');
    
    if (isAuthenticated) {
        authOverlay.classList.add('hidden');
        dashboard.classList.remove('hidden');
    } else {
        authOverlay.classList.remove('hidden');
        dashboard.classList.add('hidden');
    }
}

function setupEventListeners() {
    // Auth
    document.getElementById('login-form').addEventListener('submit', handleLogin);
    document.getElementById('google-login').addEventListener('click', handleGoogleLogin);
    document.getElementById('logout-btn').addEventListener('click', () => supabaseClient.auth.signOut());

    // Drafting
    document.getElementById('draft-btn').addEventListener('click', handleDraftGeneration);
    document.getElementById('manual-btn').addEventListener('click', handleManualEntry);
    
    // Word count tracking
    document.getElementById('draft-summary').addEventListener('input', updateWordCount);

    // Publishing
    document.getElementById('publish-btn').addEventListener('click', handlePublish);

    // Country Dropdown
    const countrySearch = document.getElementById('draft-country-search');
    const countryOptions = document.getElementById('country-options');

    countrySearch.addEventListener('focus', () => countryOptions.classList.add('active'));
    countrySearch.addEventListener('input', (e) => {
        document.getElementById('draft-country').value = '';
        filterCountries(e.target.value);
    });
    
    // Close dropdown on click outside
    document.addEventListener('click', (e) => {
        if (!document.getElementById('country-dropdown').contains(e.target)) {
            countryOptions.classList.remove('active');
        }
    });

    // Image Upload
    document.getElementById('upload-trigger').addEventListener('click', () => {
        document.getElementById('image-upload').click();
    });

    document.getElementById('image-upload').addEventListener('change', handleImageUpload);
    document.getElementById('draft-image-url').addEventListener('input', (e) => updateImagePreview(e.target.value));

    // Session Warning
    document.getElementById('extend-session-btn').addEventListener('click', extendSession);
    document.getElementById('expire-logout-btn').addEventListener('click', () => supabaseClient.auth.signOut());

    // SQL Query Explorer
    document.getElementById('run-query-btn').addEventListener('click', handleSqlQuery);
    document.getElementById('clear-results-btn').addEventListener('click', clearQueryResults);
    document.getElementById('download-csv-btn').addEventListener('click', downloadResultsAsCSV);

    // Sidebar Navigation
    document.querySelectorAll('.nav-item').forEach(item => {
        item.addEventListener('click', () => {
            const tabId = item.getAttribute('data-tab');
            switchTab(tabId);
        });
    });

    // Sidebar Toggle
    document.getElementById('sidebar-toggle').addEventListener('click', toggleSidebar);

    // Close Detail Panel
    document.getElementById('close-detail-panel').addEventListener('click', hideRecordDetails);
}

function toggleSidebar() {
    const sidebar = document.getElementById('sidebar');
    sidebar.classList.toggle('collapsed');
}

function switchTab(tabId) {
    // Update Sidebar
    document.querySelectorAll('.nav-item').forEach(item => {
        if (item.getAttribute('data-tab') === tabId) {
            item.classList.add('active');
        } else {
            item.classList.remove('active');
        }
    });

    // Update Content
    document.querySelectorAll('.tab-content').forEach(content => {
        if (content.id === tabId) {
            content.classList.remove('hidden');
        } else {
            content.classList.add('hidden');
        }
    });
}

let lastQueryResults = null;

async function handleSqlQuery() {
    const queryInput = document.getElementById('sql-query');
    const btn = document.getElementById('run-query-btn');
    const errorEl = document.getElementById('query-error');
    const resultsContainer = document.getElementById('query-results-container');
    const loader = btn.querySelector('.loader');
    const btnText = btn.querySelector('.btn-text');
    
    if (!queryInput.value.trim()) return;

    // UI State
    btn.disabled = true;
    loader.classList.remove('hidden');
    btnText.classList.add('hidden');
    errorEl.classList.add('hidden');
    resultsContainer.classList.add('hidden');

    try {
        const response = await fetch(`${CONFIG.API_BASE_URL}/api/admin/query`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${session.access_token}`
            },
            body: JSON.stringify({ query: queryInput.value.trim() })
        });

        const data = await response.json();

        if (!response.ok) {
            throw new Error(data.detail || 'Query failed');
        }

        lastQueryResults = data;
        renderQueryResults(data);
        resultsContainer.classList.remove('hidden');
        
    } catch (err) {
        errorEl.textContent = err.message;
        errorEl.classList.remove('hidden');
    } finally {
        btn.disabled = false;
        loader.classList.add('hidden');
        btnText.classList.remove('hidden');
    }
}

function renderQueryResults(data) {
    const head = document.getElementById('table-head');
    const body = document.getElementById('table-body');
    const badge = document.getElementById('row-count-badge');
    
    head.innerHTML = '';
    body.innerHTML = '';
    badge.textContent = `${data.row_count} rows`;

    if (data.row_count === 0) {
        body.innerHTML = '<tr><td colspan="100%" style="text-align: center; padding: 2rem;">No results found.</td></tr>';
        return;
    }

    // Render Headers
    const headerRow = document.createElement('tr');
    data.columns.forEach(col => {
        const th = document.createElement('th');
        th.textContent = col;
        headerRow.appendChild(th);
    });
    head.appendChild(headerRow);

    // Render Rows
    data.data.forEach((row, index) => {
        const tr = document.createElement('tr');
        tr.onclick = () => showRecordDetails(row, tr);
        
        data.columns.forEach(col => {
            const td = document.createElement('td');
            const val = row[col];
            
            if (val === null) {
                td.innerHTML = '<i style="color: hsla(0,0%,100%,0.2)">null</i>';
            } else if (typeof val === 'object') {
                td.textContent = JSON.stringify(val);
                td.title = td.textContent;
            } else {
                td.textContent = val;
                td.title = val;
            }
            tr.appendChild(td);
        });
        body.appendChild(tr);
    });
}

function showRecordDetails(record, element) {
    const panel = document.getElementById('record-detail-panel');
    const content = document.getElementById('detail-content');
    
    // Highlight selected row
    document.querySelectorAll('#results-table tr').forEach(tr => tr.classList.remove('selected'));
    if (element) element.classList.add('selected');

    content.innerHTML = '';
    
    for (const [key, value] of Object.entries(record)) {
        const item = document.createElement('div');
        item.className = 'detail-item';
        
        let displayValue = value;
        if (value === null) {
            displayValue = '<i>null</i>';
        } else if (Array.isArray(value) && value.length > 20) {
            // Special handling for long arrays (like embeddings)
            const preview = value.slice(0, 5).map(v => typeof v === 'number' ? v.toFixed(4) : v);
            displayValue = `<div class="truncated-array">[${preview.join(', ')}, ... <span class="badge small">${value.length} items total</span>]</div>`;
        } else if (typeof value === 'object') {
            displayValue = `<pre>${JSON.stringify(value, null, 2)}</pre>`;
        } else if (typeof value === 'string' && (value.startsWith('http://') || value.startsWith('https://'))) {
            displayValue = `<a href="${value}" target="_blank" class="accent-link">${value}</a>`;
        } else if (typeof value === 'string' && value.length > 500) {
            // Truncate very long strings
            displayValue = `<div class="truncated-text" title="Click to expand" onclick="this.classList.toggle('expanded')">${value}</div>`;
        }

        item.innerHTML = `
            <div class="detail-label">${key}</div>
            <div class="detail-value">${displayValue}</div>
        `;
        content.appendChild(item);
    }

    panel.classList.remove('hidden');
}

function hideRecordDetails() {
    document.getElementById('record-detail-panel').classList.add('hidden');
    document.querySelectorAll('#results-table tr').forEach(tr => tr.classList.remove('selected'));
}

function clearQueryResults() {
    document.getElementById('sql-query').value = '';
    document.getElementById('query-results-container').classList.add('hidden');
    document.getElementById('query-error').classList.add('hidden');
    lastQueryResults = null;
}

function downloadResultsAsCSV() {
    if (!lastQueryResults || lastQueryResults.data.length === 0) return;

    const cols = lastQueryResults.columns;
    const rows = lastQueryResults.data;

    const csvContent = [
        cols.join(','),
        ...rows.map(row => cols.map(c => {
            const val = row[c];
            if (val === null) return '';
            const str = String(val).replace(/"/g, '""');
            return str.includes(',') || str.includes('\n') || str.includes('"') ? `"${str}"` : str;
        }).join(','))
    ].join('\n');

    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.setAttribute('href', url);
    link.setAttribute('download', `query_results_${Date.now()}.csv`);
    link.style.visibility = 'hidden';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
}

function renderCategories() {
    const container = document.getElementById('category-chips');
    container.innerHTML = '';
    
    VALID_CATEGORIES.forEach(cat => {
        const chip = document.createElement('div');
        chip.className = 'chip';
        chip.textContent = cat.charAt(0).toUpperCase() + cat.slice(1);
        chip.onclick = () => toggleCategory(cat, chip);
        container.appendChild(chip);
    });
}

function renderCountries() {
    const container = document.getElementById('country-options');
    container.innerHTML = '';

    const clearOption = document.createElement('div');
    clearOption.className = 'dropdown-option';
    clearOption.textContent = 'No country';
    clearOption.onclick = () => {
        setCountryByCode(null);
        container.classList.remove('active');
    };
    container.appendChild(clearOption);
    
    COUNTRIES.forEach(country => {
        const option = document.createElement('div');
        option.className = 'dropdown-option';
        option.textContent = `${country.name} (${country.code})`;
        option.onclick = () => selectCountry(country);
        container.appendChild(option);
    });
}

function filterCountries(query) {
    const container = document.getElementById('country-options');
    const options = container.querySelectorAll('.dropdown-option');
    const q = query.toLowerCase();
    
    options.forEach(opt => {
        if (opt.textContent.toLowerCase().includes(q)) {
            opt.style.display = 'block';
        } else {
            opt.style.display = 'none';
        }
    });
    
    container.classList.add('active');
}

function selectCountry(country) {
    document.getElementById('draft-country-search').value = `${country.name} (${country.code})`;
    document.getElementById('draft-country').value = country.code;
    document.getElementById('country-options').classList.remove('active');
}

function setCountryByCode(code) {
    if (!code) {
        document.getElementById('draft-country-search').value = '';
        document.getElementById('draft-country').value = '';
        return;
    }
    const country = COUNTRIES.find(c => c.code === code);
    if (!country) {
        document.getElementById('draft-country-search').value = '';
        document.getElementById('draft-country').value = '';
        return;
    }
    selectCountry(country);
}

function toggleCategory(cat, element) {
    if (selectedCategories.includes(cat)) {
        selectedCategories = selectedCategories.filter(c => c !== cat);
        element.classList.remove('active');
    } else {
        selectedCategories.push(cat);
        element.classList.add('active');
    }
}

function updateWordCount() {
    const text = document.getElementById('draft-summary').value;
    const count = text.trim() ? text.trim().split(/\s+/).length : 0;
    const countEl = document.getElementById('word-count');
    countEl.textContent = count;
    
    if (count < 60 || count > 68) {
        countEl.style.color = 'var(--error-color)';
    } else {
        countEl.style.color = 'var(--success-color)';
    }
}

// --- Action Handlers ---

async function handleLogin(e) {
    e.preventDefault();
    const email = document.getElementById('email').value;
    const password = document.getElementById('password').value;
    const errorEl = document.getElementById('auth-error');
    
    errorEl.textContent = '';
    
    const { error } = await supabaseClient.auth.signInWithPassword({ email, password });
    
    if (error) {
        errorEl.textContent = error.message;
    }
}

async function handleGoogleLogin() {
    const { error } = await supabaseClient.auth.signInWithOAuth({
        provider: 'google',
        options: {
            redirectTo: window.location.origin + window.location.pathname,
            queryParams: {
                prompt: 'select_account'
            }
        }
    });
    
    if (error) {
        document.getElementById('auth-error').textContent = error.message;
    }
}

async function handleDraftGeneration() {
    const urlInput = document.getElementById('news-url');
    const btn = document.getElementById('draft-btn');
    const loader = btn.querySelector('.loader');
    const btnText = btn.querySelector('.btn-text');
    
    if (!urlInput.value) return;

    // UI Feedback
    loader.classList.remove('hidden');
    btnText.classList.add('hidden');
    btn.disabled = true;

    try {
        const response = await fetch(`${CONFIG.API_BASE_URL}/api/admin/news/draft`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${session.access_token}`
            },
            body: JSON.stringify({ url: urlInput.value })
        });

        if (!response.ok) {
            const err = await response.json();
            throw new Error(err.detail || 'Draft generation failed');
        }

        const data = await response.json();
        populateEditor(data);
        document.getElementById('editor-section').classList.remove('hidden');
        
    } catch (err) {
        alert('Error: ' + err.message);
    } finally {
        loader.classList.add('hidden');
        btnText.classList.remove('hidden');
        btn.disabled = false;
    }
}

function handleManualEntry() {
    clearEditor();
    document.getElementById('editor-section').classList.remove('hidden');
    document.getElementById('news-url').value = '';
}

function clearEditor() {
    document.getElementById('draft-title').value = '';
    document.getElementById('draft-summary').value = '';
    document.getElementById('draft-source').value = '';
    document.getElementById('draft-subcategory').value = '';
    setCountryByCode(null);
    document.getElementById('draft-paywall').checked = false;
    document.getElementById('draft-image-url').value = '';
    document.getElementById('image-preview').innerHTML = '<span>Manual Preview</span>';
    
    selectedCategories = [];
    const chips = document.querySelectorAll('.chip');
    chips.forEach(chip => chip.classList.remove('active'));
    
    updateWordCount();
}

function populateEditor(data) {
    document.getElementById('draft-title').value = data.title;
    document.getElementById('draft-summary').value = data.summary;
    document.getElementById('draft-source').value = data.source_name;
    document.getElementById('draft-subcategory').value = data.subcategory;
    setCountryByCode(data.country_code || null);
    document.getElementById('draft-paywall').checked = data.is_paywalled || false;
    document.getElementById('draft-image-url').value = data.image_url || '';
    
    // Set categories
    selectedCategories = data.categories;
    const chips = document.querySelectorAll('.chip');
    chips.forEach(chip => {
        if (selectedCategories.includes(chip.textContent.toLowerCase())) {
            chip.classList.add('active');
        } else {
            chip.classList.remove('active');
        }
    });

    // Image preview
    updateImagePreview(data.image_url);
    updateWordCount();
}

function updateImagePreview(url) {
    const previewContainer = document.getElementById('image-preview');
    if (url) {
        previewContainer.innerHTML = `<img src="${url}" alt="Preview">`;
    } else {
        previewContainer.innerHTML = '<span>No Image Detected</span>';
    }
}

async function handleImageUpload(e) {
    const file = e.target.files[0];
    if (!file) return;

    const btn = document.getElementById('upload-trigger');
    const originalText = btn.textContent;
    btn.textContent = 'Uploading...';
    btn.disabled = true;

    try {
        const fileExt = file.name.split('.').pop();
        const fileName = `${Math.random().toString(36).substring(2)}_${Date.now()}.${fileExt}`;
        const filePath = `manual-uploads/${fileName}`;

        const { data, error } = await supabaseClient.storage
            .from('article-images')
            .upload(filePath, file);

        if (error) throw error;

        const { data: { publicUrl } } = supabaseClient.storage
            .from('article-images')
            .getPublicUrl(filePath);

        document.getElementById('draft-image-url').value = publicUrl;
        updateImagePreview(publicUrl);
        
    } catch (err) {
        console.error('Upload error:', err);
        alert('Upload failed: ' + err.message);
    } finally {
        btn.textContent = originalText;
        btn.disabled = false;
    }
}

async function handlePublish() {
    const btn = document.getElementById('publish-btn');
    const errorEl = document.getElementById('publish-error');
    
    const articleData = {
        title: document.getElementById('draft-title').value,
        summary: document.getElementById('draft-summary').value,
        categories: selectedCategories,
        subcategory: document.getElementById('draft-subcategory').value,
        source_name: document.getElementById('draft-source').value,
        original_url: document.getElementById('news-url').value || 'https://manual.push/' + Date.now(),
        image_url: document.getElementById('draft-image-url').value || null,
        country_code: document.getElementById('draft-country').value || null,
        is_paywalled: document.getElementById('draft-paywall').checked
    };

    if (articleData.categories.length === 0) {
        errorEl.textContent = 'Please select at least one category.';
        return;
    }

    btn.disabled = true;
    btn.querySelector('.loader').classList.remove('hidden');
    btn.querySelector('.btn-text').classList.add('hidden');
    errorEl.textContent = '';

    try {
        const response = await fetch(`${CONFIG.API_BASE_URL}/api/admin/news/publish`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${session.access_token}`
            },
            body: JSON.stringify(articleData)
        });

        if (!response.ok) {
            const err = await response.json();
            throw new Error(err.detail || 'Publish failed');
        }

        showToast();
        // Reset
        document.getElementById('news-url').value = '';
        document.getElementById('editor-section').classList.add('hidden');
        
    } catch (err) {
        errorEl.textContent = err.message;
    } finally {
        btn.disabled = false;
        btn.querySelector('.loader').classList.add('hidden');
        btn.querySelector('.btn-text').classList.remove('hidden');
    }
}

function showToast() {
    const toast = document.getElementById('toast');
    toast.classList.remove('hidden');
    setTimeout(() => toast.classList.add('hidden'), 4000);
}

// Start the app
init();
