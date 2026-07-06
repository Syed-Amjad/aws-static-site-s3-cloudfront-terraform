/* =========================================================
   CloudHost — main.js
   Small, dependency-free progressive enhancement.
   ========================================================= */
(function () {
  "use strict";

  // --- Mobile navigation toggle ---
  var toggle = document.querySelector(".nav__toggle");
  var links = document.getElementById("nav-links");

  if (toggle && links) {
    toggle.addEventListener("click", function () {
      var open = links.classList.toggle("open");
      toggle.setAttribute("aria-expanded", String(open));
    });

    // Close the menu after choosing a link (mobile).
    links.addEventListener("click", function (e) {
      if (e.target.tagName === "A") {
        links.classList.remove("open");
        toggle.setAttribute("aria-expanded", "false");
      }
    });
  }

  // --- Dynamic footer year ---
  var year = document.getElementById("year");
  if (year) {
    year.textContent = String(new Date().getFullYear());
  }

  // --- Lightweight "build id" so each deploy is visibly distinct ---
  // Useful to confirm a CloudFront invalidation actually served new content.
  var build = document.getElementById("build-id");
  if (build) {
    build.textContent = new Date().toISOString().slice(0, 10).replace(/-/g, "");
  }
})();
