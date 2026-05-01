"""
VaxTrace AI — XGBoost Training Script
Generates synthetic vaccination data and trains a binary risk classifier.
Saves model.pkl to ml/ directory for backend consumption.

Run:
    cd backend
    python ml/train_model.py
"""

import os
import numpy as np
import pandas as pd
from pathlib import Path

OUTPUT_PATH = Path(__file__).parent / "model.pkl"

# ─────────────────────────────────────────────
# Step 1: Generate synthetic training data
# ─────────────────────────────────────────────

np.random.seed(42)
N = 5000

# Features
distance_km        = np.random.exponential(scale=5, size=N).clip(0.1, 50)
days_since_dose    = np.random.exponential(scale=45, size=N).clip(0, 365)
age_months         = np.random.randint(0, 60, size=N).astype(float)
missed_appts       = np.random.poisson(lam=1, size=N).clip(0, 5).astype(float)

# Ground truth risk (based on formula + noise)
formula_score = (distance_km * 0.3) + (days_since_dose * 0.7)
noise = np.random.normal(0, 3, N)
is_high_risk = ((formula_score + noise) >= 40).astype(int)

df = pd.DataFrame({
    "distance_km": distance_km,
    "days_since_dose": days_since_dose,
    "age_months": age_months,
    "missed_appointments": missed_appts,
    "is_high_risk": is_high_risk,
})

print(f"Dataset: {N} samples | High-risk: {is_high_risk.sum()} ({is_high_risk.mean()*100:.1f}%)")

# ─────────────────────────────────────────────
# Step 2: Train XGBoost classifier
# ─────────────────────────────────────────────

from xgboost import XGBClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, roc_auc_score

X = df[["distance_km", "days_since_dose", "age_months", "missed_appointments"]]
y = df["is_high_risk"]

X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

model = XGBClassifier(
    n_estimators=200,
    max_depth=5,
    learning_rate=0.05,
    subsample=0.8,
    colsample_bytree=0.8,
    use_label_encoder=False,
    eval_metric="logloss",
    random_state=42,
)

model.fit(
    X_train, y_train,
    eval_set=[(X_test, y_test)],
    verbose=50,
)

# ─────────────────────────────────────────────
# Step 3: Evaluate
# ─────────────────────────────────────────────

y_pred = model.predict(X_test)
y_prob = model.predict_proba(X_test)[:, 1]

print("\n=== Evaluation ===")
print(classification_report(y_test, y_pred, target_names=["Low Risk", "High Risk"]))
print(f"ROC-AUC: {roc_auc_score(y_test, y_prob):.4f}")

# ─────────────────────────────────────────────
# Step 4: Save model
# ─────────────────────────────────────────────

import joblib
joblib.dump(model, OUTPUT_PATH)
print(f"\n✅ Model saved to: {OUTPUT_PATH}")
print("   Backend will auto-load this on next startup.")
