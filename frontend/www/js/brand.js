(() => {
    const dateTargets = document.querySelectorAll("[data-brand-date]");
    if (dateTargets.length > 0) {
        const now = new Date();
        const formatted = new Intl.DateTimeFormat("en-CA", {
            weekday: "short",
            year: "numeric",
            month: "short",
            day: "2-digit"
        }).format(now);

        dateTargets.forEach((target) => {
            target.textContent = formatted;
        });
    }

    const hourTargets = document.querySelectorAll("[data-brand-time]");
    if (hourTargets.length > 0) {
        const renderTime = () => {
            const now = new Date();
            const formatted = now.toLocaleTimeString("en-CA", {
                hour: "2-digit",
                minute: "2-digit"
            });
            hourTargets.forEach((target) => {
                target.textContent = formatted;
            });
        };

        renderTime();
        setInterval(renderTime, 30000);
    }
})();

