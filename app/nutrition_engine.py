"""
PRECISION HEALTH MODE — STEP 01: HOUSEHOLD HEALTH SETUP
========================================================
Author: Chayan
Task: Calculate per-member calorie targets, macronutrient ratios,
      and micronutrient watchlists from household profile data.

FRONTEND NOTE (for frontend dev):
----------------------------------
This function expects data in the following shape (sent via POST /api/health-profile):

{
    "household": [
        {
            "age": 25,                          # int — member's age in years
            "gender": "male",                   # str — "male" | "female" | "other"
            "weightRange": "60-70",             # str — weight in kg as a range e.g. "60-70"
                                                # We take the midpoint: (60+70)/2 = 65kg
                                                # If frontend can send a single number instead,
                                                # that would be cleaner — but range works fine.
            "activityLevel": "moderate",        # str — "sedentary" | "light" | "moderate" | "active"
            "dietaryPreferences": [             # list[str] — zero or more of:
                "vegetarian",                   #   "vegetarian" | "vegan" | "keto" |
                "gluten-free"                   #   "diabetic-friendly" | "gluten-free" | "low-sodium"
            ]
        }
    ]
}

Returns JSON in this shape (frontend reads this directly):
{
    "version": "1.0",
    "householdSummary": {
        "totalCalories": 4800,
        "macroSplit": { "protein": 240, "carbs": 540, "fats": 160 }
    },
    "members": [
        {
            "calories": 2400,
            "macros": { "protein": 120, "carbs": 270, "fats": 80 },
            "micronutrients": ["Iron", "Calcium", "Vitamin B12", "Vitamin D"],
            "alerts": []
        }
    ],
    "alerts": []
}
"""

# ─────────────────────────────────────────────
# ACTIVITY LEVEL MULTIPLIERS (Harris-Benedict)
# Maps activity level string → calorie multiplier
# ─────────────────────────────────────────────
ACTIVITY_MULTIPLIERS = {
    "sedentary": 1.2,    # desk job, little/no exercise
    "light":     1.375,  # light exercise 1-3 days/week
    "moderate":  1.55,   # moderate exercise 3-5 days/week
    "active":    1.725,  # hard exercise 6-7 days/week
}

# ─────────────────────────────────────────────
# DIETARY PROFILE → MACRO RATIOS
# Each profile adjusts how calories split into protein/carbs/fats
# Format: (protein%, carbs%, fats%)
# ─────────────────────────────────────────────
DIETARY_MACRO_RATIOS = {
    "keto":             (0.25, 0.05, 0.70),  # very low carb, high fat
    "diabetic-friendly":(0.25, 0.40, 0.35),  # controlled carbs
    "vegan":            (0.20, 0.55, 0.25),  # plant-based, higher carbs
    "vegetarian":       (0.20, 0.50, 0.30),  # similar to balanced but plant protein
    "gluten-free":      (0.25, 0.45, 0.30),  # standard ratios, just flags gluten
    "low-sodium":       (0.25, 0.45, 0.30),  # standard ratios, flags sodium
    "default":          (0.25, 0.45, 0.30),  # balanced diet baseline
}

# ─────────────────────────────────────────────
# MICRONUTRIENT WATCHLIST
# Which nutrients to flag based on dietary preference
# These are the ones the cart scorer (Step 3) will track
# ─────────────────────────────────────────────
MICRONUTRIENT_WATCHLIST = {
    "vegan":            ["Iron", "Calcium", "Vitamin B12", "Vitamin D"],
    "vegetarian":       ["Iron", "Calcium", "Vitamin B12"],
    "keto":             ["Calcium", "Vitamin D", "Magnesium"],
    "diabetic-friendly":["Vitamin D", "Magnesium", "Chromium"],
    "gluten-free":      ["Iron", "Calcium", "Vitamin B12", "Folate"],
    "low-sodium":       ["Potassium", "Magnesium"],
    "default":          ["Iron", "Calcium", "Vitamin B12", "Vitamin D"],
}


def parse_weight(weight_range: str) -> float:
    """
    Parse weight range string into a single float (midpoint).
    Frontend sends weightRange as a string like "60-70".
    We take the average: (60 + 70) / 2 = 65.0 kg
    """
    try:
        if "-" in str(weight_range):
            parts = weight_range.split("-")
            return (float(parts[0]) + float(parts[1])) / 2
        return float(weight_range)
    except (ValueError, AttributeError):
        return 70.0  # safe fallback if parsing fails


def calculate_bmr(age: int, weight_kg: float, gender: str) -> float:
    """
    Calculate Basal Metabolic Rate using Mifflin-St Jeor equation.
    Assumed height: 170cm male, 160cm female (not collected in form yet).
    """
    if gender == "female":
        bmr = (10 * weight_kg) + (6.25 * 160) - (5 * age) - 161
    else:
        bmr = (10 * weight_kg) + (6.25 * 170) - (5 * age) + 5
    return bmr


def get_macro_ratio(dietary_preferences: list) -> tuple:
    """
    Pick the macro ratio based on dietary preference.
    Priority: keto → diabetic-friendly → vegan → vegetarian → gluten-free → low-sodium → default
    """
    priority = ["keto", "diabetic-friendly", "vegan", "vegetarian", "gluten-free", "low-sodium"]
    for pref in priority:
        if pref in dietary_preferences:
            return DIETARY_MACRO_RATIOS[pref]
    return DIETARY_MACRO_RATIOS["default"]


