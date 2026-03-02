/**
 * Location Service using Google Maps API
 * Retrieves user location and displays it on a map modal
 */

// Get user location and display on map
function getUserLocation() {
  const btn = document.getElementById('getLocationBtn');

  if (!navigator.geolocation) {
    alert('Geolocation is not supported by your browser.');
    return;
  }

  // Show loading state
  btn.disabled = true;
  btn.innerHTML = '<i class="ri-loader-4-line" style="animation: spin 1s linear infinite;"></i> Getting Location...';

  navigator.geolocation.getCurrentPosition(
    (position) => {
      const lat = position.coords.latitude;
      const lng = position.coords.longitude;
      const accuracy = position.coords.accuracy;

      // Reset button
      btn.disabled = false;
      btn.innerHTML = '<i class="ri-map-pin-line"></i> Get Your Location';

      // Display location details
      displayLocationModal(lat, lng, accuracy);
    },
    (error) => {
      // Reset button
      btn.disabled = false;
      btn.innerHTML = '<i class="ri-map-pin-line"></i> Get Your Location';

      // Handle errors
      handleLocationError(error);
    },
    {
      enableHighAccuracy: true,
      timeout: 10000,
      maximumAge: 0
    }
  );
}

// Handle geolocation errors
function handleLocationError(error) {
  let errorMsg = '';

  switch (error.code) {
    case error.PERMISSION_DENIED:
      errorMsg = 'Location access denied. Please enable location permission in your browser settings.';
      break;
    case error.POSITION_UNAVAILABLE:
      errorMsg = 'Location information is unavailable.';
      break;
    case error.TIMEOUT:
      errorMsg = 'Location request timed out. Please try again.';
      break;
    default:
      errorMsg = 'An error occurred while retrieving your location.';
  }

  alert(errorMsg);
  console.error('Geolocation error:', error);
}

// Display location modal with map
function displayLocationModal(lat, lng, accuracy) {
  // Check if modal already exists
  let modal = document.getElementById('locationModal');
  if (modal) {
    modal.remove();
  }

  // Create modal HTML
  const modalHTML = `
    <div id="locationModal" class="location-modal-overlay">
      <div class="location-modal">
        <div class="location-modal-header">
          <h3>Your Location</h3>
          <button class="close-modal-btn" onclick="closeLocationModal()">&times;</button>
        </div>
        <div class="location-modal-content">
          <div id="locationMap" class="location-map" style="background: #f0f0f0; display: flex; align-items: center; justify-content: center;"><span style="color: #999;">Loading map...</span></div>
          <div class="location-info">
            <div class="info-item">
              <span class="info-label">Latitude:</span>
              <span class="info-value">${lat.toFixed(6)}</span>
            </div>
            <div class="info-item">
              <span class="info-label">Longitude:</span>
              <span class="info-value">${lng.toFixed(6)}</span>
            </div>
            <div class="info-item">
              <span class="info-label">Accuracy:</span>
              <span class="info-value">±${Math.round(accuracy)} m</span>
            </div>
            <div class="info-item full-width" id="addressInfo" style="color: #666;">
              <span class="info-label">Address:</span>
              <span class="info-value" id="addressText">Loading address...</span>
            </div>
          </div>
          <button class="copy-coords-btn" onclick="copyLocationCoords(${lat}, ${lng})">
            <i class="ri-file-copy-line"></i> Copy Coordinates
          </button>
        </div>
      </div>
    </div>
  `;

  // Add modal to page
  document.body.insertAdjacentHTML('beforeend', modalHTML);

  // Wait for DOM to settle, then initialize map
  setTimeout(() => {
    initializeMap(lat, lng);
  }, 100);
}

  // Get address using Geocoding API
 function getAddressFromCoordinates(lat, lng) {
  const addressElement = document.getElementById('addressText');
  if (!addressElement) return;

  if (typeof google === 'undefined' || !google.maps) {
    addressElement.textContent = 'Google Maps not loaded';
    return;
  }

  try {
    const geocoder = new google.maps.Geocoder();

    geocoder.geocode(
      {
        location: {
          lat: parseFloat(lat),
          lng: parseFloat(lng)
        }
      },
      function (results, status) {
        if (status === 'OK' && results && results[0]) {
          addressElement.textContent = results[0].formatted_address;
          addressElement.style.color = '#222';
        } else {
          console.warn('Geocoder failed:', status);

          if (status === 'REQUEST_DENIED') {
            addressElement.textContent = 'Geocoding API not enabled';
          } else if (status === 'ZERO_RESULTS') {
            addressElement.textContent = 'No address found';
          } else {
            addressElement.textContent = 'Could not retrieve address';
          }

          addressElement.style.color = '#999';
        }
      }
    );

  } catch (error) {
    console.error('Geocoder error:', error);
    addressElement.textContent = 'Geocoder failed to load';
  }
}

