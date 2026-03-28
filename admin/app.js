// admin/app.js

const CONFIG = {
    // Replace with your production FastAPI URL if different
    API_BASE_URL: window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1' 
        ? 'http://localhost:8000' 
        : 'https://perinephric-dora-motionlessly.ngrok-free.dev', // Default fallback from dev context
    SUPABASE_URL: 'https://trfqhobnkgtfccrdsexa.supabase.co',
    SUPABASE_ANON_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRyZnFob2Jua2d0ZmNjcmRzZXhhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIyODI1NzMsImV4cCI6MjA4Nzg1ODU3M30.CkbozQuTUm5v9X_eQoVdceI41QVXau9pivfqLDJOjfk'
};

const VALID_CATEGORIES = ["politics", "tech", "science", "business", "sports", "entertainment", "health", "world", "environment"];

let supabase;
let session = null;
let selectedCategories = [];

// --- Initialization ---

async function init() {
    supabase = supabase.createClient(CONFIG.SUPABASE_URL, CONFIG.SUPABASE_ANON_KEY);
    
    // Check initial session
    const { data } = await supabase.auth.getSession();
    session = data.session;
    updateUI(!!session);

    // Listen for auth changes
    supabase.auth.onAuthStateChange((_event, _session) => {
        session = _session;
        updateUI(!!session);
    });

    setupEventListeners();
    renderCategories();
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
    document.getElementById('logout-btn').addEventListener('click', () => supabase.auth.signOut());

    // Drafting
    document.getElementById('draft-btn').addEventListener('click', handleDraftGeneration);
    document.getElementById('manual-btn').addEventListener('click', handleManualEntry);
    
    // Word count tracking
    document.getElementById('draft-summary').addEventListener('input', updateWordCount);

    // Publishing
    document.getElementById('publish-btn').addEventListener('click', handlePublish);
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
    
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    
    if (error) {
        errorEl.textContent = error.message;
    }
}

async function handleGoogleLogin() {
    const { error } = await supabase.auth.signInWithOAuth({
        provider: 'google',
        options: {
            redirectTo: window.location.origin + window.location.pathname
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
    document.getElementById('draft-country').value = 'US';
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
    document.getElementById('draft-country').value = data.country_code || 'US';
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
        country_code: document.getElementById('draft-country').value || 'US',
        is_paywalled: document.getElementById('draft-paywall').checked
    };

    if (articleData.categories.length === 0) {
        errorEl.textContent = 'Please select at least one category.';
        return;
    }

    btn.disabled = true;
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
    }
}

function showToast() {
    const toast = document.getElementById('toast');
    toast.classList.remove('hidden');
    setTimeout(() => toast.classList.add('hidden'), 4000);
}

// Start the app
init();
