/**
 * Supabase client configuration and initialization.
 * Update these credentials with your actual Supabase project credentials.
 */

// Replace these placeholders with your actual Supabase Project URL and Anon Key
const SUPABASE_URL = "https://your-supabase-project.supabase.co"; 
const SUPABASE_ANON_KEY = "your-supabase-anon-key";

// Initialize Supabase Client
let supabase = null;

if (SUPABASE_URL === "https://your-supabase-project.supabase.co" || SUPABASE_ANON_KEY === "your-supabase-anon-key") {
  console.warn(
    "Supabase configuration is using placeholder values. Please update SUPABASE_URL and SUPABASE_ANON_KEY in 'js/supabase-config.js'."
  );
  // Try to load from localStorage for quick testing if provided
  const savedUrl = localStorage.getItem("KGF_SUPABASE_URL");
  const savedKey = localStorage.getItem("KGF_SUPABASE_ANON_KEY");
  if (savedUrl && savedKey) {
    supabase = window.supabase.createClient(savedUrl, savedKey);
    console.log("Initialized Supabase client using credentials from localStorage.");
  }
} else {
  try {
    supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
    console.log("Supabase client initialized successfully.");
  } catch (error) {
    console.error("Error initializing Supabase client:", error);
  }
}

// Make configuration globally accessible
window.KGF_SUPABASE_URL = SUPABASE_URL;
window.KGF_SUPABASE_ANON_KEY = SUPABASE_ANON_KEY;
window.supabaseClient = supabase;
window.isSupabaseConfigured = function() {
  return supabase !== null && SUPABASE_URL !== "https://your-supabase-project.supabase.co";
};
