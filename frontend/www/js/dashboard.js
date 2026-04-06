(() => {
    const setActiveMenu = (activeLink) => {
        document.querySelectorAll(".menu-link").forEach((link) => {
            link.classList.toggle("active", link === activeLink);
        });
    };

    const menuLinks = [...document.querySelectorAll('.menu-link[href^="#"]')];
    menuLinks.forEach((link) => {
        link.addEventListener("click", (event) => {
            const targetId = link.getAttribute("href");
            const target = targetId ? document.querySelector(targetId) : null;
            if (!target) {
                return;
            }
            event.preventDefault();
            setActiveMenu(link);
            target.scrollIntoView({ behavior: "smooth", block: "start" });
            history.replaceState(null, "", targetId);
        });
    });

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
        const allValues = [...cashflow, ...spend].filter((value) => Number.isFinite(value));
        const minValue = Math.min(...allValues);
        const maxValue = Math.max(...allValues);
        const padding = Math.max((maxValue - minValue) * 0.2, 250);
        const yMin = Math.max(0, Math.floor((minValue - padding) / 50) * 50);
        const yMax = Math.ceil((maxValue + padding) / 50) * 50;

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
                        fill: false,
                        pointRadius: 3
                    },
                    {
                        label: "Spending",
                        data: spend,
                        borderColor: "#cc8b28",
                        backgroundColor: "rgba(204, 139, 40, 0.12)",
                        borderWidth: 2.2,
                        tension: 0.3,
                        fill: false,
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
                        min: yMin,
                        max: yMax,
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

    const transferButton = document.getElementById("transferReviewBtn");
    const transferFeedback = document.getElementById("transferFeedback");
    if (transferButton && transferFeedback) {
        transferButton.addEventListener("click", () => {
            const fromAccount = document.getElementById("fromAccount");
            const toAccount = document.getElementById("toAccount");
            const amountField = document.getElementById("transferAmount");
            const amount = Number.parseFloat(amountField?.value || "");

            if (!Number.isFinite(amount) || amount <= 0) {
                transferFeedback.className = "transfer-feedback error";
                transferFeedback.textContent = "Enter a valid transfer amount greater than 0.";
                return;
            }

            const fromText = fromAccount?.value || "source account";
            const toText = toAccount?.value || "destination account";
            transferFeedback.className = "transfer-feedback ok";
            transferFeedback.textContent = `Ready to transfer $${amount.toFixed(2)} from ${fromText} to ${toText}.`;
        });
    }
})();
