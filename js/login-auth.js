// OAuth Authentication for Login Page
import { createClient } from "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm";

const supabaseUrl = "https://nfdrnbikwzfmijrqmoqt.supabase.co";
const supabaseKey = "sb_publishable_dVvOYAqamp2BGoI8zvyB5g_NfCSkQ6b";
const supabase = createClient(supabaseUrl, supabaseKey);

const googleAuth = {
    async signIn() {
        try {
            const { data, error } = await supabase.auth.signInWithOAuth({
                provider: 'google',
                options: {
                    redirectTo: window.location.origin,
                    skipBrowserRedirect: false
                }
            });
            
            if (error) throw error;
            console.log('Google sign-in initiated');
        } catch (error) {
            console.error('Sign-in error:', error.message);
            alert('Failed to sign in. Please try again.');
        }
    },
    
    async checkSession() {
        try {
            const { data: { session } } = await supabase.auth.getSession();
            
            if (session) {
                console.log('User authenticated:', session.user.email);
                window.location.href = 'https://accesco.co.in/app';
                return true;
            }
            return false;
        } catch (error) {
            console.error('Session check error:', error.message);
            return false;
        }
    },
    
    async handleBackButton() {
        const backButton = document.getElementById('backBtn');
        if (backButton) {
            backButton.addEventListener('click', () => {
                window.history.back();
            });
        }
    }
};

// Initialize on page load
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', async () => {
        await googleAuth.checkSession();
        googleAuth.handleBackButton();
    });
} else {
    (async () => {
        await googleAuth.checkSession();
        googleAuth.handleBackButton();
    })();
}

// Export for use in onclick handlers
window.signInWithGoogle = () => googleAuth.signIn();
