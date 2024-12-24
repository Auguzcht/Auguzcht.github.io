document.addEventListener("DOMContentLoaded", () => {
    const loader = document.getElementById("loader");
    const content = document.querySelector(".content");
    const text = document.querySelector("svg text");

    // Listen for the end of the animation
    text.addEventListener("animationend", () => {
        loader.classList.add("hidden"); // Hide the loader
        content.classList.add("loaded"); // Show the main content
    });
});
