# Google Maps Location Feature - Setup Guide

## Overview
A new "Get Your Location" button has been added to the index page hero section that integrates with Google Maps API to retrieve and display user location with map visualization.

## Files Modified/Created

### 1. **index.html** (Modified)
   - **Added Button**: New "Get Your Location" button in the hero-ctas section (next to "Explore Services")
   - **Updated CSP**: Content Security Policy updated to allow Google Maps API
   - **Added Script Reference**: Link to Google Maps API and new location-service.js file

### 2. **js/location-service.js** (Created)
   - Complete location retrieval and display functionality
   - Includes error handling for different geolocation scenarios
   - Modal popup with map visualization
   - Address reverse geocoding
   - Copy coordinates feature

## Setup Instructions

### Step 1: Get Google Maps API Key
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable these APIs:
   - Maps JavaScript API
   - Geolocation API
   - Geocoding API
4. Create an API key (Credentials → Create Credentials → API Key)
5. Restrict the key to your domain for security

### Step 2: Add API Key to index.html
Replace `AIzaSyBPsuaow_h6RYW6j4Nvl9BXroIiRLq1JtM` in the Google Maps script tag (around line 2979) with your actual API key:

```html
<script src="https://maps.googleapis.com/maps/api/js?key=YOUR_API_KEY&libraries=places"></script>
```

Example:
```html
<script src="https://maps.googleapis.com/maps/api/js?key=AIzaSyDxxxxxxxxxxxxxxxxxxx&libraries=places"></script>
```

### Step 3: Test the Feature
1. Open index.html in browser
2. Look for "Get Your Location" button in hero section
3. Click the button
4. Allow location access when prompted
5. Map modal should appear with:
   - Interactive map showing your location
   - Latitude & Longitude coordinates
   - Location accuracy (in meters)
   - Full address (via geocoding)
   - Copy coordinates button

## Features

✅ **Geolocation Detection** - Uses browser's geolocation API
✅ **Map Visualization** - Shows location on Google Map
✅ **Reverse Geocoding** - Converts coordinates to readable address
✅ **Error Handling** - Graceful handling of permission denied, timeout, etc.
✅ **Mobile Responsive** - Works on desktop and mobile devices
✅ **Copy to Clipboard** - Easy sharing of coordinates
✅ **Loading States** - Visual feedback during location retrieval
✅ **Accessibility** - Clean modal with proper close button

## User Interactions

1. **Click Button**: User clicks "Get Your Location" button
2. **Permission Prompt**: Browser asks for location permission
3. **Loading State**: Button shows loading animation while fetching
4. **Modal Opens**: Location details displayed in modal popup
5. **View/Copy**: User can view location on map and copy coordinates

## Error Handling

The feature handles:
- ❌ Permission denied by user
- ❌ Location unavailable
- ❌ Request timeout
- ❌ Unsupported browsers
- ❌ Geocoding failures (shows coordinates-only mode)

## Browser Support

- ✅ Chrome/Chromium
- ✅ Firefox
- ✅ Safari
- ✅ Edge
- ✅ Mobile browsers (iOS Safari, Chrome Mobile)

**Note**: Geolocation requires HTTPS in production (works on localhost for development)

## Security Notes

- API key should be restricted to your domain
- Consider using Browser Restrictions in Google Cloud Console
- Never commit API key to public repositories
- Use environment variables in production if needed

## Styling

The feature uses:
- CSS Grid and Flexbox for layout
- Smooth animations (fade-in, slide-up)
- Accent colors from ACCESCO theme (purple gradient)
- Mobile-first responsive design
- Dark overlay modal (consistent with site design)

## API Costs

Google Maps API charges per request. Monitor usage in Google Cloud Console:
- Maps JavaScript API: $7 per 1,000 loads (Maps & Places)
- Geolocation API: Free (browser-based)
- Geocoding API: $5-7 per 1,000 requests

## Troubleshooting

### "Geolocation is not supported"
- User's browser doesn't support Geolocation API
- Ensure user is on HTTPS (required in production)

### Map not showing
- Verify API key is correct and has Maps JavaScript API enabled
- Check API key restrictions (domain, IP)
- Check CSP headers in index.html

### Address not loading
- Geocoding might be failing due to API key restrictions
- Ensure Geocoding API is enabled in Google Cloud Console

### Button disabled after click
- Browser might be blocking location access
- Check browser settings → Privacy & Security → Location

## Future Enhancements

- Add multiple location search
- Save location history
- Share location with other users
- Integrate with services (delivery, pickup locations)
- Add location-based service recommendations
