/**
 * KGF Trust - Common Shared JavaScript
 * Governs layout initialization, dark/light theme toggle, mobile navigation, scroll animations,
 * and Supabase auth state monitoring for the header actions.
 */

document.addEventListener("DOMContentLoaded", () => {
  initTheme();
  initMobileNav();
  initScrollAnimations();
  initHeaderAuth();
  
  // Initialize Lucide icons if available
  if (typeof lucide !== "undefined") {
    lucide.createIcons();
  }
});

/* --- THEME CONTROLLER --- */
function initTheme() {
  const themeToggleBtns = document.querySelectorAll(".theme-toggle-btn");
  const savedTheme = localStorage.getItem("kgf-theme") || "dark";
  
  document.documentElement.setAttribute("data-theme", savedTheme);
  updateThemeIcons(savedTheme);
  
  themeToggleBtns.forEach(btn => {
    btn.addEventListener("click", () => {
      const currentTheme = document.documentElement.getAttribute("data-theme");
      const newTheme = currentTheme === "light" ? "dark" : "light";
      
      document.documentElement.setAttribute("data-theme", newTheme);
      localStorage.setItem("kgf-theme", newTheme);
      updateThemeIcons(newTheme);
    });
  });
}

function updateThemeIcons(theme) {
  const themeToggleBtns = document.querySelectorAll(".theme-toggle-btn");
  themeToggleBtns.forEach(btn => {
    if (theme === "light") {
      btn.innerHTML = `<i data-lucide="moon"></i>`;
    } else {
      btn.innerHTML = `<i data-lucide="sun"></i>`;
    }
  });
  if (typeof lucide !== "undefined") {
    lucide.createIcons();
  }
}

/* --- MOBILE NAVIGATION --- */
function initMobileNav() {
  const hamburger = document.querySelector(".hamburger");
  const navMenu = document.querySelector(".nav-menu");
  
  if (hamburger && navMenu) {
    hamburger.addEventListener("click", () => {
      hamburger.classList.toggle("active");
      navMenu.classList.toggle("active");
      
      // Animate hamburger lines
      const spans = hamburger.querySelectorAll("span");
      if (hamburger.classList.contains("active")) {
        spans[0].style.transform = "rotate(45deg) translate(5px, 6px)";
        spans[1].style.opacity = "0";
        spans[2].style.transform = "rotate(-45deg) translate(5px, -6px)";
      } else {
        spans[0].style.transform = "none";
        spans[1].style.opacity = "1";
        spans[2].style.transform = "none";
      }
    });

    // Close menu when a link is clicked
    document.querySelectorAll(".nav-link").forEach(link => {
      link.addEventListener("click", () => {
        hamburger.classList.remove("active");
        navMenu.classList.remove("active");
        hamburger.querySelectorAll("span").forEach(s => s.style.transform = "none");
        hamburger.querySelectorAll("span")[1].style.opacity = "1";
      });
    });
  }

  // Header scroll class
  const header = document.querySelector("header");
  if (header) {
    window.addEventListener("scroll", () => {
      if (window.scrollY > 50) {
        header.classList.add("scrolled");
      } else {
        header.classList.remove("scrolled");
      }
    });
  }
}

/* --- SCROLL ANIMATIONS --- */
function initScrollAnimations() {
  const reveals = document.querySelectorAll(".reveal");
  
  const revealOnScroll = () => {
    reveals.forEach(el => {
      const windowHeight = window.innerHeight;
      const elementTop = el.getBoundingClientRect().top;
      const elementVisible = 150;
      
      if (elementTop < windowHeight - elementVisible) {
        el.classList.add("active");
      }
    });
  };
  
  window.addEventListener("scroll", revealOnScroll);
  revealOnScroll(); // Trigger once on load
}