def get_micronutrients(dietary_preferences: list) -> list:
    """
    Build micronutrient watchlist for a member.
    Merges watchlists if multiple preferences, removes duplicates.
    """
    watchlist = set()
    matched = False
    for pref in dietary_preferences:
        if pref in MICRONUTRIENT_WATCHLIST:
            watchlist.update(MICRONUTRIENT_WATCHLIST[pref])
            matched = True
    if not matched:
        watchlist.update(MICRONUTRIENT_WATCHLIST["default"])
    return sorted(list(watchlist))


def calculate_member_nutrition(member: dict) -> dict:
    """
    Core calculation for a single household member.
    Receives one member object from the frontend household array.
    """
    age            = int(member.get("age", 25))
    gender         = str(member.get("gender", "other")).lower()
    weight_range   = member.get("weightRange", "60-80")
    activity_level = str(member.get("activityLevel", "moderate")).lower()
    dietary_prefs  = member.get("dietaryPreferences", [])

    weight_kg      = parse_weight(weight_range)
    bmr            = calculate_bmr(age, weight_kg, gender)
    multiplier     = ACTIVITY_MULTIPLIERS.get(activity_level, 1.4)
    total_calories = round(bmr * multiplier)

    protein_ratio, carbs_ratio, fats_ratio = get_macro_ratio(dietary_prefs)

    # Protein: 4 cal/g | Carbs: 4 cal/g | Fats: 9 cal/g
    protein_g = round((total_calories * protein_ratio) / 4)
    carbs_g   = round((total_calories * carbs_ratio) / 4)
    fats_g    = round((total_calories * fats_ratio) / 9)

    micronutrients = get_micronutrients(dietary_prefs)

    alerts = []
    if age >= 60:
        alerts.append("Senior member: Consider Calcium and Vitamin D supplementation.")
    if age < 18:
        alerts.append("Minor member: Higher calcium and iron needs for growth.")

    return {
        "calories": total_calories,
        "macros": {
            "protein": protein_g,
            "carbs":   carbs_g,
            "fats":    fats_g,
        },
        "micronutrients": micronutrients,
        "alerts":         alerts,
    }


def calculate_household_nutrition(household: list) -> dict:
    """
    Main entry point — called by the /api/health-profile endpoint.
    Receives the full household array from the frontend form.
    """
    member_results  = [calculate_member_nutrition(m) for m in household]

    total_calories  = sum(m["calories"]          for m in member_results)
    total_protein   = sum(m["macros"]["protein"] for m in member_results)
    total_carbs     = sum(m["macros"]["carbs"]   for m in member_results)
    total_fats      = sum(m["macros"]["fats"]    for m in member_results)

    household_alerts = []
    for m in member_results:
        household_alerts.extend(m.get("alerts", []))

    return {
        "version": "1.0",
        "householdSummary": {
            "totalCalories": total_calories,
            "macroSplit": {
                "protein": total_protein,
                "carbs":   total_carbs,
                "fats":    total_fats,
            },
        },
        "members": member_results,
        "alerts":  household_alerts,
    }


# ─────────────────────────────────────────────
# FASTAPI ENDPOINT
# This is what connects your function to the frontend form
# ─────────────────────────────────────────────

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import httpx

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─────────────────────────────────────────────
# FIREBASE CONFIG
# TODO (backend dev): Replace with your Firebase Realtime Database URL
# Format: "https://YOUR-PROJECT-ID-default-rtdb.firebaseio.com"
# The result will be saved under /health_profiles/ node
# ─────────────────────────────────────────────
FIREBASE_URL = ""  # TODO: add your Firebase Realtime Database URL here


async def save_to_firebase(result: dict):
    """
    Saves the nutrition result to Firebase Realtime Database.
    Only runs if FIREBASE_URL is set — safe to leave empty during development.
    """
    if not FIREBASE_URL:
        print("⚠️  Firebase URL not set — skipping save. Add your URL to FIREBASE_URL above.")
        return

    try:
        async with httpx.AsyncClient() as client:
            await client.post(
                f"{FIREBASE_URL}/health_profiles.json",
                json=result
            )
        print("✅ Result saved to Firebase.")
    except Exception as e:
        print(f"❌ Firebase save failed: {e}")


@app.post("/v1/health/analyze")
async def analyze(request: dict):
    household = request.get("household", [])
    result = calculate_household_nutrition(household)

    # Save to Firebase (only runs if FIREBASE_URL is set above)
    await save_to_firebase(result)

    return result


# ─────────────────────────────────────────────
# QUICK TEST — run this file directly to verify
# python nutrition_engine.py
# ─────────────────────────────────────────────
if __name__ == "__main__":
    import json

    test_payload = {
        "household": [
            {
                "age": 35,
                "gender": "male",
                "weightRange": "70-80",
                "activityLevel": "moderate",
                "dietaryPreferences": ["vegetarian"]
            },
            {
                "age": 28,
                "gender": "female",
                "weightRange": "55-65",
                "activityLevel": "light",
                "dietaryPreferences": ["vegan", "gluten-free"]
            },
            {
                "age": 65,
                "gender": "female",
                "weightRange": "60-70",
                "activityLevel": "sedentary",
                "dietaryPreferences": []
            }
        ]
    }

    result = calculate_household_nutrition(test_payload["household"])
    print(json.dumps(result, indent=2))
