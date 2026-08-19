// Resalta en el sidebar la seccion visible mientras se hace scroll.

const links = document.querySelectorAll(".sidebar-link");
const sections = document.querySelectorAll("main.content > section[id]");

const linkFor = (id) => document.querySelector(`.sidebar-link[href="#${id}"]`);

const observer = new IntersectionObserver(
  (entries) => {
    entries.forEach((entry) => {
      const link = linkFor(entry.target.id);
      if (!link) return;
      if (entry.isIntersecting) {
        links.forEach((l) => l.classList.remove("is-active"));
        link.classList.add("is-active");
      }
    });
  },
  { rootMargin: "-40% 0px -50% 0px" }
);

sections.forEach((section) => observer.observe(section));
