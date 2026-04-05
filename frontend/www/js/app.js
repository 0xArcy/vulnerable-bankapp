// Modern Bank - Frontend JavaScript
// Client-side validation and interactions

document.addEventListener('DOMContentLoaded', function() {
    // Form validation
    const forms = document.querySelectorAll('.needs-validation');
    Array.from(forms).forEach(form => {
        form.addEventListener('submit', event => {
            if (!form.checkValidity()) {
                event.preventDefault();
                event.stopPropagation();
            }
            form.classList.add('was-validated');
        }, false);
    });

    // File upload preview (client-side only - VULNERABLE)
    const avatarInput = document.getElementById('avatar');
    if (avatarInput) {
        avatarInput.addEventListener('change', function(e) {
            const file = this.files[0];
            if (file) {
                // Client-side validation only! (VULNERABLE)
                const allowedTypes = ['image/jpeg', 'image/png', 'image/gif'];
                const maxSize = 50 * 1024 * 1024;

                if (!allowedTypes.includes(file.type)) {
                    alert('Please upload a valid image file (JPG, PNG, GIF)');
                    this.value = '';
                    return;
                }

                if (file.size > maxSize) {
                    alert('File size exceeds 50MB limit');
                    this.value = '';
                    return;
                }

                // Show preview
                const reader = new FileReader();
                reader.onload = function(evt) {
                    const preview = document.querySelector('img[alt="Avatar"]');
                    if (preview) {
                        preview.src = evt.target.result;
                    }
                };
                reader.readAsDataURL(file);
            }
        });
    }
});