function initializeMap(lat, lng) {
  const mapElement = document.getElementById('locationMap');
  if (!mapElement) return;

  mapElement.innerHTML = '';

  if (typeof google === 'undefined' || !google.maps) {
    mapElement.innerHTML = '<span style="color:#999;">Google Maps library not loaded.</span>';
    return;
  }

  try {
    const location = {
      lat: parseFloat(lat),
      lng: parseFloat(lng)
    };

    const map = new google.maps.Map(mapElement, {
      zoom: 15,
      center: location,
      mapTypeControl: false,
      fullscreenControl: false
    });

    new google.maps.Marker({
      position: location,
      map: map,
      title: 'Your Location'
    });
    getAddressFromCoordinates(lat, lng);

  } catch (error) {
    console.error('Map initialization error:', error);
    mapElement.innerHTML = '<span style="color:#c33;">Failed to load map</span>';
  }
}
// Copy location coordinates to clipboard
function copyLocationCoords(lat, lng) {
  const coords = `${lat.toFixed(6)}, ${lng.toFixed(6)}`;
  navigator.clipboard.writeText(coords).then(() => {
    alert('Coordinates copied to clipboard!');
  }).catch(() => {
    alert('Failed to copy coordinates');
  });
}

// Add loader animation CSS
const style = document.createElement('style');
style.textContent = `
  @keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
  }

  .location-modal-overlay {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 10000;
    animation: fadeIn 0.3s ease;
  }

  @keyframes fadeIn {
    from { opacity: 0; }
    to { opacity: 1; }
  }

  .location-modal {
    background: white;
    border-radius: 16px;
    box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
    max-width: 500px;
    width: 90%;
    max-height: 90vh;
    overflow-y: auto;
    animation: slideUp 0.3s ease;
  }

  @keyframes slideUp {
    from {
      transform: translateY(20px);
      opacity: 0;
    }
    to {
      transform: translateY(0);
      opacity: 1;
    }
  }

  .location-modal-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 20px;
    border-bottom: 1px solid #f0f0f0;
  }

  .location-modal-header h3 {
    margin: 0;
    font-size: 20px;
    color: #222;
  }

  .close-modal-btn {
    background: none;
    border: none;
    font-size: 28px;
    cursor: pointer;
    color: #999;
    padding: 0;
    width: 32px;
    height: 32px;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 50%;
    transition: all 0.2s ease;
  }

  .close-modal-btn:hover {
    background: #f5f5f5;
    color: #222;
  }

  .location-modal-content {
    padding: 20px;
  }

  .location-map {
    width: 100%;
    height: 350px;
    border-radius: 12px;
    margin-bottom: 20px;
    overflow: hidden;
    background: #f0f0f0;
    border: 1px solid #e0e0e0;
    flex-shrink: 0;
  }

  /* Ensure Google Maps renders properly */
  .location-map > div:first-child {
    width: 100% !important;
    height: 100% !important;
  }

  .location-info {
    display: flex;
    flex-direction: column;
    gap: 12px;
    margin-bottom: 20px;
    padding: 16px;
    background: #f9f9f9;
    border-radius: 12px;
  }

  .info-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: 14px;
  }

  .info-item.full-width {
    flex-direction: column;
    align-items: flex-start;
    gap: 8px;
  }

  .info-label {
    font-weight: 600;
    color: #666;
    min-width: 100px;
  }

  .info-value {
    font-family: 'Courier New', monospace;
    color: #222;
    font-weight: 500;
    word-break: break-all;
  }

  .copy-coords-btn {
    width: 100%;
    padding: 12px 16px;
    background: linear-gradient(135deg, rgba(112, 4, 87, 1), rgba(160, 30, 125, 1));
    color: white;
    border: none;
    border-radius: 8px;
    font-weight: 700;
    cursor: pointer;
    font-size: 14px;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    transition: all 0.3s ease;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
  }

  .copy-coords-btn:hover {
    transform: translateY(-2px);
    box-shadow: 0 8px 20px rgba(112, 4, 87, 0.3);
  }

  .copy-coords-btn:active {
    transform: translateY(0);
  }

  @media (max-width: 600px) {
    .location-modal {
      width: 95%;
      max-height: 95vh;
    }

    .location-map {
      height: 250px;
    }

    .location-modal-header h3 {
      font-size: 18px;
    }

    .info-item {
      font-size: 13px;
    }

    .info-label {
      min-width: auto;
    }
  }
`;
document.head.appendChild(style);