/* --- DYNAMIC HEADER AUTH BUTTONS --- */
async function initHeaderAuth() {
  const authContainer = document.getElementById("header-auth-actions");
  if (!authContainer) return;

  // Check if Supabase client is available and initialized
  if (typeof supabaseClient !== "undefined" && window.isSupabaseConfigured()) {
    try {
      const { data: { session } } = await window.supabaseClient.auth.getSession();
      
      if (session && session.user) {
        // Fetch user role
        const { data: profile } = await window.supabaseClient
          .from('users')
          .select('role')
          .eq('id', session.user.id)
          .single();

        const isAdmin = profile && profile.role === 'admin';
        
        authContainer.innerHTML = `
          ${isAdmin ? `<a href="admin.html" class="btn btn-outline btn-sm"><i data-lucide="shield"></i> Admin</a>` : ''}
          <a href="dashboard.html" class="btn btn-outline btn-sm"><i data-lucide="user"></i> Dashboard</a>
          <button onclick="handleLogout()" class="btn btn-primary btn-sm"><i data-lucide="log-out"></i> Logout</button>
        `;
      } else {
        authContainer.innerHTML = `
          <a href="login.html" class="btn btn-primary btn-sm"><i data-lucide="log-in"></i> Login</a>
        `;
      }
    } catch (e) {
      console.error("Error setting up header auth actions:", e);
      authContainer.innerHTML = `<a href="login.html" class="btn btn-primary btn-sm">Login</a>`;
    }
  } else {
    // Supabase not configured yet - show standard Login link
    authContainer.innerHTML = `
      <a href="login.html" class="btn btn-primary btn-sm"><i data-lucide="log-in"></i> Login</a>
    `;
  }
  
  if (typeof lucide !== "undefined") {
    lucide.createIcons();
  }
}

/* --- LOGOUT HANDLER --- */
async function handleLogout() {
  if (typeof supabaseClient !== "undefined" && window.isSupabaseConfigured()) {
    try {
      await window.supabaseClient.auth.signOut();
      localStorage.removeItem("kgf_session");
      window.location.href = "login.html";
    } catch (error) {
      alert("Error logging out: " + error.message);
    }
  } else {
    alert("Supabase is not configured.");
  }
}

/* --- GLOBAL NOTIFICATION SYSTEM --- */
window.showToast = function(message, type = "success") {
  // Remove existing toast if any
  const existingToast = document.querySelector(".kgf-toast");
  if (existingToast) existingToast.remove();
  
  const toast = document.createElement("div");
  toast.className = `kgf-toast card glass-card reveal active`;
  
  let icon = "check-circle";
  let borderCol = "var(--success)";
  if (type === "error") {
    icon = "alert-circle";
    borderCol = "var(--error)";
  } else if (type === "warning") {
    icon = "alert-triangle";
    borderCol = "var(--warning)";
  }
  
  toast.style.position = "fixed";
  toast.style.bottom = "2rem";
  toast.style.right = "2rem";
  toast.style.zIndex = "3000";
  toast.style.padding = "1rem 1.5rem";
  toast.style.borderLeft = `4px solid ${borderCol}`;
  toast.style.display = "flex";
  toast.style.alignItems = "center";
  toast.style.gap = "0.75rem";
  toast.style.minWidth = "280px";
  toast.style.maxWidth = "400px";
  
  toast.innerHTML = `
    <i data-lucide="${icon}" style="color: ${borderCol}; flex-shrink: 0;"></i>
    <div style="font-size: 0.9rem; font-weight: 500;">${message}</div>
  `;
  
  document.body.appendChild(toast);
  lucide.createIcons();
  
  setTimeout(() => {
    toast.style.opacity = "0";
    toast.style.transform = "translateY(20px)";
    toast.style.transition = "all 0.5s ease";
    setTimeout(() => toast.remove(), 500);
  }, 4000);
};

/* --- GENERAL HELPER: GENERATE UNIQUE ID --- */
window.generateUniqueMemberID = function() {
  const year = new Date().getFullYear();
  const rand = Math.floor(1000 + Math.random() * 9000);
  return `KGF-MEM-${year}-${rand}`;
};
