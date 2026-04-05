(() => {
    const animateCurrency = (element) => {
        const target = Number.parseFloat(element.dataset.value || "0");
        const format = element.dataset.format || "currency";
        if (!Number.isFinite(target)) {
            return;
        }

        const start = 0;
        const duration = 900;
        const startTime = performance.now();

        const step = (now) => {
            const elapsed = now - startTime;
            const progress = Math.min(elapsed / duration, 1);
            const eased = 1 - Math.pow(1 - progress, 3);
            const current = start + (target - start) * eased;

            if (format === "number") {
                element.textContent = Math.round(current).toLocaleString();
            } else if (Math.abs(target) >= 1000 && Math.abs(target) < 1000000) {
                element.textContent = `$${current.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
            } else if (Math.abs(target) >= 1000000) {
                element.textContent = `$${current.toLocaleString(undefined, { maximumFractionDigits: 0 })}`;
            } else if (Number.isInteger(target)) {
                element.textContent = `$${Math.round(current).toLocaleString()}`;
            } else {
                element.textContent = `$${current.toFixed(2)}`;
            }

            if (progress < 1) {
                requestAnimationFrame(step);
            }
        };

        requestAnimationFrame(step);
    };

    document.querySelectorAll(".count").forEach(animateCurrency);

    const chartCanvas = document.getElementById("cashflowChart");
    if (chartCanvas && window.Chart && window.bankData) {
        const { months, cashflow, spend } = window.bankData;
        new window.Chart(chartCanvas, {
            type: "line",
            data: {
                labels: months,
                datasets: [
                    {
                        label: "Income",
                        data: cashflow,
                        borderColor: "#0f70d8",
                        backgroundColor: "rgba(15, 112, 216, 0.15)",
                        borderWidth: 2.6,
                        tension: 0.35,
                        fill: true,
                        pointRadius: 3
                    },
                    {
                        label: "Spending",
                        data: spend,
                        borderColor: "#cc8b28",
                        backgroundColor: "rgba(204, 139, 40, 0.12)",
                        borderWidth: 2.2,
                        tension: 0.3,
                        fill: true,
                        pointRadius: 2.8
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        labels: {
                            usePointStyle: true,
                            boxWidth: 8,
                            boxHeight: 8
                        }
                    }
                },
                scales: {
                    y: {
                        ticks: {
                            callback: (value) => `$${value}`
                        },
                        grid: {
                            color: "#e6edf7"
                        }
                    },
                    x: {
                        grid: {
                            display: false
                        }
                    }
                }
            }
        });
    }

    const avatarInput = document.getElementById("avatar");
    const avatarPreview = document.getElementById("avatarPreview");
    if (avatarInput && avatarPreview) {
        avatarInput.addEventListener("change", (event) => {
            const file = event.target.files?.[0];
            if (!file) {
                return;
            }
            const previewUrl = URL.createObjectURL(file);
            avatarPreview.src = previewUrl;
        });
    }
})();
